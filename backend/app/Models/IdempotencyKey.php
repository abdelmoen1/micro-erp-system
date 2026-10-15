<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IdempotencyKey extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'store_id',
        'user_id',
        'key',
        'request_hash',
        'method_path',
        'response_status',
        'response_body',
    ];
}
