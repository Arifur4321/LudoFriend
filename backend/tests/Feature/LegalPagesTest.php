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
    }

    public function test_legal_pages_do_not_require_authentication(): void
    {
        $this->get('/privacy')->assertOk();
        $this->get('/terms')->assertOk();
        $this->get('/data-deletion')->assertOk();
    }
}
