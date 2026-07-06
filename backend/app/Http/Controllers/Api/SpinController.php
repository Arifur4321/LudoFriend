<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Economy\FreeSpinService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class SpinController extends Controller
{
    public function __construct(private readonly FreeSpinService $spins)
    {
    }

    /** Whether the free spin is available + the wheel layout. */
    public function status(Request $request): JsonResponse
    {
        return response()->json([
            'enabled' => $this->spins->enabled(),
            'segments' => $this->spins->segments(),
            ...$this->spins->status($request->user()),
        ]);
    }

    /** Claim the free spin (server picks the reward). */
    public function spin(Request $request): JsonResponse
    {
        try {
            $result = $this->spins->spin($request->user());
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($result);
    }
}
