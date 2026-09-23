<?php

namespace App\Services;

use App\Models\Receipt;
use App\Models\Transaction;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Storage;

class ReceiptPdfService
{
    /**
     * Generate PDF Receipt and save to local storage.
     */
    public function generateReceipt(Transaction $transaction): string
    {
        $transaction->load(['items', 'cashier', 'customer']);

        $pdf = Pdf::loadView('receipts.thermal', [
            'transaction' => $transaction,
        ])->setPaper([0, 0, 226.77, 600], 'portrait'); // ~80mm width thermal paper

        $fileName = 'receipts/' . $transaction->invoice_no . '.pdf';
        Storage::disk('local')->put($fileName, $pdf->output());

        Receipt::updateOrCreate(
            ['transaction_id' => $transaction->id],
            ['file_path' => $fileName]
        );

        return $fileName;
    }

    /**
     * Get or generate PDF output stream.
     */
    public function getReceiptPdf(Transaction $transaction)
    {
        $transaction->load(['items', 'cashier', 'customer']);

        $pdf = Pdf::loadView('receipts.thermal', [
            'transaction' => $transaction,
        ])->setPaper([0, 0, 226.77, 600], 'portrait');

        return $pdf;
    }
}

