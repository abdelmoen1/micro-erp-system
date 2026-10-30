<?php

namespace App\Models;

use App\Support\Money;
use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Who the store buys goods from. What the store owes = Σ invoice totals − Σ payments. */
class Supplier extends Model
{
    use BelongsToStore;

    protected $fillable = ['store_id', 'name', 'phone'];

    public function invoices(): HasMany
    {
        return $this->hasMany(PurchaseInvoice::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SupplierPayment::class);
    }

    public function scopeWithBalance(Builder $query): Builder
    {
        return $query->withSum('invoices as purchased', 'total')->withSum('payments as paid', 'amount');
    }

    public function balance(): string
    {
        return Money::sub($this->invoices()->sum('total'), $this->payments()->sum('amount'));
    }
}
