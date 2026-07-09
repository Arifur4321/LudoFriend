<?php

/*
|--------------------------------------------------------------------------
| Cross-Origin Resource Sharing (CORS) Configuration
|--------------------------------------------------------------------------
|
| The mobile app talks to the API over bearer tokens (no cookies), but the
| optional web SPA and the Sanctum CSRF-cookie / broadcasting-auth endpoints
| need CORS. Per the CORS spec, credentials MUST NOT be combined with a
| wildcard origin — so if CORS_ALLOWED_ORIGINS is left as "*", credentials are
| automatically disabled (mobile still works via bearer tokens). For production,
| set CORS_ALLOWED_ORIGINS to an explicit comma-separated allowlist.
|
*/

$origins = array_values(array_filter(array_map(
    'trim',
    explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost,http://localhost:3000')),
)));

$hasWildcard = in_array('*', $origins, true);

return [

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'broadcasting/auth'],

    'allowed_methods' => ['*'],

    'allowed_origins' => $origins,

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    // Credentials cannot be combined with a wildcard origin (CORS spec). When a
    // wildcard is configured we disable credentials to stay valid and safe.
    'supports_credentials' => ! $hasWildcard,

];
