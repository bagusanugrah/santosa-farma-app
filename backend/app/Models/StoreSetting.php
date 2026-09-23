<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StoreSetting extends Model
{
    use HasFactory;

    protected $fillable = [
        'is_open',
        'last_opened_at',
        'last_closed_at',
    ];

    protected $casts = [
        'is_open' => 'boolean',
        'last_opened_at' => 'datetime',
        'last_closed_at' => 'datetime',
    ];

    public static function current(): self
    {
        return self::firstOrCreate(
            ['id' => 1],
            ['is_open' => true, 'last_opened_at' => now()]
        );
    }

    public static function isOpen(): bool
    {
        $setting = self::current();
        return (bool) $setting->is_open;
    }
}

