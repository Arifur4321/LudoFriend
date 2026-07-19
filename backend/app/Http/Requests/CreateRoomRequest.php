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

    /**
     * Normalise optional inputs so an "accidentally empty" board tier from the
     * guest UI falls back to the free casual default (RoomService) instead of
     * tripping the `in:` rule. A genuinely unknown non-empty tier still returns
     * a clean 422 rather than a 500.
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('board_tier')) {
            $tier = $this->input('board_tier');
            if ($tier === '' || $tier === null || (is_string($tier) && trim($tier) === '')) {
                $this->merge(['board_tier' => null]);
            }
        }
    }
}
