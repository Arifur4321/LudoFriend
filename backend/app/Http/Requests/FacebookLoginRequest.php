<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class FacebookLoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Short-lived user access token obtained client-side via the FB SDK.
            'access_token' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:191'],
        ];
    }
}
