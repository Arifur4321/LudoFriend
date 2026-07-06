<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StorePurchaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $productIds = array_column((array) config('economy.store.packs', []), 'product_id');

        return [
            'product_id' => ['required', 'string', 'in:'.implode(',', $productIds)],
            'platform' => ['required', 'in:ios,android,web'],
            'receipt' => ['nullable', 'string'],
        ];
    }
}
