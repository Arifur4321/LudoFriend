<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateRoomRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $tierKeys = array_column((array) config('economy.tiers', []), 'key');

        return [
            'mode' => ['required', 'in:2p,4p'],
            'board_tier' => ['nullable', 'string', 'in:'.implode(',', $tierKeys)],
            'team_mode' => ['boolean'],
            'visibility' => ['required', 'in:public,private'],
            'bot_fill' => ['boolean'],
            'turn_timer_seconds' => ['nullable', 'integer', 'min:5', 'max:120'],
            'settings' => ['nullable', 'array'],
        ];
    }
}
