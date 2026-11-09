<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (Schema::hasTable('store_settings') && !Schema::hasColumn('store_settings', 'online_orders_enabled')) {
            Schema::table('store_settings', function (Blueprint $table) {
                $table->boolean('online_orders_enabled')->default(false)->after('is_open');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('store_settings') && Schema::hasColumn('store_settings', 'online_orders_enabled')) {
            Schema::table('store_settings', function (Blueprint $table) {
                $table->dropColumn('online_orders_enabled');
            });
        }
    }
};

