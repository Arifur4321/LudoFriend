<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Broadcaster
    |--------------------------------------------------------------------------
    |
    | Ludo Friends uses the Pusher protocol via Laravel Reverb (Soketi is
    | wire-compatible and can be dropped in by pointing the same config at it).
    |
    */

    'default' => env('BROADCAST_CONNECTION', 'reverb'),

    /*
    |--------------------------------------------------------------------------
    | Broadcast Connections
    |--------------------------------------------------------------------------
    */

    'connections' => [

        'reverb' => [
            'driver' => 'reverb',
            'key' => env('REVERB_APP_KEY'),
            'secret' => env('REVERB_APP_SECRET'),
            'app_id' => env('REVERB_APP_ID'),
            'options' => [
                'host' => env('REVERB_HOST'),
                'port' => env('REVERB_PORT', 443),
                'scheme' => env('REVERB_SCHEME', 'https'),
                'useTLS' => env('REVERB_SCHEME', 'https') === 'https',
            ],
            'client_options' => [
                // Guzzle client options for the server -> Reverb HTTP API.
            ],
        ],

        // Generic Pusher connection (also works against Soketi). Switch
        // BROADCAST_CONNECTION=pusher and fill PUSHER_* to use this instead.
        'pusher' => [
            'driver' => 'pusher',
            'key' => env('PUSHER_APP_KEY', env('REVERB_APP_KEY')),
            'secret' => env('PUSHER_APP_SECRET', env('REVERB_APP_SECRET')),
            'app_id' => env('PUSHER_APP_ID', env('REVERB_APP_ID')),
            'options' => [
                'cluster' => env('PUSHER_APP_CLUSTER', 'mt1'),
                'host' => env('PUSHER_HOST', env('REVERB_HOST', 'api-mt1.pusher.com')),
                'port' => env('PUSHER_PORT', env('REVERB_PORT', 443)),
                'scheme' => env('PUSHER_SCHEME', env('REVERB_SCHEME', 'https')),
                'encrypted' => true,
                'useTLS' => env('PUSHER_SCHEME', 'https') === 'https',
            ],
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => env('BROADCAST_REDIS_CONNECTION', 'default'),
        ],

        'log' => [
            'driver' => 'log',
        ],

        'null' => [
            'driver' => 'null',
        ],

    ],

];
