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
