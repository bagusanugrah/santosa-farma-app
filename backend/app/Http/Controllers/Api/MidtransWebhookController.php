<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Services\MidtransService;
use App\Services\ReceiptPdfService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class MidtransWebhookController extends Controller
{
    protected MidtransService $midtransService;
    protected ReceiptPdfService $receiptPdfService;

    public function __construct(MidtransService $midtransService, ReceiptPdfService $receiptPdfService)
    {
        $this->midtransService = $midtransService;
        $this->receiptPdfService = $receiptPdfService;
    }

    /**
     * Handle Midtrans Payment Notification Webhook
     */
    public function handle(Request $request): JsonResponse
    {
        $payload = $request->all();
        Log::info('[Midtrans Webhook Received]', $payload);

        $orderId = $payload['order_id'] ?? null;
        $statusCode = $payload['status_code'] ?? null;
        $grossAmount = $payload['gross_amount'] ?? null;
        $signatureKey = $payload['signature_key'] ?? null;
        $transactionStatus = $payload['transaction_status'] ?? null;
        $fraudStatus = $payload['fraud_status'] ?? null;
        $paymentType = $payload['payment_type'] ?? null;

        if (!$orderId) {
            return response()->json(['status' => 'error', 'message' => 'Missing order_id'], 400);
        }

        // Verify signature if signature_key is present and not mock
        $serverKey = config('midtrans.server_key', '');
        if ($signatureKey && !str_contains($serverKey, 'demo')) {
            $isValid = $this->midtransService->verifySignature($orderId, $statusCode, $grossAmount, $signatureKey);
            if (!$isValid) {
                Log::warning("[Midtrans Webhook] Invalid signature key for Order: {$orderId}");
                return response()->json(['status' => 'error', 'message' => 'Invalid signature'], 403);
            }
        }

        $transaction = Transaction::where('invoice_no', $orderId)
            ->orWhere('midtrans_order_id', $orderId)
            ->first();

        if (!$transaction) {
            Log::warning("[Midtrans Webhook] Transaction not found for Order ID: {$orderId}");
            return response()->json(['status' => 'error', 'message' => 'Transaction not found'], 404);
        }

        // Map payment type to internal enum (tunai, qris, kartu, va)
        $mappedMethod = $transaction->payment_method;
        if ($paymentType) {
            if (in_array($paymentType, ['qris', 'gopay', 'shopeepay'])) {
                $mappedMethod = 'qris';
            } elseif (in_array($paymentType, ['credit_card', 'card'])) {
                $mappedMethod = 'kartu';
            } elseif (in_array($paymentType, ['bank_transfer', 'echannel', 'permata_va', 'cstore'])) {
                $mappedMethod = 'va';
            }
        }

        // Extract VA number if available
        $vaNumber = null;
        if (isset($payload['va_numbers'][0]['va_number'])) {
            $vaNumber = $payload['va_numbers'][0]['bank'] . ': ' . $payload['va_numbers'][0]['va_number'];
        } elseif (isset($payload['permata_va_number'])) {
            $vaNumber = 'Permata: ' . $payload['permata_va_number'];
        } elseif (isset($payload['bill_key'])) {
            $vaNumber = 'Mandiri: ' . $payload['bill_key'];
        }

        return DB::transaction(function () use ($transaction, $transactionStatus, $fraudStatus, $mappedMethod, $vaNumber) {
            $currentStatus = $transaction->status;

            if ($transactionStatus == 'capture') {
                if ($fraudStatus == 'challenge') {
                    $transaction->update(['status' => 'pending']);
                } else if ($fraudStatus == 'accept') {
                    $this->markAsPaid($transaction, $mappedMethod, $vaNumber);
                }
            } else if ($transactionStatus == 'settlement') {
                $this->markAsPaid($transaction, $mappedMethod, $vaNumber);
            } else if ($transactionStatus == 'pending') {
                $transaction->update([
                    'status' => 'pending',
                    'payment_method' => $mappedMethod,
                    'midtrans_va_number' => $vaNumber ?? $transaction->midtrans_va_number,
                ]);
            } else if (in_array($transactionStatus, ['deny', 'cancel', 'expire'])) {
                $newStatus = $transactionStatus === 'expire' ? 'expired' : 'gagal';
                $transaction->update([
                    'status' => $newStatus,
                ]);
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Notification processed successfully',
            ]);
        });
    }

    /**
     * Helper to mark transaction as paid, deduct stock for online, generate QR token, generate receipt.
     */
    protected function markAsPaid(Transaction $transaction, string $paymentMethod, ?string $vaNumber): void
    {
        $alreadyPaid = in_array($transaction->status, ['paid', 'selesai', 'diambil']);

        if (!$alreadyPaid) {
            // Deduct stock for online orders (toko cash already deducted on creation)
            if ($transaction->channel === 'online' || ($transaction->channel === 'toko' && $transaction->payment_method === 'qris')) {
                foreach ($transaction->items as $item) {
                    $product = Product::find($item->product_id);
                    if ($product) {
                        $product->decrement('stock', $item->qty);
                    }
                }
            }

            // Generate unique Pickup QR token for online orders
            $qrToken = $transaction->channel === 'online' ? 'PKP-' . Str::random(24) : null;
            $newStatus = $transaction->channel === 'toko' ? 'selesai' : 'paid';

            $transaction->update([
                'status' => $newStatus,
                'payment_method' => $paymentMethod,
                'midtrans_va_number' => $vaNumber ?? $transaction->midtrans_va_number,
                'paid_at' => now(),
                'qr_token' => $qrToken,
            ]);

            // Generate receipt PDF
            $this->receiptPdfService->generateReceipt($transaction);
        }
    }
}
