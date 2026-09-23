<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Laporan Rekap Penjualan</title>
    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            font-size: 10pt;
            color: #333;
            line-height: 1.4;
            padding: 10px;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #2b6cb0;
            padding-bottom: 10px;
            margin-bottom: 15px;
        }
        .header h1 {
            margin: 0;
            font-size: 16pt;
            color: #2b6cb0;
        }
        .header p {
            margin: 3px 0;
            font-size: 9pt;
            color: #555;
        }
        .report-title {
            text-align: center;
            font-size: 12pt;
            font-weight: bold;
            margin-bottom: 15px;
        }
        .summary-box {
            width: 100%;
            margin-bottom: 20px;
        }
        .summary-box table {
            width: 100%;
            border-collapse: collapse;
        }
        .summary-box td {
            padding: 8px;
            background: #f7fafc;
            border: 1px solid #e2e8f0;
        }
        .summary-title {
            font-size: 8.5pt;
            color: #718096;
            text-transform: uppercase;
        }
        .summary-value {
            font-size: 13pt;
            font-weight: bold;
            color: #2d3748;
        }
        .table-data {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        .table-data th, .table-data td {
            border: 1px solid #cbd5e0;
            padding: 6px 8px;
            font-size: 8.5pt;
        }
        .table-data th {
            background-color: #2b6cb0;
            color: white;
            text-align: left;
        }
        .text-right { text-align: right; }
        .text-center { text-align: center; }
        .footer {
            margin-top: 30px;
            font-size: 8pt;
            color: #718096;
            text-align: right;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>APOTEK SANTOSA FARMA</h1>
        <p>Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat | Telp: (0260) 123456</p>
    </div>

    <div class="report-title">
        LAPORAN REKAP PENJUALAN<br>
        <span style="font-size: 9.5pt; font-weight: normal; color: #4a5568;">
            Periode: {{ $startDate }} s/d {{ $endDate }}
        </span>
    </div>

    <div class="summary-box">
        <table>
            <tr>
                <td style="width: 25%;">
                    <div class="summary-title">Total Pendapatan</div>
                    <div class="summary-value">Rp {{ number_format($totalRevenue, 0, ',', '.') }}</div>
                </td>
                <td style="width: 25%;">
                    <div class="summary-title">Total Transaksi</div>
                    <div class="summary-value">{{ number_format($totalTransactions) }}</div>
                </td>
                <td style="width: 25%;">
                    <div class="summary-title">Transaksi Toko</div>
                    <div class="summary-value">{{ number_format($tokoTransactions) }}</div>
                </td>
                <td style="width: 25%;">
                    <div class="summary-title">Transaksi Online</div>
                    <div class="summary-value">{{ number_format($onlineTransactions) }}</div>
                </td>
            </tr>
        </table>
    </div>

    <table class="table-data">
        <thead>
            <tr>
                <th style="width: 4%;" class="text-center">No</th>
                <th style="width: 14%;">Tanggal</th>
                <th style="width: 16%;">No Invoice</th>
                <th style="width: 10%;">Channel</th>
                <th style="width: 10%;">Metode</th>
                <th style="width: 18%;">Kasir / Pelanggan</th>
                <th style="width: 12%;">Status</th>
                <th style="width: 16%;" class="text-right">Total</th>
            </tr>
        </thead>
        <tbody>
            @forelse($transactions as $index => $trx)
            <tr>
                <td class="text-center">{{ $index + 1 }}</td>
                <td>{{ $trx->created_at->format('d/m/Y H:i') }}</td>
                <td><strong>{{ $trx->invoice_no }}</strong></td>
                <td>{{ ucfirst($trx->channel) }}</td>
                <td>{{ strtoupper($trx->payment_method) }}</td>
                <td>
                    @if($trx->channel === 'toko')
                        Kasir: {{ $trx->cashier?->name ?? '-' }}
                    @else
                        {{ $trx->customer?->name ?? 'Online Customer' }}
                    @endif
                </td>
                <td>{{ ucfirst($trx->status) }}</td>
                <td class="text-right">Rp {{ number_format($trx->total, 0, ',', '.') }}</td>
            </tr>
            @empty
            <tr>
                <td colspan="8" class="text-center" style="padding: 15px; color: #a0aec0;">Tidak ada data transaksi pada periode ini.</td>
            </tr>
            @endforelse
        </tbody>
        <tfoot>
            <tr style="font-weight: bold; background-color: #edf2f7;">
                <td colspan="7" class="text-right">GRAND TOTAL:</td>
                <td class="text-right">Rp {{ number_format($totalRevenue, 0, ',', '.') }}</td>
            </tr>
        </tfoot>
    </table>

    <div class="footer">
        Dicetak pada: {{ now()->format('d F Y, H:i:s') }} WIB
    </div>
</body>
</html>

