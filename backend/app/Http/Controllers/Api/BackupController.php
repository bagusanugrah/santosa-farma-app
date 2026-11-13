<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class BackupController extends Controller
{
    /**
     * List of tables to include in full database backup.
     */
    protected array $backupTables = [
        'users',
        'customers',
        'products',
        'store_settings',
        'transactions',
        'transaction_items',
        'receipts',
        'otp_codes',
        'password_resets',
        'personal_access_tokens',
    ];

    /**
     * Export the complete database as a structured JSON file.
     */
    public function export(Request $request): JsonResponse
    {
        $tablesData = [];
        $counts = [];

        foreach ($this->backupTables as $tableName) {
            if (Schema::hasTable($tableName)) {
                $rows = DB::table($tableName)->get()->map(function ($item) {
                    return (array) $item;
                })->toArray();
                $tablesData[$tableName] = $rows;
                $counts[$tableName] = count($rows);
            }
        }

        $checksum = hash('sha256', json_encode($tablesData));

        $payload = [
            'app' => 'apotek-santosa-farma',
            'version' => '1.0',
            'backup_type' => 'full_database',
            'exported_at' => now()->toIso8601String(),
            'exported_by' => $request->user() ? ($request->user()->name . ' (@' . $request->user()->username . ')') : 'super_admin',
            'database_driver' => DB::getDriverName(),
            'metadata' => [
                'record_counts' => $counts,
                'total_tables' => count($tablesData),
            ],
            'tables' => $tablesData,
            'checksum' => $checksum,
        ];

        $filename = 'backup-apotek-santosa-farma-' . date('Y-m-d_His') . '.json';

        return response()->json($payload, 200, [
            'Content-Type' => 'application/json',
            'Content-Disposition' => 'attachment; filename="' . $filename . '"',
        ]);
    }

    /**
     * Import and restore the complete database from a verified JSON backup file.
     */
    public function import(Request $request): JsonResponse
    {
        if (!$request->hasFile('backup_file')) {
            return response()->json([
                'status' => 'error',
                'message' => 'File backup (.json) wajib diunggah.',
            ], 422);
        }

        $file = $request->file('backup_file');
        if (!$file->isValid()) {
            return response()->json([
                'status' => 'error',
                'message' => 'File yang diunggah tidak valid atau rusak.',
            ], 422);
        }

        // Validate extension
        $ext = strtolower($file->getClientOriginalExtension());
        if ($ext !== 'json') {
            return response()->json([
                'status' => 'error',
                'message' => 'Format file tidak didukung. File backup harus berformat .json resmi.',
            ], 422);
        }

        $contentRaw = file_get_contents($file->getRealPath());
        $data = json_decode($contentRaw, true);

        if (!is_array($data) || json_last_error() !== JSON_ERROR_NONE) {
            return response()->json([
                'status' => 'error',
                'message' => 'Format file tidak valid: Konten file bukan format JSON yang valid.',
            ], 422);
        }

        // 1. Signature check
        if (!isset($data['app']) || $data['app'] !== 'apotek-santosa-farma') {
            return response()->json([
                'status' => 'error',
                'message' => 'Format file tidak valid: File ini bukan file cadangan resmi Apotek Santosa Farma.',
            ], 422);
        }

        // 2. Tables structure check
        if (!isset($data['tables']) || !is_array($data['tables'])) {
            return response()->json([
                'status' => 'error',
                'message' => 'Format file tidak valid: Struktur data tabel tidak ditemukan di dalam file backup.',
            ], 422);
        }

        $requiredTables = ['users', 'products', 'transactions', 'transaction_items', 'store_settings'];
        foreach ($requiredTables as $reqTable) {
            if (!array_key_exists($reqTable, $data['tables']) || !is_array($data['tables'][$reqTable])) {
                return response()->json([
                    'status' => 'error',
                    'message' => "Format file tidak valid: Tabel wajib '{$reqTable}' tidak ditemukan di dalam file backup.",
                ], 422);
            }
        }

        // 3. Checksum verification
        if (!isset($data['checksum']) || !is_string($data['checksum'])) {
            return response()->json([
                'status' => 'error',
                'message' => 'File tidak valid: Kode checksum verifikasi tidak ditemukan.',
            ], 422);
        }

        $computedChecksum = hash('sha256', json_encode($data['tables']));
        if (!hash_equals($computedChecksum, $data['checksum'])) {
            return response()->json([
                'status' => 'error',
                'message' => 'File korup atau telah dimodifikasi: Checksum data tidak sesuai. Pemulihan database dibatalkan demi keamanan.',
            ], 422);
        }

        // 4. Sanity check: must contain at least one super_admin user
        $hasSuperAdmin = false;
        foreach ($data['tables']['users'] as $u) {
            if (isset($u['role']) && $u['role'] === 'super_admin') {
                $hasSuperAdmin = true;
                break;
            }
        }
        if (!$hasSuperAdmin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Data tidak valid: File backup harus memiliki setidaknya 1 akun Super Admin agar sistem dapat diakses.',
            ], 422);
        }

        $driver = DB::getDriverName();

        // Safety backup for SQLite file if applicable
        $sqliteDbPath = config('database.connections.sqlite.database');
        $sqliteBackupCreated = false;
        if ($driver === 'sqlite' && file_exists($sqliteDbPath)) {
            @copy($sqliteDbPath, $sqliteDbPath . '.pre_restore.bak');
            $sqliteBackupCreated = true;
        }

        try {
            if ($driver === 'sqlite') {
                DB::statement('PRAGMA foreign_keys = OFF;');
            } elseif ($driver === 'mysql') {
                DB::statement('SET FOREIGN_KEY_CHECKS=0;');
            }

            $restoredCounts = [];

            DB::transaction(function () use ($data, &$restoredCounts) {
                // Delete existing records in child-to-parent order
                $deleteOrder = [
                    'receipts',
                    'transaction_items',
                    'transactions',
                    'personal_access_tokens',
                    'otp_codes',
                    'password_resets',
                    'customers',
                    'products',
                    'store_settings',
                    'users',
                ];

                foreach ($deleteOrder as $table) {
                    if (Schema::hasTable($table)) {
                        DB::table($table)->delete();
                    }
                }

                // Insert records in parent-to-child order
                $insertOrder = [
                    'users',
                    'customers',
                    'products',
                    'store_settings',
                    'transactions',
                    'transaction_items',
                    'receipts',
                    'otp_codes',
                    'password_resets',
                    'personal_access_tokens',
                ];

                foreach ($insertOrder as $table) {
                    if (isset($data['tables'][$table]) && Schema::hasTable($table)) {
                        $rows = $data['tables'][$table];
                        if (!empty($rows)) {
                            foreach (array_chunk($rows, 100) as $chunk) {
                                DB::table($table)->insert($chunk);
                            }
                        }
                        $restoredCounts[$table] = count($rows);
                    }
                }
            });

            if ($driver === 'sqlite') {
                DB::statement('PRAGMA foreign_keys = ON;');
            } elseif ($driver === 'mysql') {
                DB::statement('SET FOREIGN_KEY_CHECKS=1;');
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Database berhasil dipulihkan secara penuh dari file backup.',
                'data' => [
                    'restored_at' => now()->toIso8601String(),
                    'counts' => $restoredCounts,
                ],
            ]);
        } catch (\Throwable $e) {
            if ($driver === 'sqlite') {
                DB::statement('PRAGMA foreign_keys = ON;');
            } elseif ($driver === 'mysql') {
                DB::statement('SET FOREIGN_KEY_CHECKS=1;');
            }

            // If sqlite backup existed, attempt to revert on fatal failure
            if ($sqliteBackupCreated && file_exists($sqliteDbPath . '.pre_restore.bak')) {
                @copy($sqliteDbPath . '.pre_restore.bak', $sqliteDbPath);
            }

            Log::error('[Database Import Error] ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Gagal memulihkan database: ' . $e->getMessage(),
            ], 500);
        }
    }
}
