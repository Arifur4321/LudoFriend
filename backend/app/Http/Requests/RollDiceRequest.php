<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class RollDiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // The color the requester claims to act as; ownership is verified
            // by MatchPolicy and the turn is verified by the engine.
            'color' => ['required', 'in:red,green,yellow,blue'],
        ];
    }
}
