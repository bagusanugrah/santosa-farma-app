<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'invoice_no',
        'channel',
        'customer_id',
        'cashier_id',
        'payment_method',
        'midtrans_order_id',
        'midtrans_snap_token',
        'midtrans_qris_url',
        'midtrans_va_number',
        'status',
        'total',
        'amount_paid',
        'change_amount',
        'qr_token',
        'paid_at',
        'picked_up_at',
    ];

    protected $casts = [
        'total' => 'float',
        'amount_paid' => 'float',
        'change_amount' => 'float',
        'paid_at' => 'datetime',
        'picked_up_at' => 'datetime',
    ];

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function cashier()
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function items()
    {
        return $this->hasMany(TransactionItem::class);
    }

    public function receipt()
    {
        return $this->hasOne(Receipt::class);
    }
}

