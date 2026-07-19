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
];
