<?php

namespace App\Services\Game;

/**
 * BotIdentityService — picks realistic, human-looking display names for bot
 * seats from a configurable pool (config/bots.php). Names are chosen randomly
 * and kept unique within a single match while the pool has spare names.
 *
 * Cosmetic only: this never touches bot AI, turns, dice or timeout logic.
 */
class BotIdentityService
{
    /**
     * The flat, de-duplicated pool of candidate names (union of all groups).
     *
     * @return list<string>
     */
    public function pool(): array
    {
        $groups = (array) config('bots.name_pools', []);
        $names = [];
        foreach ($groups as $group) {
            foreach ((array) $group as $name) {
                $name = trim((string) $name);
                if ($name !== '') {
                    $names[] = $name;
                }
            }
        }

        // Preserve order but drop duplicates across groups.
        return array_values(array_unique($names));
    }

    /**
     * Pick a bot name not already present in $taken. When the pool is exhausted
     * (more bots than names — not expected for a 4-seat board) a numeric suffix
     * keeps the name unique so two bots never collide.
     *
     * @param  iterable<string|null>  $taken  names already used in this match
     */
    public function pickUnique(iterable $taken = []): string
    {
        $used = [];
        foreach ($taken as $t) {
            if ($t !== null && $t !== '') {
                $used[strtolower((string) $t)] = true;
            }
        }

        $available = array_values(array_filter(
            $this->pool(),
            fn (string $n) => ! isset($used[strtolower($n)])
        ));

        if ($available !== []) {
            return $available[random_int(0, count($available) - 1)];
        }

        // Pool exhausted: fall back to a suffixed name that is still unique.
        $base = $this->pool();
        $seed = $base !== [] ? $base[random_int(0, count($base) - 1)] : 'Player';
        $n = 2;
        while (isset($used[strtolower($base = $seed.' '.$n)])) {
            $n++;
        }

        return $seed.' '.$n;
    }

    /** Default avatar for a bot (null => client renders initials). */
    public function defaultAvatar(): ?string
    {
        $a = config('bots.default_avatar');

        return is_string($a) && $a !== '' ? $a : null;
    }
}
