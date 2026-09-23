<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Struk Pembayaran - {{ $transaction->invoice_no }}</title>
    <style>
        @page {
            margin: 5px;
        }
        body {
            font-family: 'Courier New', Courier, monospace;
            font-size: 9pt;
            line-height: 1.2;
            color: #000;
            padding: 5px;
        }
        .text-center { text-align: center; }
        .text-right { text-align: right; }
        .text-left { text-align: left; }
        .bold { font-weight: bold; }
        .divider {
            border-top: 1px dashed #000;
            margin: 5px 0;
        }
        .header {
            margin-bottom: 8px;
        }
        .header h2 {
            margin: 0;
            font-size: 11pt;
            text-transform: uppercase;
        }
        .header p {
            margin: 2px 0;
            font-size: 7.5pt;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 2px 0;
        }
        .items td {
            vertical-align: top;
            font-size: 8.5pt;
        }
        .totals td {
            font-size: 8.5pt;
            padding: 1px 0;
        }
        .footer {
            margin-top: 8px;
            font-size: 7.5pt;
        }
    </style>
</head>
<body>
    <div class="header text-center">
        <h2 class="bold">APOTEK SANTOSA FARMA</h2>
        <p>Pertigaan Jl. Raya Jalancagak, Subang, Jawa Barat</p>
        <p>Telp: (0260) 123456 / WA: 0812-3456-7890</p>
    </div>

    <div class="divider"></div>

    <div>
        <table style="font-size: 8pt;">
            <tr>
                <td>No: {{ $transaction->invoice_no }}</td>
                <td class="text-right">{{ $transaction->created_at->format('d/m/Y H:i') }}</td>
            </tr>
            <tr>
                <td>Kasir: {{ $transaction->cashier ? $transaction->cashier->name : 'Online' }}</td>
                <td class="text-right">Tipe: {{ strtoupper($transaction->channel) }}</td>
            </tr>
            @if($transaction->customer)
            <tr>
                <td colspan="2">Pelanggan: {{ $transaction->customer->name }}</td>
            </tr>
            @endif
        </table>
    </div>

    <div class="divider"></div>

    <table class="items">
        <thead>
            <tr style="border-bottom: 1px solid #000;">
                <th class="text-left" style="width: 45%;">Item</th>
                <th class="text-center" style="width: 15%;">Qty</th>
                <th class="text-right" style="width: 20%;">Harga</th>
                <th class="text-right" style="width: 20%;">Total</th>
            </tr>
        </thead>
        <tbody>
            @foreach($transaction->items as $item)
            <tr>
                <td colspan="4" class="bold" style="padding-top: 3px;">{{ $item->product_name }}</td>
            </tr>
            <tr>
                <td></td>
                <td class="text-center">{{ $item->qty }}</td>
                <td class="text-right">{{ number_format($item->price, 0, ',', '.') }}</td>
                <td class="text-right">{{ number_format($item->subtotal, 0, ',', '.') }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="divider"></div>

    <table class="totals">
        <tr class="bold">
            <td class="text-left">TOTAL</td>
            <td class="text-right">Rp {{ number_format($transaction->total, 0, ',', '.') }}</td>
        </tr>
        <tr>
            <td class="text-left">Metode Bayar</td>
            <td class="text-right">{{ strtoupper($transaction->payment_method) }}</td>
        </tr>
        @if($transaction->amount_paid)
        <tr>
            <td class="text-left">Bayar (Tunai)</td>
            <td class="text-right">Rp {{ number_format($transaction->amount_paid, 0, ',', '.') }}</td>
        </tr>
        <tr>
            <td class="text-left">Kembalian</td>
            <td class="text-right">Rp {{ number_format($transaction->change_amount ?? 0, 0, ',', '.') }}</td>
        </tr>
        @endif
        <tr>
            <td class="text-left">Status</td>
            <td class="text-right bold">{{ strtoupper($transaction->status) }}</td>
        </tr>
    </table>

    <div class="divider"></div>

    <div class="footer text-center">
        <p class="bold">Terima kasih atas kunjungan Anda</p>
        <p>Semoga Lekas Sembuh</p>
        <p style="margin-top: 4px; font-size: 6.5pt;">Barang yang sudah dibeli tidak dapat ditukar/dikembalikan kecuali perjanjian.</p>
    </div>
</body>
</html>

