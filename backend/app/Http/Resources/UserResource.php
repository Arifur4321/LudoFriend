<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->when(! $this->is_guest, $this->email),
            'avatar' => $this->avatar,
            'is_guest' => (bool) $this->is_guest,
            'is_admin' => (bool) $this->is_admin,
            'profile' => new ProfileResource($this->whenLoaded('profile')),
            'created_at' => $this->created_at,
        ];
    }
}
