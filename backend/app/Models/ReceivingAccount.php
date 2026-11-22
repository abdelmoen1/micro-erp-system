<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ReceivingAccount extends Model
{
    use BelongsToStore, SoftDeletes;

    protected $fillable = [
        'store_id', 'provider', 'account_name', 'account_identifier',
        'active', 'created_by', 'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'active' => 'boolean',
            'deleted_at' => 'datetime',
        ];
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function editor()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
