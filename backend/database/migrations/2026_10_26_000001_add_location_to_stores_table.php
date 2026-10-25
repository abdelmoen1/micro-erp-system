<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Store location: `area` (city / governorate, for grouping and filtering stores) and optional map
 * coordinates. Both are store profile data, visible only to the store's own members and the
 * platform admin.
 *
 * Backfill: the web and mobile registration forms saved the city inside `address` as
 * "street، city". A store gets that city as its `area` only when the address ends with exactly one
 * of the cities those forms offered; every other address is left for the owner to set. `address`
 * itself is never changed, and no coordinates are guessed.
 */
return new class extends Migration
{
    /** The registration forms' city list when this migration was written (web Join.jsx, mobile registration_form.dart). */
    private const REGISTRATION_CITIES = [
        'الخليل', 'بيت لحم', 'القدس', 'رام الله والبيرة', 'نابلس', 'جنين', 'طولكرم', 'قلقيلية',
        'سلفيت', 'طوباس', 'أريحا', 'غزة', 'شمال غزة', 'دير البلح', 'خان يونس', 'رفح',
    ];

    public function up(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->string('area', 100)->nullable()->after('address')->index();
            // 6 decimal places ≈ 0.1 m; enough for a shop front.
            $table->decimal('latitude', 9, 6)->nullable()->after('area');
            $table->decimal('longitude', 9, 6)->nullable()->after('latitude');
        });

        $this->backfill();
    }

    private function backfill(): void
    {
        // By id, not by offset: each update drops the row from `whereNull('area')`.
        DB::table('stores')->whereNull('area')->whereNotNull('address')->select(['id', 'address'])
            ->lazyById(100)
            ->each(function ($store) {
                $parts = preg_split('/\s*،\s*/u', trim($store->address));
                $city = trim((string) end($parts));
                if (count($parts) > 1 && in_array($city, self::REGISTRATION_CITIES, true)) {
                    DB::table('stores')->where('id', $store->id)->update(['area' => $city]);
                }
            });
    }

    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropIndex(['area']);
            $table->dropColumn(['area', 'latitude', 'longitude']);
        });
    }
};
