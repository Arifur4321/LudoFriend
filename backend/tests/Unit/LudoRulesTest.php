<?php

namespace Tests\Unit;

use App\Services\Game\LudoRules;
use PHPUnit\Framework\TestCase;

/**
 * Mirrors the nine verified rule scenarios from the authoritative spec. These
 * tests construct LudoRules with an explicit config array so they do not depend
 * on the Laravel container.
 */
class LudoRulesTest extends TestCase
{
    private LudoRules $rules;

    protected function setUp(): void
    {
        parent::setUp();

        $this->rules = new LudoRules($this->config());
    }

    /** The canonical rule constants (same values as config/ludo.php). */
    private function config(): array
    {
        return [
            'ring_size' => 52,
            'rel_base' => -1,
            'rel_ring_min' => 0,
            'rel_ring_max' => 50,
            'rel_home_min' => 51,
            'rel_home' => 56,
            'start_offsets' => ['red' => 0, 'green' => 13, 'yellow' => 26, 'blue' => 39],
            'colors' => ['red', 'green', 'yellow', 'blue'],
            'colors_2p' => ['red', 'yellow'],
            'safe_cells' => [0, 8, 13, 21, 26, 34, 39, 47],
            'leave_base_roll' => 6,
            'extra_turn_roll' => 6,
            'max_consecutive_sixes' => 3,
            'tokens_per_player' => 4,
        ];
    }

    /** Build a token map with everyone in base, then override per-color. */
    private function tokens(array $overrides = []): array
    {
        $base = [
            'red' => [-1, -1, -1, -1],
            'green' => [-1, -1, -1, -1],
            'yellow' => [-1, -1, -1, -1],
            'blue' => [-1, -1, -1, -1],
        ];

        return array_replace($base, $overrides);
    }

    /* 1. absolutePos(color, rel) = (start + rel) % 52 for rel 0..50. */
    public function test_absolute_position_uses_start_offsets(): void
    {
        $this->assertSame(0, $this->rules->absolutePos('red', 0));
        $this->assertSame(13, $this->rules->absolutePos('green', 0));
        $this->assertSame(26, $this->rules->absolutePos('yellow', 0));
        $this->assertSame(39, $this->rules->absolutePos('blue', 0));

        // Wrap-around: green start 13 + rel 50 = 63 % 52 = 11.
        $this->assertSame(11, $this->rules->absolutePos('green', 50));

        // Off-ring positions resolve to null.
        $this->assertNull($this->rules->absolutePos('red', -1));   // base
        $this->assertNull($this->rules->absolutePos('red', 51));   // home column
        $this->assertNull($this->rules->absolutePos('red', 56));   // finished
    }

    /* 2. A token leaves base only on a roll of 6 (rel -1 -> 0). */
    public function test_token_leaves_base_only_on_six(): void
    {
        $this->assertFalse($this->rules->isLegalTokenMove(-1, 1));
        $this->assertFalse($this->rules->isLegalTokenMove(-1, 5));
        $this->assertTrue($this->rules->isLegalTokenMove(-1, 6));
        $this->assertSame(0, $this->rules->destinationRel(-1, 6));

        // From base, only the token that can move appears in legalMoves.
        $moves = $this->rules->legalMoves('red', 6, $this->tokens());
        $this->assertNotEmpty($moves);
        $this->assertSame(0, $moves[0]['to']);

        $this->assertEmpty($this->rules->legalMoves('red', 4, $this->tokens()));
    }

    /* 3. A move is legal only if r + dice <= 56 (must land exactly on 56). */
    public function test_move_must_land_exactly_on_home(): void
    {
        // From rel 53, a 3 lands exactly on 56 -> legal.
        $this->assertTrue($this->rules->isLegalTokenMove(53, 3));
        // From rel 53, a 4 would overshoot to 57 -> illegal.
        $this->assertFalse($this->rules->isLegalTokenMove(53, 4));
        // A finished token cannot move.
        $this->assertFalse($this->rules->isLegalTokenMove(56, 1));

        $result = $this->rules->applyMove('red', 0, 3, $this->tokens(['red' => [53, -1, -1, -1]]));
        $this->assertSame(56, $result['to']);
        $this->assertTrue($result['finished']);
    }

