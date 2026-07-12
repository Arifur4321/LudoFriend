<?php

namespace App\Http\Controllers\Api;

use App\Events\ChatMessageSent;
use App\Events\EmojiReactionSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\SendChatRequest;
use App\Http\Requests\SendEmojiRequest;
use App\Http\Resources\MatchMessageResource;
use App\Models\Matchup;
use App\Models\MatchMessage;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * In-match chat + emoji. Only seated participants may post or read
 * (MatchPolicy@view returns true only for a user with a seat in the match, so a
 * non-member or a stranger guessing a match id is rejected). Guests are limited
 * to canned quick-phrases; registered users get free text with a length cap and
 * a profanity mask.
 *
 * Chat is persisted (authoritative id, stable order) and broadcast; emoji is
 * ephemeral (broadcast only) but still carries a stable id so clients can
 * de-duplicate. Sender identity is always taken from the authenticated user —
 * never trusted from the request body.
 */
class ChatController extends Controller
{
    /**
     * Recent chat history for a match, newest-page-first via a `before_id`
     * cursor. Bounded so a client can restore context on (re)entry without ever
     * pulling an unbounded log. Read is gated to seated participants.
     */
    public function history(Request $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $max = (int) config('chat.history_max', 50);
        $limit = max(1, min((int) $request->integer('limit', 30), $max));

        $query = MatchMessage::query()
            ->where('match_id', $match->id)
            ->with('user:id,name,avatar')
            ->orderByDesc('id');

        if ($request->filled('before_id')) {
            $query->where('id', '<', (int) $request->integer('before_id'));
        }

        // Fetch one extra to know whether an older page exists.
        $rows = $query->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);

        return response()->json([
            // Ascending (oldest → newest) for direct display.
            'data' => MatchMessageResource::collection($page->sortBy('id')->values()),
            'meta' => [
                'has_more' => $hasMore,
                'next_before_id' => $hasMore ? (int) $page->min('id') : null,
            ],
        ]);
    }

    public function message(SendChatRequest $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $user = $request->user();
        $seat = $match->players()->where('user_id', $user->id)->first();

        $body = $this->sanitize((string) $request->input('body'));
        if ($body === '') {
            return response()->json(['message' => 'Empty message.'], 422);
        }

        // Guests may only send from the approved quick-phrase list.
        if ($user->is_guest && ! in_array($body, config('chat.quick_phrases', []), true)) {
            return response()->json(['message' => 'Guests can only send quick messages.'], 422);
        }

        $body = $this->filterProfanity($body);
        $clientId = $request->filled('client_id') ? (string) $request->input('client_id') : null;

        [$message, $created] = $this->persistMessage($match, $user, $seat?->color, $body, $clientId);
        $message->setRelation('user', $user);

        // Broadcast only for a newly stored message — a duplicate request never
        // produces a second broadcast (or a second row).
        if ($created) {
            broadcast(new ChatMessageSent(
                $match->id,
                $message->id,
                $clientId,
                $user->id,
                $user->name,
                $user->avatar,
                $seat?->color,
                $body,
                optional($message->created_at)->toIso8601String() ?? now()->toIso8601String(),
            ));
        }

        return response()->json([
            'data' => (new MatchMessageResource($message))->resolve($request),
            'meta' => ['duplicate' => ! $created],
        ]);
    }

    public function emoji(SendEmojiRequest $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $user = $request->user();
        $seat = $match->players()->where('user_id', $user->id)->first();
        $emoji = (string) $request->input('emoji');
        $eventId = (string) Str::uuid();

        broadcast(new EmojiReactionSent(
            $match->id,
            $eventId,
            $user->id,
            $user->name,
            $seat?->color,
            $emoji,
        ));

        return response()->json(['data' => ['id' => $eventId, 'emoji' => $emoji]]);
    }

    /**
     * Store the message, honouring the client idempotency key. A duplicate
     * (match_id, client_id) resolves to the existing row — no second insert,
     * even under a concurrent retry (the unique index is the backstop).
     *
     * @return array{0: MatchMessage, 1: bool}  [message, wasCreated]
     */
    private function persistMessage(Matchup $match, $user, ?string $color, string $body, ?string $clientId): array
    {
        $attributes = [
            'user_id' => $user->id,
            'color' => $color,
            'type' => 'text',
            'body' => $body,
        ];

        if ($clientId === null) {
            return [MatchMessage::create(['match_id' => $match->id] + $attributes), true];
        }

        $existing = MatchMessage::where('match_id', $match->id)->where('client_id', $clientId)->first();
        if ($existing) {
            return [$existing, false];
        }

        try {
            $message = MatchMessage::create(
                ['match_id' => $match->id, 'client_id' => $clientId] + $attributes,
            );

            return [$message, true];
        } catch (QueryException $e) {
            // Lost a race on the unique(match_id, client_id) index: the other
            // request already stored it — return that row idempotently.
            $existing = MatchMessage::where('match_id', $match->id)->where('client_id', $clientId)->first();
            if ($existing) {
                return [$existing, false];
            }
            throw $e;
        }
    }

    /**
     * Remove control characters (keeping tab/newline) and trim. Eloquent
     * parameter binding already prevents SQL injection, and the Flutter client
     * renders text nodes only (no HTML/JS execution surface), so this focuses on
     * control-character abuse and whitespace normalisation while preserving all
     * Unicode (Bengali, Hindi, CJK, emoji, accents).
     */
    private function sanitize(string $text): string
    {
        $clean = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $text);

        return trim($clean ?? $text);
    }

    /** Whole-word, case-insensitive mask of any configured profanity. */
    private function filterProfanity(string $text): string
    {
        $bad = config('chat.profanity', []);
        if (empty($bad)) {
            return $text;
        }

        $pattern = '/\b('.implode('|', array_map(fn ($w) => preg_quote($w, '/'), $bad)).')\b/iu';

        return preg_replace_callback(
            $pattern,
            fn ($m) => str_repeat('*', mb_strlen($m[0])),
            $text,
        ) ?? $text;
    }
}
