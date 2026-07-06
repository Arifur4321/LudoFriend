<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * Thrown when a wallet debit would take the balance below zero. Carries the
 * amounts so callers can produce a precise, user-facing message.
 */
class InsufficientCoinsException extends RuntimeException
{
    public function __construct(
        public readonly int $required,
        public readonly int $available,
        string $message = ''
    ) {
        parent::__construct(
            $message !== '' ? $message
                : "Not enough coins: need {$required}, have {$available}."
        );
    }
}
