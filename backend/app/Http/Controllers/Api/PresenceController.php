<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/**
 * Lightweight online-presence heartbeat. The client pings this on a timer while
 * in the foreground; friends lists read the resulting cache keys. Backed by the
 * cache store (Redis in production) so it is cheap and auto-expiring.
 */
class PresenceController extends Controller
{
    public function ping(Request $request): JsonResponse
    {
        $id = $request->user()->id;
        Cache::put(
            "presence:online:{$id}",
            true,
            now()->addSeconds((int) config('chat.presence_ttl', 60)),
        );

        return response()->json(['ok' => true]);
    }
}
