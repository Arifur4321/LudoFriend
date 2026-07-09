<?php

namespace App\Http\Controllers\Api;

use App\Events\ChatMessageSent;
use App\Events\EmojiReactionSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\SendChatRequest;
use App\Http\Requests\SendEmojiRequest;
use App\Models\Matchup;
use App\Models\MatchMessage;
use Illuminate\Http\JsonResponse;

/**
 * In-match chat + emoji. Only seated participants may post (MatchPolicy@view).
 * Guests are limited to canned quick-phrases; registered users get free text
 * with a length cap and a profanity mask. Messages broadcast to every
 * participant so the log is one authoritative stream; emojis are ephemeral.
 */
class ChatController extends Controller
{
    public function message(SendChatRequest $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $user = $request->user();
        $seat = $match->players()->where('user_id', $user->id)->first();
        $body = trim((string) $request->input('body'));

        if ($body === '') {
            return response()->json(['message' => 'Empty message.'], 422);
        }

        // Guests may only send from the approved quick-phrase list.
        if ($user->is_guest && ! in_array($body, config('chat.quick_phrases', []), true)) {
            return response()->json(['message' => 'Guests can only send quick messages.'], 422);
        }

        $body = $this->filterProfanity($body);

        MatchMessage::create([
            'match_id' => $match->id,
            'user_id' => $user->id,
            'color' => $seat?->color,
            'type' => 'text',
            'body' => $body,
        ]);

        broadcast(new ChatMessageSent(
            $match->id,
            $user->id,
            $user->name,
            $seat?->color,
            $body,
            now()->timestamp,
        ));

        return response()->json(['data' => ['body' => $body]]);
    }

    public function emoji(SendEmojiRequest $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $user = $request->user();
        $seat = $match->players()->where('user_id', $user->id)->first();
        $emoji = (string) $request->input('emoji');

        broadcast(new EmojiReactionSent($match->id, $user->id, $seat?->color, $emoji));

        return response()->json(['data' => ['emoji' => $emoji]]);
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
