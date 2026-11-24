<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;

class SuspendedInvoice extends Model
{
    use BelongsToStore;

    public const STATUS_DRAFT = 'draft';
    public const STATUS_PENDING_TRANSFER = 'pending_transfer';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'store_id', 'reference', 'customer_id', 'cashier_id', 'status',
        'subtotal', 'discount_amount', 'total_amount', 'payment_method',
        'receiving_account_id', 'account_snapshot_name', 'account_snapshot_provider',
        'account_snapshot_identifier', 'final_invoice_id', 'idempotency_key',
        'notes', 'cancellation_reason', 'closed_by', 'closed_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'discount_amount' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'closed_at' => 'datetime',
        ];
    }

    public function customer() { return $this->belongsTo(Customer::class); }
    public function cashier() { return $this->belongsTo(User::class, 'cashier_id'); }
    public function items() { return $this->hasMany(SuspendedInvoiceItem::class); }
    public function reservations() { return $this->hasMany(InventoryReservation::class); }
    public function events() { return $this->hasMany(SuspendedInvoiceEvent::class); }
    public function finalInvoice() { return $this->belongsTo(Invoice::class, 'final_invoice_id'); }
    public function receivingAccount() { return $this->belongsTo(ReceivingAccount::class); }
}
