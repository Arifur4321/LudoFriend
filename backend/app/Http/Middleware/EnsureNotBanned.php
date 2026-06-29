<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rejects requests from banned users with a 403 and the ban reason.
 */
class EnsureNotBanned
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && $user->is_banned) {
            return response()->json([
                'message' => 'Your account has been banned.',
                'reason' => $user->banned_reason,
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}