    /* 4. Capture: landing on an opponent on a non-safe ring cell sends it home. */
    public function test_capture_sends_opponent_to_base(): void
    {
        // Red token at rel 3 (absolute 3). Green token sits on absolute 3, which
        // for green is rel (3 - 13 + 52) % 52 = 42. Red rolls so it lands on
        // absolute 5 — put green there instead. Use a simpler direct setup:
        // Red at rel 4 -> rolls 1 -> lands rel 5 = absolute 5.
        // Green occupies absolute 5 => green rel = (5 - 13 + 52) % 52 = 44.
        $tokens = $this->tokens([
            'red' => [4, -1, -1, -1],
            'green' => [44, -1, -1, -1],
        ]);

        // Sanity: both map to absolute 5.
        $this->assertSame(5, $this->rules->absolutePos('red', 5));
        $this->assertSame(5, $this->rules->absolutePos('green', 44));

        $result = $this->rules->applyMove('red', 0, 1, $tokens);

        $this->assertSame(5, $this->rules->absolutePos('red', $result['to']));
        $this->assertNotEmpty($result['captured']);
        $this->assertSame('green', $result['captured'][0]['color']);
        // Captured token is back in base.
        $this->assertSame(-1, $result['tokens']['green'][0]);
        // Capture grants an extra turn.
        $this->assertTrue($result['extra_turn']);
    }

    /* 5. A SAFE cell prevents capture. */
    public function test_safe_cell_prevents_capture(): void
    {
        // Absolute 8 is safe. Red at rel 7 -> roll 1 -> rel 8 = absolute 8.
        // Green occupies absolute 8 => green rel = (8 - 13 + 52) % 52 = 47.
        $tokens = $this->tokens([
            'red' => [7, -1, -1, -1],
            'green' => [47, -1, -1, -1],
        ]);

        $this->assertSame(8, $this->rules->absolutePos('red', 8));
        $this->assertSame(8, $this->rules->absolutePos('green', 47));
        $this->assertTrue($this->rules->isSafeCell(8));

        $result = $this->rules->applyMove('red', 0, 1, $tokens);

        // Landed on the safe cell but nothing was captured.
        $this->assertSame(8, $this->rules->absolutePos('red', $result['to']));
        $this->assertEmpty($result['captured']);
        // Green stays put.
        $this->assertSame(47, $result['tokens']['green'][0]);
    }

    /* 6. No captures inside home columns. */
    public function test_no_capture_in_home_column(): void
    {
        // Home-column positions (>=51) have a null absolute, so even if two
        // colors share a rel value there is no capture.
        $tokens = $this->tokens([
            'red' => [52, -1, -1, -1],
            'green' => [52, -1, -1, -1],
        ]);

        $result = $this->rules->applyMove('red', 0, 1, $tokens); // 52 -> 53
        $this->assertSame(53, $result['to']);
        $this->assertEmpty($result['captured']);
        $this->assertSame(52, $result['tokens']['green'][0]);
    }

    /* 7. Extra turn granted on six, capture, or reaching home. */
    public function test_extra_turn_conditions(): void
    {
        // Six.
        $this->assertTrue($this->rules->grantsExtraTurn(6, false, false));
        // Capture (non-six).
        $this->assertTrue($this->rules->grantsExtraTurn(3, true, false));
        // Reached home (non-six).
        $this->assertTrue($this->rules->grantsExtraTurn(2, false, true));
        // None of the above.
        $this->assertFalse($this->rules->grantsExtraTurn(4, false, false));
    }

    /* 8. Three consecutive sixes => third is forfeited. */
    public function test_three_consecutive_sixes_forfeits_third(): void
    {
        // After 0 prior sixes, a six is fine (1st).
        $this->assertFalse($this->rules->isForfeitedThirdSix(0, 6));
        // After 1 prior six, a six is fine (2nd).
        $this->assertFalse($this->rules->isForfeitedThirdSix(1, 6));
        // After 2 prior sixes, the 3rd six is forfeited.
        $this->assertTrue($this->rules->isForfeitedThirdSix(2, 6));
        // A non-six is never forfeited by this rule.
        $this->assertFalse($this->rules->isForfeitedThirdSix(2, 4));
    }

    /* 9. Winner = all four tokens of a color at rel 56. */
    public function test_winner_requires_all_four_home(): void
    {
        $this->assertTrue($this->rules->isWinner([56, 56, 56, 56]));
        $this->assertFalse($this->rules->isWinner([56, 56, 56, 55]));
        $this->assertFalse($this->rules->isWinner([56, 56, 56]));
    }

    /* Bonus: self-stacking on a ring cell is disallowed. */
    public function test_cannot_land_on_own_token(): void
    {
        // Red has tokens at rel 4 and rel 5. Moving the rel-4 token by 1 would
        // land on rel 5 where its own token sits -> not a legal move.
        $tokens = $this->tokens(['red' => [4, 5, -1, -1]]);
        $moves = $this->rules->legalMoves('red', 1, $tokens);
        $movedTokens = array_column($moves, 'token');

        $this->assertNotContains(0, $movedTokens); // token 0 (rel 4) blocked
        $this->assertContains(1, $movedTokens);    // token 1 (rel 5 -> 6) ok
    }
}
