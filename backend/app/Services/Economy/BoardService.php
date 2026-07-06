<?php

namespace App\Services\Economy;

use RuntimeException;

/**
 * BoardService — resolves staked board tiers from config/economy.php and
 * validates that a requested (tier, mode, team) combination is playable.
 */
class BoardService
{
    /** All tiers, ordered. */
    public function all(): array
    {
        $tiers = config('economy.tiers', []);
        usort($tiers, fn ($a, $b) => ($a['order'] ?? 0) <=> ($b['order'] ?? 0));

        return $tiers;
    }

    public function keys(): array
    {
        return array_column($this->all(), 'key');
    }

    public function find(string $key): ?array
    {
        foreach ($this->all() as $tier) {
            if (($tier['key'] ?? null) === $key) {
                return $tier;
            }
        }

        return null;
    }

    public function findOrFail(string $key): array
    {
        $tier = $this->find($key);
        if (! $tier) {
            throw new RuntimeException("Unknown board tier: {$key}.");
        }

        return $tier;
    }

    public function stakeFor(string $key): int
    {
        return (int) $this->findOrFail($key)['stake'];
    }

    /**
     * Validate a tier is playable for the given mode / team choice.
     *
     * @throws RuntimeException
     */
    public function assertPlayable(string $key, string $mode, bool $teamMode): void
    {
        $tier = $this->findOrFail($key);

        if (! in_array($mode, $tier['modes'] ?? ['2p', '4p'], true)) {
            throw new RuntimeException("This board does not support {$mode} mode.");
        }

        if ($teamMode) {
            if ($mode !== '4p') {
                throw new RuntimeException('Team mode is only available on 4-player boards.');
            }
            if (! ($tier['team'] ?? false)) {
                throw new RuntimeException('This board does not support team mode.');
            }
        }
    }
}
