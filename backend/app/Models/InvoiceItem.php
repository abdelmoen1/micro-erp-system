<?php

namespace App\Models;

use App\Support\Pack;
use Illuminate\Database\Eloquent\Model;

/**
 * A sale line. `unit_price`, `unit`, `pack_size` and `total` (the line total) are snapshots taken
 * at the sale, so later product edits (a new carton size or price) never change history. Legacy
 * lines have no product, and no pack_size (sold in the base unit).
 */
class InvoiceItem extends Model
{
    protected $fillable = [
        'invoice_id',
        'product_id',
        'item_name',
        'unit',
        'quantity',
        'pack_size',
        'returned_quantity',
        'unit_price',
        'total',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'returned_quantity' => 'decimal:3',
            'pack_size' => 'integer',
            'unit_price' => 'decimal:2',
            'total' => 'decimal:2',
        ];
    }

    /** Sold by the carton: quantity, returned_quantity and unit_price are per carton of pack_size. */
    public function isPack(): bool
    {
        return $this->pack_size !== null;
    }

    /** Pieces (or kg) behind [quantity] of this line's unit; stock moves by this. */
    public function baseQuantity(string $quantity): string
    {
        return Pack::baseQuantity($quantity, $this->pack_size);
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
