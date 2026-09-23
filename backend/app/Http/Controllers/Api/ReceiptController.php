<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\ReceiptPdfService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ReceiptController extends Controller
{
    protected ReceiptPdfService $receiptPdfService;

    public function __construct(ReceiptPdfService $receiptPdfService)
    {
        $this->receiptPdfService = $receiptPdfService;
    }

    /**
     * Download or stream PDF receipt.
     */
    public function downloadReceipt(string $transactionId)
    {
        $transaction = Transaction::with(['items', 'customer', 'cashier', 'receipt'])
            ->where('id', $transactionId)
            ->orWhere('invoice_no', $transactionId)
            ->first();

        if (!$transaction) {
            return response()->json([
                'status' => 'error',
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        $pdf = $this->receiptPdfService->getReceiptPdf($transaction);

        return $pdf->stream('struk-' . $transaction->invoice_no . '.pdf');
    }
}

