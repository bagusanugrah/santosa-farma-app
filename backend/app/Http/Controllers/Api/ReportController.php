<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ReportExportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ReportController extends Controller
{
    protected ReportExportService $reportService;

    public function __construct(ReportExportService $reportService)
    {
        $this->reportService = $reportService;
    }

    /**
     * Download Sales PDF Report.
     */
    public function salesPdf(Request $request)
    {
        $startDate = $request->input('start_date', now()->subDays(30)->toDateString());
        $endDate = $request->input('end_date', now()->toDateString());

        $pdf = $this->reportService->generateSalesPdf($startDate, $endDate);

        return $pdf->download("laporan-penjualan-{$startDate}-sd-{$endDate}.pdf");
    }

    /**
     * Download Products Excel (.xlsx).
     */
    public function productsExcel(): BinaryFileResponse
    {
        $filePath = $this->reportService->exportProductsExcel();
        $fileName = 'daftar-produk-obat-' . date('Y-m-d') . '.xlsx';

        return response()->download($filePath, $fileName)->deleteFileAfterSend(true);
    }

    /**
     * Get Analytics Data (Super Admin Dashboard).
     */
    public function analytics(Request $request): JsonResponse
    {
        $period = $request->input('period', 'monthly');
        $data = $this->reportService->getAnalyticsData($period);

        return response()->json([
            'status' => 'success',
            'data' => $data,
        ]);
    }
}

