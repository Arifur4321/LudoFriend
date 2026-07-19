<?php

/*
|--------------------------------------------------------------------------
| Bot identity configuration
|--------------------------------------------------------------------------
|
| Realistic display names for bot (AI) seats so a bot-filled table never shows
| a generic "Bot" label. Names are chosen randomly and kept unique within a
| single match when the pool is large enough. The chosen name is PERSISTED on
| the seat (game_room_players.display_name / match_players.display_name) so
| every device renders the same name and it stays stable across reconnects.
|
| This is purely cosmetic: bot AI, turns, dice, token movement and timeout
| behaviour are unchanged. Override the pools per-deployment via config cache.
|
*/

return [
    // A neutral default avatar URL for bots (null => the client renders
    // deterministic initials from the display name).
    'default_avatar' => env('LUDO_BOT_AVATAR', null),

    // Regional name pools. The effective pool is the union of all enabled
    // groups (see 'names' below), so a match can mix local + international
    // names naturally.
    'name_pools' => [
        'bangladeshi' => [
            'Rakib', 'Sojib', 'Ashraf', 'Rahim', 'Karim', 'Nayeem',
            'Shakib', 'Tanvir', 'Rafi', 'Imran', 'Mitu', 'Rima',
        ],
        'international' => [
            'Samuel', 'John', 'Marco', 'Daniel', 'Alex', 'David',
            'Sofia', 'Emma', 'Mia', 'Lucas', 'Leo', 'Noah',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Online bot-turn driver (server-authoritative)
    |--------------------------------------------------------------------------
    |
    | Timing + safety knobs for the PlayBotTurn job that advances bot seats on
    | the server. These do NOT change dice probabilities or Ludo movement rules
    | — only the presentation delay and the loop/recovery bounds.
    |
    */
    'turn' => [
        // Human-like "thinking" pause before each bot action (milliseconds).
        'think_min_ms' => (int) env('LUDO_BOT_THINK_MIN_MS', 600),
        'think_max_ms' => (int) env('LUDO_BOT_THINK_MAX_MS', 1200),

        // Hard bound on the actions one bot-turn job may take (infinite-loop
        // guard across consecutive extra turns).
        'max_actions' => (int) env('LUDO_BOT_MAX_ACTIONS', 60),

        // Best-effort per-match execution lock TTL (seconds).
        'lock_seconds' => (int) env('LUDO_BOT_LOCK_SECONDS', 20),

        // The recovery sweep only re-drives a bot turn pending at least this
        // long (seconds) — never a fresh transition.
        'recovery_after_seconds' => (int) env('LUDO_BOT_RECOVERY_SECONDS', 8),
    ],
];
