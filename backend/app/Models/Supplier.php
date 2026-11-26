<?php

namespace App\Models;

use App\Support\Money;
use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Who the store buys goods from. What the store owes = Σ invoice totals − Σ payments − Σ returns,
 * each counting only rows that are not voided. A supplier with history is archived, never deleted.
 */
class Supplier extends Model
{
    use BelongsToStore;

    public const STATUS_ACTIVE = 'active';

    public const STATUS_ARCHIVED = 'archived';

    protected $fillable = ['store_id', 'name', 'phone'];

    protected $attributes = ['status' => self::STATUS_ACTIVE];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(PurchaseInvoice::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SupplierPayment::class);
    }

    public function returns(): HasMany
    {
        return $this->hasMany(PurchaseReturn::class);
    }

    public function scopeWithBalance(Builder $query): Builder
    {
        return $query
            ->withSum(['invoices as purchased' => fn(Builder $q) => $q->notVoided()], 'total')
            ->withSum(['payments as paid' => fn(Builder $q) => $q->notVoided()], 'amount')
            ->withSum(['returns as returned' => fn(Builder $q) => $q->notVoided()], 'balance_reduction');
    }

    public function balance(): string
    {
        return Money::sub(
            Money::sub($this->invoices()->notVoided()->sum('total'), $this->payments()->notVoided()->sum('amount')),
            $this->returns()->notVoided()->sum('balance_reduction'),
        );
    }

    public function isArchived(): bool
    {
        return $this->status === self::STATUS_ARCHIVED;
    }

    /** Has the supplier any document at all (voided ones included)? Then it can only be archived. */
    public function hasHistory(): bool
    {
        return $this->invoices()->exists() || $this->payments()->exists() || $this->returns()->exists();
    }

    /** Every delivery line of a product from this supplier. Each one is that product's invoice. */
    public function productLines(int $productId): Builder
    {
        return PurchaseItem::query()
            ->where('product_id', $productId)
            ->whereIn('purchase_invoice_id', $this->invoices()->select('id'));
    }
}
