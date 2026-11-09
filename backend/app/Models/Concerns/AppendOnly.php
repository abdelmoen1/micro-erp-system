<?php

namespace App\Models\Concerns;

use LogicException;

/** Financial and audit rows are written once: no update, no delete through the model. */
trait AppendOnly
{
    public static function bootAppendOnly(): void
    {
        static::updating(fn() => throw new LogicException(static::class . ' rows are append-only.'));
        static::deleting(fn() => throw new LogicException(static::class . ' rows are append-only.'));
    }
}
