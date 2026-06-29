<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class GuestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Stable per-install identifier so the same device reuses its guest.
            'device_id' => ['required', 'string', 'max:191'],
            'guest_name' => ['nullable', 'string', 'max:40'],
            'avatar' => ['nullable', 'string', 'max:2048'],
        ];
    }
}
