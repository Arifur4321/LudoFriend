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
        ];
    }
}
