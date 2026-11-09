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
        if (Schema::hasTable('store_settings') && !Schema::hasColumn('store_settings', 'last_ping_at')) {
            Schema::table('store_settings', function (Blueprint $table) {
                $table->timestamp('last_ping_at')->nullable()->after('last_closed_at');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('store_settings') && Schema::hasColumn('store_settings', 'last_ping_at')) {
            Schema::table('store_settings', function (Blueprint $table) {
                $table->dropColumn('last_ping_at');
            });
        }
    }
};

