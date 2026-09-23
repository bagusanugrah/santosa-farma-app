<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Receipt extends Model
{
    use HasFactory;

    protected $fillable = [
        'transaction_id',
        'file_path',
    ];

    public function transaction()
    {
        return $this->belongsTo(Transaction::class);
    }
}

