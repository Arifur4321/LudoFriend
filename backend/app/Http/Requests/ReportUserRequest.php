<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ReportUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $selfId = optional($this->user())->id;

        return [
            'reported_user_id' => [
                'required', 'integer', 'exists:users,id',
                // Cannot report yourself.
                'not_in:'.($selfId ?? 0),
            ],
            'match_id' => ['nullable', 'integer', 'exists:matches,id'],
            'reason' => ['required', 'string', 'in:cheating,abuse,harassment,afk,other'],
            'details' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'reported_user_id.not_in' => 'You cannot report yourself.',
        ];
    }
}
