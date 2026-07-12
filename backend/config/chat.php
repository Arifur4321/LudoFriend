<?php

return [

    /*
    |--------------------------------------------------------------------------
    | In-match chat / emoji
    |--------------------------------------------------------------------------
    |
    | Guests may only send from `quick_phrases` (no free text) to limit abuse.
    | Registered users may send free text up to `max_length`, run through a
    | (configurable) profanity mask. Emoji reactions are restricted to
    | `allowed_emojis`. `presence_ttl` is how long an online ping is trusted.
    |
    */

    'max_length' => 200,

    'presence_ttl' => 60, // seconds

    // Most recent messages returned per history page (hard cap on `limit`).
    'history_max' => 50,

    // Per-user, per-minute send limits (overridable via RATE_LIMIT_CHAT /
    // RATE_LIMIT_EMOJI env). Applied by the 'chat' / 'emoji' rate limiters.
    'rate_per_minute' => 20,
    'emoji_rate_per_minute' => 15,

    'quick_phrases' => [
        'Hi! 👋',
        'Good luck!',
        'Nice move!',
        'Oh no! 😅',
        'Well played 👏',
        'Hurry up ⏳',
        'Rematch?',
    ],

    'allowed_emojis' => ['😀', '😂', '😮', '😎', '😭', '👍', '🎉', '🔥', '❤️', '😡'],

    // Populate with words to mask in free-text messages (case-insensitive,
    // whole-word). Left empty by default; extend per your moderation policy.
    'profanity' => [],

];
