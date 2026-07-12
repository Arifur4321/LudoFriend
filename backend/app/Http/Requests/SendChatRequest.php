<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SendChatRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // participant check is done via MatchPolicy in the controller
    }

    public function rules(): array
    {
        return [
            'body' => ['required', 'string', 'max:'.(int) config('chat.max_length', 200)],
            // Client-generated idempotency key for one physical send. A retry or
            // rapid double-tap with the same id resolves to the same message.
            'client_id' => ['nullable', 'string', 'max:64', 'regex:/^[A-Za-z0-9_-]+$/'],
        ];
    }
}
