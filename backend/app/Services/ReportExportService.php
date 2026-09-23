<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Transaction;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class ReportExportService
{
    /**
     * Generate Sales PDF report.
     */
    public function generateSalesPdf(string $startDate, string $endDate)
    {
        $start = Carbon::parse($startDate)->startOfDay();
        $end = Carbon::parse($endDate)->endOfDay();

        $transactions = Transaction::with(['customer', 'cashier'])
            ->whereBetween('created_at', [$start, $end])
            ->whereIn('status', ['paid', 'diambil', 'selesai'])
            ->orderBy('created_at', 'desc')
            ->get();

        $totalRevenue = $transactions->sum('total');
        $totalTransactions = $transactions->count();
        $tokoTransactions = $transactions->where('channel', 'toko')->count();
        $onlineTransactions = $transactions->where('channel', 'online')->count();

        $pdf = Pdf::loadView('reports.sales', [
            'startDate' => $start->format('d/m/Y'),
            'endDate' => $end->format('d/m/Y'),
            'transactions' => $transactions,
            'totalRevenue' => $totalRevenue,
            'totalTransactions' => $totalTransactions,
            'tokoTransactions' => $tokoTransactions,
            'onlineTransactions' => $onlineTransactions,
        ])->setPaper('a4', 'portrait');

        return $pdf;
    }

    /**
     * Export Products to Excel (.xlsx).
     */
    public function exportProductsExcel(): string
    {
        $products = Product::orderBy('name', 'asc')->get();

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Daftar Produk');

        // Header Title
        $sheet->mergeCells('A1:F1');
        $sheet->setCellValue('A1', 'APOTEK SANTOSA FARMA - DAFTAR PRODUK OBAT');
        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(14);
        $sheet->getStyle('A1')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        $sheet->mergeCells('A2:F2');
        $sheet->setCellValue('A2', 'Diekspor pada: ' . now()->format('d/m/Y H:i:s'));
        $sheet->getStyle('A2')->getFont()->setItalic(true)->setSize(10);
        $sheet->getStyle('A2')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        // Table Headers
        $headers = ['No', 'Nama Produk', 'Kategori', 'Harga (Rp)', 'Stok', 'Deskripsi'];
        $col = 'A';
        foreach ($headers as $header) {
            $sheet->setCellValue($col . '4', $header);
            $col++;
        }

        // Header Styling
        $headerStyle = [
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => [
                'fillType' => Fill::FILL_SOLID,
                'startColor' => ['rgb' => '2B6CB0'],
            ],
            'alignment' => [
                'horizontal' => Alignment::HORIZONTAL_CENTER,
                'vertical' => Alignment::VERTICAL_CENTER,
            ],
        ];
        $sheet->getStyle('A4:F4')->applyFromArray($headerStyle);
        $sheet->getRowDimension(4)->setRowHeight(25);

        // Data Rows
        $row = 5;
        foreach ($products as $index => $product) {
            $sheet->setCellValue('A' . $row, $index + 1);
            $sheet->setCellValue('B' . $row, $product->name);
            $sheet->setCellValue('C' . $row, $product->category ?? '-');
            $sheet->setCellValue('D' . $row, $product->price);
            $sheet->setCellValue('E' . $row, $product->stock);
            $sheet->setCellValue('F' . $row, $product->description ?? '-');

            $sheet->getStyle('A' . $row)->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);
            $sheet->getStyle('D' . $row)->getNumberFormat()->setFormatCode('#,##0');
            $sheet->getStyle('E' . $row)->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

            $row++;
        }

        // Auto-fit columns
        foreach (range('A', 'F') as $columnID) {
            $sheet->getColumnDimension($columnID)->setAutoSize(true);
        }

        $writer = new Xlsx($spreadsheet);
        $tempPath = storage_path('app/temp_products_' . time() . '.xlsx');
        $writer->save($tempPath);

        return $tempPath;
    }

    /**
     * Get Analytics Data for Super Admin Dashboard.
     */
    public function getAnalyticsData(string $period = 'monthly'): array
    {
        // 1. Overview metrics
        $paidStatuses = ['paid', 'diambil', 'selesai'];
        $totalSales = (float) Transaction::whereIn('status', $paidStatuses)->sum('total');
        $totalOrders = Transaction::whereIn('status', $paidStatuses)->count();
        $totalProducts = Product::count();
        $lowStockProducts = Product::where('stock', '<=', 10)->count();

        // 2. Channel Distribution (Pie chart)
        $channelStats = Transaction::whereIn('status', $paidStatuses)
            ->select('channel', DB::raw('count(*) as count'), DB::raw('sum(total) as revenue'))
            ->groupBy('channel')
            ->get()
            ->map(function ($item) {
                return [
                    'name' => ucfirst($item->channel),
                    'channel' => $item->channel,
                    'count' => (int) $item->count,
                    'value' => (float) $item->revenue,
                ];
            });

        // 3. Payment Method Distribution (Pie chart)
        $paymentStats = Transaction::whereIn('status', $paidStatuses)
            ->select('payment_method', DB::raw('count(*) as count'), DB::raw('sum(total) as revenue'))
            ->groupBy('payment_method')
            ->get()
            ->map(function ($item) {
                return [
                    'name' => strtoupper($item->payment_method),
                    'method' => $item->payment_method,
                    'count' => (int) $item->count,
                    'value' => (float) $item->revenue,
                ];
            });

        // 4. Sales Trend (Bar chart - past 7 days or past 30 days)
        $days = 7;
        $trendData = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $startOfDay = $date->copy()->startOfDay();
            $endOfDay = $date->copy()->endOfDay();

            $revenue = (float) Transaction::whereIn('status', $paidStatuses)
                ->whereBetween('created_at', [$startOfDay, $endOfDay])
                ->sum('total');

            $count = Transaction::whereIn('status', $paidStatuses)
                ->whereBetween('created_at', [$startOfDay, $endOfDay])
                ->count();

            $trendData[] = [
                'date' => $date->format('d M'),
                'full_date' => $date->format('Y-m-d'),
                'revenue' => $revenue,
                'transactions' => $count,
            ];
        }

        // 5. Top Selling Products
        $topProducts = DB::table('transaction_items')
            ->join('transactions', 'transaction_items.transaction_id', '=', 'transactions.id')
            ->whereIn('transactions.status', $paidStatuses)
            ->select(
                'transaction_items.product_id',
                'transaction_items.product_name',
                DB::raw('SUM(transaction_items.qty) as total_qty'),
                DB::raw('SUM(transaction_items.subtotal) as total_revenue')
            )
            ->groupBy('transaction_items.product_id', 'transaction_items.product_name')
            ->orderBy('total_qty', 'desc')
            ->limit(5)
            ->get()
            ->map(function ($item) {
                return [
                    'product_id' => $item->product_id,
                    'product_name' => $item->product_name,
                    'total_qty' => (int) $item->total_qty,
                    'total_revenue' => (float) $item->total_revenue,
                ];
            });

        return [
            'summary' => [
                'total_revenue' => $totalSales,
                'total_orders' => $totalOrders,
                'total_products' => $totalProducts,
                'low_stock_products' => $lowStockProducts,
            ],
            'channel_distribution' => $channelStats,
            'payment_distribution' => $paymentStats,
            'sales_trend' => $trendData,
            'top_products' => $topProducts,
        ];
    }
}

