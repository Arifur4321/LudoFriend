<?php

/*
|--------------------------------------------------------------------------
| Ludo Rule Configuration (single source of truth)
|--------------------------------------------------------------------------
|
| Every gameplay constant lives here so that the move-validation engine
| (App\Services\Game\LudoRules) and any other consumer read identical
| values. Do NOT duplicate these numbers elsewhere.
|
| Board model (verified spec):
|   - Ring = 52 cells, indices 0..51.
|   - Token relative position:
|       -1     = in base
|        0..50 = on the shared ring (relative to the color's start)
|       51..56 = private home column
|       56     = finished / home
|   - absolutePos(color, rel) = (start[color] + rel) % 52  for rel 0..50.
|
*/

return [

    /*
    |--------------------------------------------------------------------------
    | Ring geometry
    |--------------------------------------------------------------------------
    */
    'ring_size' => 52,

    // Relative-position landmarks.
    'rel_base'      => -1,  // token sitting in its base/yard
    'rel_ring_min'  => 0,   // first shared-ring cell (the color's start)
    'rel_ring_max'  => 50,  // last shared-ring cell before entering home column
    'rel_home_min'  => 51,  // first private home-column cell
    'rel_home'      => 56,  // finished — must be reached exactly

    /*
    |--------------------------------------------------------------------------
    | Per-color start offsets on the shared ring
    |--------------------------------------------------------------------------
    | absolutePos(color, rel) = (start[color] + rel) % ring_size
    */
    'start_offsets' => [
        'red'    => 0,
        'green'  => 13,
        'yellow' => 26,
        'blue'   => 39,
    ],

    // Canonical seat -> color ordering for turn rotation (clockwise).
    'colors' => ['red', 'green', 'yellow', 'blue'],

    // Colors used for a 2-player match (diagonally opposed).
    'colors_2p' => ['red', 'yellow'],

    /*
    |--------------------------------------------------------------------------
    | Safe cells (absolute ring indices)
    |--------------------------------------------------------------------------
    | A token on a safe cell can never be captured. These are the four
    | colored start cells plus the four star cells.
    */
    'safe_cells' => [0, 8, 13, 21, 26, 34, 39, 47],

    /*
    |--------------------------------------------------------------------------
    | Dice / turn rules
    |--------------------------------------------------------------------------
    */
    'dice_min' => 1,
    'dice_max' => 6,

    // A token may only leave base on this roll.
    'leave_base_roll' => 6,

    // Roll that grants an extra turn (also granted on capture or reaching home).
    'extra_turn_roll' => 6,

    // Three consecutive sixes => third roll forfeited, turn ends.
    'max_consecutive_sixes' => (int) env('LUDO_MAX_CONSECUTIVE_SIXES', 3),

    // Tokens per color.
    'tokens_per_player' => 4,

    /*
    |--------------------------------------------------------------------------
    | Timers (seconds)
    |--------------------------------------------------------------------------
    */
    'turn_timer_seconds'       => (int) env('LUDO_TURN_TIMER_SECONDS', 20),
    'reconnect_grace_seconds'  => (int) env('LUDO_RECONNECT_GRACE_SECONDS', 60),
    'room_stale_minutes'       => (int) env('LUDO_ROOM_STALE_MINUTES', 15),
    'matchmaking_bot_fill_seconds' => (int) env('LUDO_MATCHMAKING_BOT_FILL_SECONDS', 30),

    /*
    |--------------------------------------------------------------------------
    | Economy / scoring defaults
    |--------------------------------------------------------------------------
    */
    'starting_coins'      => 500,
    'win_coins_reward'    => 100,
    'rating_default'      => 1000,
    'rating_k_factor'     => 24,
];
