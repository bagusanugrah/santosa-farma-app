<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use ZipArchive;

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
     * Export the complete database and media files as a verified ZIP backup package.
     */
    public function export(Request $request): BinaryFileResponse|JsonResponse
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

        $tablesChecksum = hash('sha256', json_encode($tablesData));

        $databasePayload = [
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
            'checksum' => $tablesChecksum,
        ];

        $databaseJsonString = json_encode($databasePayload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

        // Collect all images in public storage products directory
        $productsStoragePath = storage_path('app/public/products');
        $mediaFiles = [];
        if (File::isDirectory($productsStoragePath)) {
            $files = File::files($productsStoragePath);
            foreach ($files as $file) {
                $mediaFiles[] = $file->getFilename();
            }
        }

        $manifestPayload = [
            'app' => 'apotek-santosa-farma',
            'version' => '1.0',
            'package_type' => 'full_system_backup_zip',
            'created_at' => now()->toIso8601String(),
            'created_by' => $request->user() ? ($request->user()->name . ' (@' . $request->user()->username . ')') : 'super_admin',
            'database_checksum' => hash('sha256', $databaseJsonString),
            'record_counts' => $counts,
            'total_media_files' => count($mediaFiles),
            'media_files' => $mediaFiles,
        ];

        $manifestJsonString = json_encode($manifestPayload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

        // Build temporary ZIP archive
        $tempZipPath = tempnam(sys_get_temp_dir(), 'apotek_backup_') . '.zip';
        $zip = new ZipArchive();

        if ($zip->open($tempZipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal membuat berkas arsip ZIP untuk cadangan data.',
            ], 500);
        }

        $zip->addFromString('manifest.json', $manifestJsonString);
        $zip->addFromString('database.json', $databaseJsonString);

        // Add media files
        if (File::isDirectory($productsStoragePath)) {
            foreach ($mediaFiles as $filename) {
                $fullPath = $productsStoragePath . DIRECTORY_SEPARATOR . $filename;
                if (File::exists($fullPath)) {
                    $zip->addFile($fullPath, 'media/products/' . $filename);
                }
            }
        }

        $zip->close();

        $downloadFilename = 'backup-apotek-santosa-farma-' . date('Y-m-d_His') . '.zip';

        return response()->download($tempZipPath, $downloadFilename, [
            'Content-Type' => 'application/zip',
            'Access-Control-Expose-Headers' => 'Content-Disposition',
        ])->deleteFileAfterSend(true);
    }

    /**
     * Import and restore complete database and media files from a verified ZIP or JSON backup.
     */
    public function import(Request $request): JsonResponse
    {
        if (!$request->hasFile('backup_file')) {
            return response()->json([
                'status' => 'error',
                'message' => 'Berkas cadangan (.zip atau .json) wajib diunggah.',
            ], 422);
        }

        $file = $request->file('backup_file');
        if (!$file->isValid()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Berkas yang diunggah tidak valid atau rusak.',
            ], 422);
        }

        $ext = strtolower($file->getClientOriginalExtension());
        if (!in_array($ext, ['zip', 'json'])) {
            return response()->json([
                'status' => 'error',
                'message' => 'Format berkas tidak didukung. Harap unggah berkas resmi berformat .zip atau .json.',
            ], 422);
        }

        $productsStoragePath = storage_path('app/public/products');
        File::ensureDirectoryExists($productsStoragePath);

        // Prepare restoration payload and files
        $databasePayload = null;
        $extractedImages = []; // [ ['sourcePath' => ..., 'targetFilename' => ...] ]
        $tempExtractDir = null;

        if ($ext === 'zip') {
            $zip = new ZipArchive();
            $zipOpenRes = $zip->open($file->getRealPath());

            if ($zipOpenRes !== true) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Berkas ZIP rusak atau tidak dapat dibuka.',
                ], 422);
            }

            // 1. Check for path traversal / zip slip safety
            for ($i = 0; $i < $zip->numFiles; $i++) {
                $filename = $zip->getNameIndex($i);
                if (str_contains($filename, '..') || str_starts_with($filename, '/') || str_starts_with($filename, '\\')) {
                    $zip->close();
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Berkas ZIP tidak aman: Ditemukan jalur berkas yang mencurigakan.',
                    ], 422);
                }
            }

            // 2. Locate manifest.json and database.json
            $manifestIndex = $zip->locateName('manifest.json');
            $databaseIndex = $zip->locateName('database.json');

            if ($manifestIndex === false || $databaseIndex === false) {
                $zip->close();
                return response()->json([
                    'status' => 'error',
                    'message' => 'Format berkas tidak valid: Berkas ZIP ini bukan berkas cadangan resmi Apotek Santosa Farma (manifest atau database tidak ditemukan).',
                ], 422);
            }

            $manifestRaw = $zip->getFromIndex($manifestIndex);
            $manifest = json_decode($manifestRaw, true);

            if (!is_array($manifest) || ($manifest['app'] ?? '') !== 'apotek-santosa-farma') {
                $zip->close();
                return response()->json([
                    'status' => 'error',
                    'message' => 'Format berkas tidak valid: Tanda tangan aplikasi tidak sesuai pada manifest cadangan.',
                ], 422);
            }

            $databaseRaw = $zip->getFromIndex($databaseIndex);
            $databasePayload = json_decode($databaseRaw, true);

            // 3. Verify manifest checksum
            if (isset($manifest['database_checksum'])) {
                $computedChecksum = hash('sha256', $databaseRaw);
                if (!hash_equals($manifest['database_checksum'], $computedChecksum)) {
                    $zip->close();
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Berkas cadangan korup atau telah dimodifikasi: Checksum integritas database tidak sesuai.',
                    ], 422);
                }
            }

            // 4. Extract media files into a temporary staging directory
            $tempExtractDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'apotek_extract_' . uniqid();
            File::ensureDirectoryExists($tempExtractDir);

            for ($i = 0; $i < $zip->numFiles; $i++) {
                $entryName = $zip->getNameIndex($i);
                if (str_starts_with($entryName, 'media/products/') && !str_ends_with($entryName, '/')) {
                    $targetFilename = basename($entryName);
                    $content = $zip->getFromIndex($i);
                    $tempFilePath = $tempExtractDir . DIRECTORY_SEPARATOR . $targetFilename;
                    file_put_contents($tempFilePath, $content);

                    $extractedImages[] = [
                        'sourcePath' => $tempFilePath,
                        'targetFilename' => $targetFilename,
                    ];
                }
            }

            $zip->close();
        } else {
            // Legacy JSON format support
            $contentRaw = file_get_contents($file->getRealPath());
            $databasePayload = json_decode($contentRaw, true);
        }

        // Validate database JSON structure
        if (!is_array($databasePayload) || json_last_error() !== JSON_ERROR_NONE) {
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
            return response()->json([
                'status' => 'error',
                'message' => 'Format berkas tidak valid: Konten database bukan format JSON yang valid.',
            ], 422);
        }

        if (!isset($databasePayload['app']) || $databasePayload['app'] !== 'apotek-santosa-farma') {
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
            return response()->json([
                'status' => 'error',
                'message' => 'Format berkas tidak valid: Berkas ini bukan cadangan resmi Apotek Santosa Farma.',
            ], 422);
        }

        if (!isset($databasePayload['tables']) || !is_array($databasePayload['tables'])) {
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
            return response()->json([
                'status' => 'error',
                'message' => 'Format berkas tidak valid: Struktur data tabel tidak ditemukan.',
            ], 422);
        }

        $requiredTables = ['users', 'products', 'transactions', 'transaction_items', 'store_settings'];
        foreach ($requiredTables as $reqTable) {
            if (!array_key_exists($reqTable, $databasePayload['tables']) || !is_array($databasePayload['tables'][$reqTable])) {
                if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
                return response()->json([
                    'status' => 'error',
                    'message' => "Format berkas tidak valid: Tabel wajib '{$reqTable}' tidak ditemukan di dalam berkas cadangan.",
                ], 422);
            }
        }

        // Verify checksum inside database payload
        if (isset($databasePayload['checksum'])) {
            $computedChecksum = hash('sha256', json_encode($databasePayload['tables']));
            if (!hash_equals($computedChecksum, $databasePayload['checksum'])) {
                if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
                return response()->json([
                    'status' => 'error',
                    'message' => 'Berkas korup atau telah dimodifikasi: Checksum data tabel tidak sesuai.',
                ], 422);
            }
        }

        // Ensure at least one super_admin exists
        $hasSuperAdmin = false;
        foreach ($databasePayload['tables']['users'] as $u) {
            if (isset($u['role']) && $u['role'] === 'super_admin') {
                $hasSuperAdmin = true;
                break;
            }
        }
        if (!$hasSuperAdmin) {
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
            return response()->json([
                'status' => 'error',
                'message' => 'Data tidak valid: Berkas cadangan harus memiliki setidaknya 1 akun Super Admin.',
            ], 422);
        }

        $driver = DB::getDriverName();

        // Safety backups
        $sqliteDbPath = config('database.connections.sqlite.database');
        $sqliteBackupCreated = false;
        if ($driver === 'sqlite' && file_exists($sqliteDbPath)) {
            @copy($sqliteDbPath, $sqliteDbPath . '.pre_restore.bak');
            $sqliteBackupCreated = true;
        }

        $storageBackupDir = storage_path('app/public/products_pre_restore_bak');
        if (File::isDirectory($productsStoragePath)) {
            File::deleteDirectory($storageBackupDir);
            File::copyDirectory($productsStoragePath, $storageBackupDir);
        }

        try {
            if ($driver === 'sqlite') {
                DB::statement('PRAGMA foreign_keys = OFF;');
            } elseif ($driver === 'mysql') {
                DB::statement('SET FOREIGN_KEY_CHECKS=0;');
            }

            $restoredCounts = [];

            DB::transaction(function () use ($databasePayload, &$restoredCounts) {
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
                    if (isset($databasePayload['tables'][$table]) && Schema::hasTable($table)) {
                        $rows = $databasePayload['tables'][$table];
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

            // ========================================================
            // CLEAN STORAGE & RESTORE MEDIA
            // ========================================================
            // Clean out all old/stuck files in storage/app/public/products
            File::cleanDirectory($productsStoragePath);

            // Restore media files from the ZIP archive
            $restoredMediaCount = 0;
            foreach ($extractedImages as $img) {
                $dest = $productsStoragePath . DIRECTORY_SEPARATOR . $img['targetFilename'];
                File::copy($img['sourcePath'], $dest);
                $restoredMediaCount++;
            }

            // Cleanup temporary extraction folder and safety backups
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);
            if (File::isDirectory($storageBackupDir)) File::deleteDirectory($storageBackupDir);
            if ($sqliteBackupCreated && file_exists($sqliteDbPath . '.pre_restore.bak')) {
                @unlink($sqliteDbPath . '.pre_restore.bak');
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Database dan berkas media berhasil dipulihkan secara penuh.',
                'data' => [
                    'restored_at' => now()->toIso8601String(),
                    'counts' => $restoredCounts,
                    'restored_images' => $restoredMediaCount,
                ],
            ]);
        } catch (\Throwable $e) {
            if ($driver === 'sqlite') {
                DB::statement('PRAGMA foreign_keys = ON;');
            } elseif ($driver === 'mysql') {
                DB::statement('SET FOREIGN_KEY_CHECKS=1;');
            }

            // Rollback database and storage
            if ($sqliteBackupCreated && file_exists($sqliteDbPath . '.pre_restore.bak')) {
                @copy($sqliteDbPath . '.pre_restore.bak', $sqliteDbPath);
            }
            if (File::isDirectory($storageBackupDir)) {
                File::cleanDirectory($productsStoragePath);
                File::copyDirectory($storageBackupDir, $productsStoragePath);
                File::deleteDirectory($storageBackupDir);
            }
            if ($tempExtractDir) File::deleteDirectory($tempExtractDir);

            Log::error('[Database & Media Import Error] ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Gagal memulihkan database dan berkas media: ' . $e->getMessage(),
            ], 500);
        }
    }
}
