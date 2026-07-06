<?php

/*
|--------------------------------------------------------------------------
| Economy configuration (single source of truth)
|--------------------------------------------------------------------------
|
| Board tiers, the daily-spin wheel, purchasable coin packs, and social /
| store feature flags. Server-authoritative: the client renders these but the
| server always re-reads them when validating stakes, spins, and purchases.
|
*/

return [

    /*
    |--------------------------------------------------------------------------
    | Starting wallet
    |--------------------------------------------------------------------------
    | New accounts are seeded with `starting_coins` (also mirrored in ludo.php
    | for backward compatibility). The seed is written to the ledger as a
    | `signup_bonus` transaction.
    */
    'starting_coins' => (int) env('LUDO_STARTING_COINS', 500),

    /*
    |--------------------------------------------------------------------------
    | Payout model
    |--------------------------------------------------------------------------
    | Pure winner-takes-all: the whole pot goes to the winner (or is split
    | evenly across the winning team). `house_rake_bps` is kept at 0 so the
    | mechanism exists but takes nothing; set >0 (basis points, 100 = 1%) to
    | enable a commission later without touching code.
    */
    // Active matches idle longer than this are aborted and refunded.
    'match_idle_abort_minutes' => (int) env('LUDO_MATCH_IDLE_ABORT_MINUTES', 30),

    'house_rake_bps' => (int) env('LUDO_HOUSE_RAKE_BPS', 0),

    /*
    |--------------------------------------------------------------------------
    | Board tiers
    |--------------------------------------------------------------------------
    | `key` is stable and stored on rooms/matches. `stake` is the per-seat
    | buy-in in coins. `min_players`/`modes` gate availability. `team` marks
    | tiers that allow 2v2 on 4p. `accent`/`badge` give the client a consistent
    | premium identity per tier (the Flutter BoardTheme keys off `key`).
    */
    'tiers' => [
        [
            // Free practice table used by quick match / bot-fill and offline.
            // Hidden from the staked board list (stake 0, no escrow).
            'key' => 'casual', 'name' => 'Casual', 'stake' => 0,
            'order' => 0, 'modes' => ['2p', '4p'], 'team' => true, 'hidden' => true,
            'accent' => '#90A4AE', 'badge' => 'Free',
            'description' => 'Play for fun — no coins at stake.',
        ],
        [
            'key' => 'classic', 'name' => 'Classic Arena', 'stake' => 200,
            'order' => 1, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#4CAF50', 'badge' => 'Starter',
            'description' => 'Where every legend begins.',
        ],
        [
            'key' => 'bronze', 'name' => 'Bronze Bazaar', 'stake' => 500,
            'order' => 2, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#CD7F32', 'badge' => 'Bronze',
            'description' => 'Warm up your wallet.',
        ],
        [
            'key' => 'silver', 'name' => 'Silver Summit', 'stake' => 1000,
            'order' => 3, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#B0BEC5', 'badge' => 'Silver',
            'description' => 'Sharper play, bigger pots.',
        ],
        [
            'key' => 'gold', 'name' => 'Golden Colosseum', 'stake' => 5000,
            'order' => 4, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#FFC107', 'badge' => 'Gold',
            'description' => 'For seasoned challengers.',
        ],
        [
            'key' => 'emerald', 'name' => 'Emerald Empire', 'stake' => 10000,
            'order' => 5, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#00BFA5', 'badge' => 'Emerald',
            'description' => 'High rollers only.',
        ],
        [
            'key' => 'diamond', 'name' => 'Diamond Throne', 'stake' => 20000,
            'order' => 6, 'modes' => ['2p', '4p'], 'team' => true,
            'accent' => '#7C4DFF', 'badge' => 'Diamond',
            'description' => 'The ultimate table.',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Free spin
    |--------------------------------------------------------------------------
    | Weighted wheel, rare jackpots, claimable once every
    | `interval_minutes` (rolling cooldown from the last spin; default 60 min).
    | Weights are integers; probability = weight / sum(weights). The 20,000
    | jackpot sits at 0.5%; EV ≈ 1,435 coins per spin.
    |
    | Note: with a 60-minute interval a player can claim up to ~24 spins/day
    | (~34k coins/day average). Lower the segment rewards or raise
    | interval_minutes here if you want the coin economy to be tighter relative
    | to the 200–20,000 boards.
    */
    'free_spin' => [
        'enabled' => (bool) env('LUDO_FREE_SPIN_ENABLED', true),
        'interval_minutes' => (int) env('LUDO_FREE_SPIN_INTERVAL_MINUTES', 60),
        'segments' => [
            ['reward' => 500,   'weight' => 300],
            ['reward' => 750,   'weight' => 220],
            ['reward' => 1000,  'weight' => 200],
            ['reward' => 1500,  'weight' => 130],
            ['reward' => 2500,  'weight' => 80],
            ['reward' => 5000,  'weight' => 45],
            ['reward' => 10000, 'weight' => 20],
            ['reward' => 20000, 'weight' => 5],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Coin store (IAP)
    |--------------------------------------------------------------------------
    | `verify_receipts` stays false until real store credentials are wired, so
    | purchases are recorded but credited only in trusted/dev flows. Product ids
    | must match the App Store / Play Console entries.
    */
    'store' => [
        'enabled' => (bool) env('LUDO_STORE_ENABLED', true),
        'verify_receipts' => (bool) env('LUDO_STORE_VERIFY_RECEIPTS', false),
        'google_play_package' => env('LUDO_ANDROID_PACKAGE', 'com.ludofriends.app'),
        'apple_shared_secret' => env('APPLE_IAP_SHARED_SECRET'),
        'packs' => [
            ['product_id' => 'com.ludofriends.coins.handful', 'coins' => 5000,   'bonus' => 0,     'price' => '0.99',  'label' => 'Handful'],
            ['product_id' => 'com.ludofriends.coins.stack',   'coins' => 30000,  'bonus' => 3000,  'price' => '4.99',  'label' => 'Stack'],
            ['product_id' => 'com.ludofriends.coins.chest',   'coins' => 80000,  'bonus' => 12000, 'price' => '9.99',  'label' => 'Chest', 'popular' => true],
            ['product_id' => 'com.ludofriends.coins.vault',   'coins' => 200000, 'bonus' => 40000, 'price' => '19.99', 'label' => 'Vault'],
            ['product_id' => 'com.ludofriends.coins.crown',   'coins' => 500000, 'bonus' => 125000,'price' => '49.99', 'label' => 'Crown', 'best_value' => true],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Social login (credentials added later — inert until then)
    |--------------------------------------------------------------------------
    */
    'social' => [
        'google' => [
            'enabled' => (bool) env('GOOGLE_LOGIN_ENABLED', false),
            // Accept ID tokens minted for any of these audiences (web/android/ios).
            'client_ids' => array_values(array_filter([
                env('GOOGLE_CLIENT_ID_WEB'),
                env('GOOGLE_CLIENT_ID_ANDROID'),
                env('GOOGLE_CLIENT_ID_IOS'),
            ])),
        ],
        'facebook' => [
            'enabled' => (bool) env('FACEBOOK_LOGIN_ENABLED', false),
            'app_id' => env('FACEBOOK_APP_ID'),
            'app_secret' => env('FACEBOOK_APP_SECRET'),
        ],
    ],
];
