<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\TransactionItem;
use App\Services\MidtransService;
use App\Services\ReceiptPdfService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class TransactionController extends Controller
{
    protected MidtransService $midtransService;
    protected ReceiptPdfService $receiptPdfService;

    public function __construct(MidtransService $midtransService, ReceiptPdfService $receiptPdfService)
    {
        $this->midtransService = $midtransService;
        $this->receiptPdfService = $receiptPdfService;
    }

    /**
     * List transactions (Super Admin & Admin Kasir).
     */
    public function index(Request $request): JsonResponse
    {
        $query = Transaction::with(['customer', 'cashier', 'items.product'])
            ->orderBy('created_at', 'desc');

        // Filter by channel (toko / online)
        if ($request->filled('channel')) {
            $query->where('channel', $request->channel);
        }

        // Filter by status
        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        // Filter by date range
        if ($request->filled('start_date') && $request->filled('end_date')) {
            $query->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59',
            ]);
        }

        // Search by invoice no or customer name
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('invoice_no', 'like', "%{$search}%")
                  ->orWhereHas('customer', function ($cq) use ($search) {
                      $cq->where('name', 'like', "%{$search}%")
                         ->orWhere('phone', 'like', "%{$search}%");
                  });
            });
        }

        $perPage = (int) $request->input('per_page', 10);
        if (!in_array($perPage, [10, 25, 50, 100])) {
            $perPage = 10;
        }

        $transactions = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'data' => $transactions->items(),
            'meta' => [
                'current_page' => $transactions->currentPage(),
                'per_page' => $transactions->perPage(),
                'total' => $transactions->total(),
                'last_page' => $transactions->lastPage(),
            ],
        ]);
    }

    /**
     * Show single transaction detail.
     */
    public function show(string $id): JsonResponse
    {
        $transaction = Transaction::with(['customer', 'cashier', 'items.product', 'receipt'])
            ->find($id);

        if (!$transaction) {
            return response()->json([
                'status' => 'error',
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $transaction,
        ]);
    }

    /**
     * Store POS Transaction (Toko Kasir).
     */
    public function posCheckout(Request $request): JsonResponse
    {
        // Cancel / Delete pending transaction fallback
        if ($request->input('action') === 'cancel' && $request->filled('transaction_id')) {
            return $this->destroy($request, $request->input('transaction_id'));
        }

        $validator = Validator::make($request->all(), [
            'payment_method' => 'required|in:tunai,qris',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.qty' => 'required|integer|min:1',
            'amount_paid' => 'required_if:payment_method,tunai|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Data transaksi tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $cashier = $request->user();

        return DB::transaction(function () use ($request, $cashier) {
            $invoiceNo = 'INV-POS-' . date('Ymd') . '-' . strtoupper(Str::random(5));
            $itemsData = $request->items;
            $paymentMethod = $request->payment_method;

            $total = 0;
            $transactionItems = [];

            foreach ($itemsData as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']);

                if ($product->stock < $item['qty']) {
                    throw new \Exception("Stok {$product->name} tidak mencukupi (sisa: {$product->stock}).");
                }

                $subtotal = $product->price * $item['qty'];
                $total += $subtotal;

                $transactionItems[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'qty' => $item['qty'],
                    'price' => $product->price,
                    'subtotal' => $subtotal,
                ];

                // If cash, deduct stock immediately
                if ($paymentMethod === 'tunai') {
                    $product->decrement('stock', $item['qty']);
                }
            }

            $amountPaid = $paymentMethod === 'tunai' ? (float) $request->amount_paid : $total;
            $changeAmount = $paymentMethod === 'tunai' ? max(0, $amountPaid - $total) : 0;

            if ($paymentMethod === 'tunai' && $amountPaid < $total) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Jumlah uang yang dibayarkan kurang dari total belanja.',
                ], 422);
            }

            $transaction = Transaction::create([
                'invoice_no' => $invoiceNo,
                'channel' => 'toko',
                'cashier_id' => $cashier->id,
                'payment_method' => $paymentMethod,
                'status' => $paymentMethod === 'tunai' ? 'selesai' : 'pending',
                'total' => $total,
                'amount_paid' => $amountPaid,
                'change_amount' => $changeAmount,
                'paid_at' => $paymentMethod === 'tunai' ? now() : null,
            ]);

            foreach ($transactionItems as $tItem) {
                $transaction->items()->create($tItem);
            }

            // Generate receipt PDF if completed
            if ($paymentMethod === 'tunai') {
                $this->receiptPdfService->generateReceipt($transaction);
            }

            // If QRIS, request QR code from Midtrans
            if ($paymentMethod === 'qris') {
                $qrisData = $this->midtransService->createQrisCharge($transaction);
                $transaction->update([
                    'midtrans_qris_url' => $qrisData['qr_url'],
                    'midtrans_order_id' => $invoiceNo,
                ]);
            }

            $transaction->load(['items', 'cashier']);

            return response()->json([
                'status' => 'success',
                'message' => 'Transaksi POS berhasil dibuat.',
                'data' => $transaction,
            ], 201);
        });
    }

    /**
     * Get the latest active pending QRIS POS transaction (for Android Kasir display).
     */
    public function activeQris(): JsonResponse
    {
        $transaction = Transaction::with(['items', 'cashier'])
            ->where('channel', 'toko')
            ->where('payment_method', 'qris')
            ->where('status', 'pending')
            ->where('created_at', '>=', now()->subMinutes(15))
            ->orderBy('created_at', 'desc')
            ->first();

        if (!$transaction) {
            return response()->json([
                'status' => 'success',
                'data' => null,
                'message' => 'Tidak ada transaksi QRIS aktif saat ini.',
            ]);
        }

        return response()->json([
            'status' => 'success',
            'data' => $transaction,
        ]);
    }

    /**
     * Customer Online Checkout (Web Client).
     */
    public function onlineCheckout(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.qty' => 'required|integer|min:1',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Data checkout tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $customer = $request->user();

        return DB::transaction(function () use ($request, $customer) {
            $invoiceNo = 'INV-ONL-' . date('Ymd') . '-' . strtoupper(Str::random(5));
            $itemsData = $request->items;

            $total = 0;
            $transactionItems = [];

            foreach ($itemsData as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']);

                if ($product->stock < $item['qty']) {
                    return response()->json([
                        'status' => 'error',
                        'message' => "Stok obat {$product->name} tidak mencukupi (sisa: {$product->stock}).",
                    ], 422);
                }

                $subtotal = $product->price * $item['qty'];
                $total += $subtotal;

                $transactionItems[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'qty' => $item['qty'],
                    'price' => $product->price,
                    'subtotal' => $subtotal,
                ];
            }

            $transaction = Transaction::create([
                'invoice_no' => $invoiceNo,
                'channel' => 'online',
                'customer_id' => $customer->id,
                'payment_method' => 'qris', // Default placeholder until Midtrans webhook updates specific channel
                'status' => 'pending',
                'total' => $total,
                'midtrans_order_id' => $invoiceNo,
            ]);

            foreach ($transactionItems as $tItem) {
                $transaction->items()->create($tItem);
            }

            $transaction->load(['items', 'customer']);

            // Get Midtrans Snap Token
            $snapToken = $this->midtransService->createSnapToken($transaction);
            $transaction->update(['midtrans_snap_token' => $snapToken]);

            return response()->json([
                'status' => 'success',
                'message' => 'Checkout berhasil. Silakan selesaikan pembayaran.',
                'data' => [
                    'transaction' => $transaction,
                    'snap_token' => $snapToken,
                ],
            ], 201);
        });
    }

    /**
     * Customer My Orders.
     */
    public function myOrders(Request $request): JsonResponse
    {
        $customer = $request->user();

        $transactions = Transaction::with(['items.product'])
            ->where('customer_id', $customer->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $transactions,
        ]);
    }

    /**
     * Cashier Scan Customer Pickup QR Code (Android Kasir).
     */
    public function getOrderByQr(string $qrToken): JsonResponse
    {
        $transaction = Transaction::with(['customer', 'items.product'])
            ->where('qr_token', $qrToken)
            ->first();

        if (!$transaction) {
            return response()->json([
                'status' => 'error',
                'message' => 'QR Code pesanan tidak valid atau tidak ditemukan.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $transaction,
        ]);
    }

    /**
     * Cashier Confirms Order Pickup (Scan QR Android Kasir or Direct Desktop App).
     */
    public function confirmPickup(Request $request, string $qrToken): JsonResponse
    {
        $transaction = Transaction::with(['customer', 'items.product', 'cashier'])
            ->where('qr_token', $qrToken)
            ->orWhere('id', $qrToken)
            ->orWhere('invoice_no', $qrToken)
            ->first();

        if (!$transaction) {
            return response()->json([
                'status' => 'error',
                'message' => 'Pesanan atau QR Code tidak ditemukan.',
            ], 404);
        }

        if ($transaction->status === 'diambil' || $transaction->status === 'selesai') {
            return response()->json([
                'status' => 'error',
                'message' => 'Pesanan ini sudah pernah diambil sebelumnya pada ' . ($transaction->picked_up_at?->format('d/m/Y H:i') ?? 'sesi sebelumnya') . '.',
            ], 400);
        }

        if ($transaction->status !== 'paid') {
            return response()->json([
                'status' => 'error',
                'message' => "Pesanan belum dapat diambil karena status pembayaran saat ini adalah: {$transaction->status}.",
            ], 400);
        }

        $user = $request->user();
        $transaction->update([
            'status' => 'diambil',
            'picked_up_at' => now(),
            'cashier_id' => $user?->id ?? $transaction->cashier_id,
        ]);

        // Generate receipt PDF for pickup
        $this->receiptPdfService->generateReceipt($transaction);

        return response()->json([
            'status' => 'success',
            'message' => 'Pengambilan pesanan berhasil dikonfirmasi.',
            'data' => $transaction->fresh(['customer', 'cashier', 'items.product']),
        ]);
    }

    /**
     * Cashier Confirms Order Pickup directly by ID / Invoice (Desktop App).
     */
    public function confirmPickupById(Request $request, int|string $id): JsonResponse
    {
        return $this->confirmPickup($request, (string) $id);
    }

    /**
     * Delete or Cancel Pending / Expired / Failed Transaction (Staff Kasir & Super Admin).
     */
    public function destroy(Request $request, int|string $id): JsonResponse
    {
        $transaction = Transaction::where('id', $id)
            ->orWhere('invoice_no', $id)
            ->first();

        if (!$transaction) {
            return response()->json([
                'status' => 'error',
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        // Only allow deleting pending, expired, or failed transactions
        if (!in_array($transaction->status, ['pending', 'expired', 'gagal'])) {
            return response()->json([
                'status' => 'error',
                'message' => "Transaksi dengan status '{$transaction->status}' tidak dapat dihapus karena sudah dibayar/selesai.",
            ], 400);
        }

        $invoiceNo = $transaction->invoice_no;

        DB::transaction(function () use ($transaction) {
            // Delete related items
            $transaction->items()->delete();

            // Delete receipt if any
            if ($transaction->receipt) {
                $transaction->receipt()->delete();
            }

            $transaction->delete();
        });

        return response()->json([
            'status' => 'success',
            'message' => "Transaksi {$invoiceNo} berhasil dihapus.",
        ]);
    }
}

