<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SendEmojiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // participant check is done via MatchPolicy in the controller
    }

    public function rules(): array
    {
        return [
            'emoji' => ['required', 'string', 'max:16', Rule::in(config('chat.allowed_emojis', []))],
        ];
    }
}
