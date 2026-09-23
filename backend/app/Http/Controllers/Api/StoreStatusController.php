<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StoreSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreStatusController extends Controller
{
    /**
     * Get Store Status (buka / tutup).
     */
    public function status(): JsonResponse
    {
        $setting = StoreSetting::current();

        return response()->json([
            'status' => 'success',
            'data' => [
                'is_open' => (bool) $setting->is_open,
                'store_status' => $setting->is_open ? 'buka' : 'tutup',
                'last_opened_at' => $setting->last_opened_at,
                'last_closed_at' => $setting->last_closed_at,
            ],
        ]);
    }

    /**
     * Set Store Status to Open (Triggered when Desktop App starts).
     */
    public function open(): JsonResponse
    {
        $setting = StoreSetting::current();
        $setting->update([
            'is_open' => true,
            'last_opened_at' => now(),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Status apotek berhasil diubah menjadi BUKA.',
            'data' => [
                'is_open' => true,
                'store_status' => 'buka',
            ],
        ]);
    }

    /**
     * Set Store Status to Closed (Triggered when Desktop App closes).
     */
    public function close(): JsonResponse
    {
        $setting = StoreSetting::current();
        $setting->update([
            'is_open' => false,
            'last_closed_at' => now(),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Status apotek berhasil diubah menjadi TUTUP.',
            'data' => [
                'is_open' => false,
                'store_status' => 'tutup',
            ],
        ]);
    }
}

