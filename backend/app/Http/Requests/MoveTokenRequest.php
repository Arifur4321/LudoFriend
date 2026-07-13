<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class MoveTokenRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'color' => ['required', 'in:red,green,yellow,blue'],
            // Which of the player's four tokens to move. The destination and any
            // capture are computed server-side — never trusted from the client.
            'token' => ['required', 'integer', 'between:0,3'],
            // Optional anti-replay assertion: the client's expected next seq.
            'seq' => ['nullable', 'integer', 'min:1'],
            // Stable for one physical tap. If transport retries the same HTTP
            // request, the engine returns the first result instead of moving a
            // second time (mirrors RollDiceRequest.action_id).
            'action_id' => ['nullable', 'string', 'max:100', 'regex:/^[A-Za-z0-9_-]+$/'],
        ];
    }
}
