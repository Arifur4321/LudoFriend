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
        ];
    }
}
