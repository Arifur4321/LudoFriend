<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReportUserRequest;
use App\Models\Report;
use Illuminate\Http\JsonResponse;

class ReportController extends Controller
{
    /** File a report against another user (optionally tied to a match). */
    public function store(ReportUserRequest $request): JsonResponse
    {
        $report = Report::create([
            'reporter_user_id' => $request->user()->id,
            'reported_user_id' => (int) $request->integer('reported_user_id'),
            'match_id' => $request->filled('match_id') ? (int) $request->integer('match_id') : null,
            'reason' => $request->string('reason'),
            'details' => $request->input('details'),
            'status' => 'open',
        ]);

        return response()->json([
            'message' => 'Report submitted.',
            'data' => ['id' => $report->id],
        ], 201);
    }
}
