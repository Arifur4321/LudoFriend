<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AcceptFriendByCodeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // A friend code is simply the target user's id encoded as a string;
            // kept as a separate request so the surface can evolve (e.g. signed
            // short codes) without touching the controller contract.
            'code' => ['required', 'string', 'max:64'],
        ];
    }
}
