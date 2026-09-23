<?php

namespace App\Services;

use App\Models\Transaction;
use Illuminate\Support\Facades\Log;
use Midtrans\Config;
use Midtrans\Snap;
use Midtrans\CoreApi;

class MidtransService
{
    public function __construct()
    {
        Config::$serverKey = config('midtrans.server_key', 'SB-Mid-server-demo');
        Config::$clientKey = config('midtrans.client_key', 'SB-Mid-client-demo');
        Config::$isProduction = (bool) config('midtrans.is_production', false);
        Config::$isSanitized = (bool) config('midtrans.is_sanitized', true);
        Config::$is3ds = (bool) config('midtrans.is_3ds', true);
    }

    /**
     * Create Snap Token for online checkout.
     */
    public function createSnapToken(Transaction $transaction): string
    {
        $items = [];
        foreach ($transaction->items as $item) {
            $items[] = [
                'id' => (string) $item->product_id,
                'price' => (int) round($item->price),
                'quantity' => (int) $item->qty,
                'name' => mb_substr($item->product_name, 0, 50),
            ];
        }

        $customerDetails = [
            'first_name' => $transaction->customer?->name ?? 'Customer Online',
            'email' => $transaction->customer?->email ?? 'customer@example.com',
            'phone' => $transaction->customer?->phone ?? '08123456789',
        ];

        $params = [
            'transaction_details' => [
                'order_id' => $transaction->invoice_no,
                'gross_amount' => (int) round($transaction->total),
            ],
            'item_details' => $items,
            'customer_details' => $customerDetails,
            'callbacks' => [
                'finish' => env('WEB_URL', 'http://localhost:3000') . '/orders/' . $transaction->invoice_no,
            ],
        ];

        try {
            // If Midtrans server key is valid sandbox/prod key, call Midtrans Snap
            if (!str_contains(Config::$serverKey, 'demo')) {
                $snapToken = Snap::getSnapToken($params);
                return $snapToken;
            }
        } catch (\Exception $e) {
            Log::warning("[Midtrans Snap Exception] " . $e->getMessage() . " - Falling back to local mock token.");
        }

        // Mock token for sandbox demo
        return 'mock-snap-token-' . $transaction->invoice_no . '-' . md5(uniqid());
    }

    /**
     * Create Core API QRIS charge for Toko POS.
     */
    public function createQrisCharge(Transaction $transaction): array
    {
        $params = [
            'payment_type' => 'qris',
            'transaction_details' => [
                'order_id' => $transaction->invoice_no,
                'gross_amount' => (int) round($transaction->total),
            ],
            'qris' => [
                'acquirer' => 'gopay',
            ],
        ];

        try {
            if (!str_contains(Config::$serverKey, 'demo')) {
                $response = CoreApi::charge($params);
                $qrString = $response->qr_string ?? null;
                $actions = $response->actions ?? [];
                $qrUrl = null;
                foreach ($actions as $action) {
                    if (isset($action->name) && $action->name === 'generate-qr-code') {
                        $qrUrl = $action->url;
                    }
                }
                return [
                    'qr_string' => $qrString,
                    'qr_url' => $qrUrl ?? "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($qrString ?? $transaction->invoice_no),
                ];
            }
        } catch (\Exception $e) {
            Log::warning("[Midtrans QRIS Charge Exception] " . $e->getMessage() . " - Falling back to local mock QRIS.");
        }

        // Mock QRIS payload
        $mockQrString = "00020101021226580016ID.CO.SHOPEE.WWW01189360099800000000000208" . $transaction->invoice_no . "520458125303360540" . round($transaction->total) . "5802ID5919Apotek Santosa Farma6006SUBANG6304";
        return [
            'qr_string' => $mockQrString,
            'qr_url' => "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($mockQrString),
        ];
    }

    /**
     * Verify Webhook Signature Key.
     */
    public function verifySignature(string $orderId, string $statusCode, string $grossAmount, string $signatureKey): bool
    {
        $serverKey = Config::$serverKey;
        $calculatedSignature = hash("sha512", $orderId . $statusCode . $grossAmount . $serverKey);
        return hash_equals($calculatedSignature, $signatureKey);
    }
}
