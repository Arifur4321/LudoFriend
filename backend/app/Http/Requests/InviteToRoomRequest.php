<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class InviteToRoomRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'room_id' => ['required', 'integer', 'exists:game_rooms,id'],
            'friend_user_id' => ['required', 'integer', 'exists:users,id'],
        ];
    }
}
