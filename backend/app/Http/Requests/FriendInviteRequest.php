<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class FriendInviteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Invite a known user by id (e.g. from Facebook friends-using-app).
            'friend_user_id' => ['required', 'integer', 'exists:users,id'],
            'source' => ['nullable', 'in:facebook,code,link'],
        ];
    }
}
