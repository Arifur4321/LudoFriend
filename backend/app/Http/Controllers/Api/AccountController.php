<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AccountDeletionRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AccountController extends Controller
{
    /**
     * Record a (non-destructive) account-deletion request for the authenticated
     * user, satisfying Google Play's "Delete account" and GDPR erasure paths.
     *
     * We deliberately do NOT hard-delete wallet, purchase, or match records
     * here: those are required for game integrity, fraud prevention, and
     * accounting. A single pending request is created (idempotent) for
     * manual/async processing, and the user is told the contact address and the
     * expected timeline. Full deletion/anonymization happens out of band.
     */
    public function deleteRequest(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $user = $request->user();

        $deletion = AccountDeletionRequest::firstOrCreate(
            ['user_id' => $user->id, 'status' => 'pending'],
            ['reason' => $validated['reason'] ?? null],
        );

        return response()->json([
            'status' => 'pending',
            'message' => 'Your account deletion request has been received. '
                .'We will delete or anonymize your data within 30 days. '
                .'For anything urgent, email hatbazar627@gmail.com.',
            'contact_email' => 'hatbazar627@gmail.com',
            'requested_at' => $deletion->created_at,
        ], 202);
    }
}
