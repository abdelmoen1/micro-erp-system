<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A platform-admin request that read or changed store data (EnsurePlatformAdmin logs it). */
class AdminAccessLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['admin_id', 'method', 'path', 'target_store_id', 'ip'];
}
