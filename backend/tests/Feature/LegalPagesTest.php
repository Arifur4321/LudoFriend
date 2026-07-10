<?php

namespace Tests\Feature;

use Tests\TestCase;

class LegalPagesTest extends TestCase
{
    public function test_public_legal_pages_are_available(): void
    {
        $this->get('/')->assertOk()->assertSee('Ludo Friends');
        $this->get('/privacy')->assertOk()->assertSee('Privacy Policy');
        $this->get('/terms')->assertOk()->assertSee('Terms');
        $this->get('/data-deletion')->assertOk()->assertSee('Data Deletion');
        $this->get('/support')->assertOk()->assertSee('Support');
    }

    public function test_legal_pages_do_not_require_authentication(): void
    {
        $this->get('/privacy')->assertOk();
        $this->get('/terms')->assertOk();
        $this->get('/data-deletion')->assertOk();
        $this->get('/support')->assertOk();
    }

    public function test_privacy_and_deletion_cover_google_and_facebook(): void
    {
        $this->get('/privacy')->assertOk()
            ->assertSee('Google')
            ->assertSee('Facebook')
            ->assertSee('hatbazar627@gmail.com');

        $this->get('/data-deletion')->assertOk()
            ->assertSee('Google')
            ->assertSee('Facebook')
            ->assertSee('https://db.ludogame.dronescan.pro/data-deletion');
    }
}
