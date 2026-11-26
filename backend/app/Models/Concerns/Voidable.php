<?php

namespace App\Models\Concerns;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A posted document that is never deleted: a mistake is voided. The row keeps its amounts and
 * records when, by whom and why; ledgers count only rows that are not voided (`scopeNotVoided`).
 */
trait Voidable
{
    public function initializeVoidable(): void
    {
        $this->mergeCasts(['voided_at' => 'datetime']);
    }

    public function scopeNotVoided(Builder $query): Builder
    {
        return $query->whereNull($query->qualifyColumn('voided_at'));
    }

    public function voider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'voided_by');
    }

    public function isVoided(): bool
    {
        return $this->voided_at !== null;
    }

    /** Fields written by a void, kept out of `$fillable` so no request can set them. */
    public function markVoided(User $actor, string $reason): void
    {
        $this->forceFill([
            'voided_at' => now(),
            'voided_by' => $actor->id,
            'void_reason' => $reason,
        ])->save();
    }
}
