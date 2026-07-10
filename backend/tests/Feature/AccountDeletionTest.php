<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_delete_request_requires_authentication(): void
    {
        $this->postJson('/api/v1/account/delete-request')->assertUnauthorized();
    }

    public function test_authenticated_user_can_request_deletion(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/account/delete-request', ['reason' => 'Leaving'])
            ->assertStatus(202)
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('contact_email', 'hatbazar627@gmail.com');

        $this->assertDatabaseHas('account_deletion_requests', [
            'user_id' => $user->id,
            'status' => 'pending',
            'reason' => 'Leaving',
        ]);
    }

    public function test_repeat_request_does_not_duplicate(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/account/delete-request')->assertStatus(202);
        $this->postJson('/api/v1/account/delete-request')->assertStatus(202);

        $this->assertDatabaseCount('account_deletion_requests', 1);
    }
}
