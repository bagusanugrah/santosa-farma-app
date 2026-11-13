<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\StoreSetting;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PharmacyApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    /**
     * Test Staff Login and Me
     */
    public function test_staff_login_and_me(): void
    {
        // 1. Invalid login
        $res = $this->postJson('/api/auth/staff/login', [
            'username' => 'admin',
            'password' => 'wrongpass',
        ]);
        $res->assertStatus(401);

        // 2. Valid login
        $res = $this->postJson('/api/auth/staff/login', [
            'username' => 'admin',
            'password' => 'password123',
        ]);
        $res->assertStatus(200)
            ->assertJsonPath('data.user.role', 'super_admin');

        $token = $res->json('data.token');

        // 3. Me endpoint
        $meRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->getJson('/api/auth/staff/me');
        $meRes->assertStatus(200)
            ->assertJsonPath('data.username', 'admin');
    }

    /**
     * Test Staff Change Password
     */
    public function test_staff_change_password(): void
    {
        $loginRes = $this->postJson('/api/auth/staff/login', [
            'username' => 'kasir',
            'password' => 'password123',
        ]);
        $token = $loginRes->json('data.token');

        // Wrong current password
        $failRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/auth/staff/change-password', [
                'current_password' => 'wrongpass',
                'new_password' => 'newpassword123',
                'new_password_confirmation' => 'newpassword123',
            ]);
        $failRes->assertStatus(422);

        // Success change password
        $successRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/auth/staff/change-password', [
                'current_password' => 'password123',
                'new_password' => 'newpassword123',
                'new_password_confirmation' => 'newpassword123',
            ]);
        $successRes->assertStatus(200)
            ->assertJsonPath('status', 'success');

        // Login with new password
        $newLoginRes = $this->postJson('/api/auth/staff/login', [
            'username' => 'kasir',
            'password' => 'newpassword123',
        ]);
        $newLoginRes->assertStatus(200);
    }

    /**
     * Test Store Status
     */
    public function test_store_status_open_and_close(): void
    {
        $res = $this->getJson('/api/store/status');
        $res->assertStatus(200)
            ->assertJsonPath('data.store_status', 'buka');

        // Close store
        $closeRes = $this->postJson('/api/store/close');
        $closeRes->assertStatus(200)
            ->assertJsonPath('data.store_status', 'tutup');

        // Verify status is tutup
        $statusRes = $this->getJson('/api/store/status');
        $statusRes->assertJsonPath('data.store_status', 'tutup');

        // Open store
        $openRes = $this->postJson('/api/store/open');
        $openRes->assertStatus(200)
            ->assertJsonPath('data.store_status', 'buka');
    }

    /**
     * Test Product list, alphabet sort, search, and pagination
     */
    public function test_product_catalog(): void
    {
        $res = $this->getJson('/api/products?sort=alphabet&per_page=10');
        $res->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'data' => [
                    '*' => ['id', 'name', 'price', 'stock', 'image_url', 'category'],
                ],
                'meta' => ['current_page', 'per_page', 'total', 'last_page'],
            ]);

        $data = $res->json('data');
        $this->assertNotEmpty($data);
        $this->assertLessThanOrEqual(10, count($data));

        // Test search
        $searchRes = $this->getJson('/api/products?search=Amoxicillin');
        $searchRes->assertStatus(200);
        $this->assertStringContainsString('Amoxicillin', $searchRes->json('data.0.name'));
    }

    /**
     * Test Super Admin Product CRUD
     */
    public function test_super_admin_product_crud(): void
    {
        $admin = User::where('role', 'super_admin')->first();
        $token = $admin->createToken('admin-token', ['role:super_admin'])->plainTextToken;

        // 1. Create product
        $createRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/products', [
                'name' => 'Vitamin D3 1000 IU Tablet',
                'category' => 'Vitamin',
                'price' => 55000,
                'stock' => 30,
                'description' => 'Membantu penyerapan kalsium dan menjaga daya tahan tubuh.',
            ]);
        $createRes->assertStatus(201)
            ->assertJsonPath('data.name', 'Vitamin D3 1000 IU Tablet');

        $productId = $createRes->json('data.id');

        // 2. Update product
        $updateRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->putJson("/api/products/{$productId}", [
                'price' => 50000,
                'stock' => 28,
            ]);
        $updateRes->assertStatus(200)
            ->assertJsonPath('data.price', 50000);

        // 3. Delete product
        $deleteRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->deleteJson("/api/products/{$productId}");
        $deleteRes->assertStatus(200);

        $this->assertDatabaseMissing('products', ['id' => $productId]);
    }

    /**
     * Test Cashier POS Cash Transaction
     */
    public function test_cashier_pos_cash_transaction(): void
    {
        $cashier = User::where('role', 'admin_kasir')->first();
        $token = $cashier->createToken('cashier-token', ['role:admin_kasir'])->plainTextToken;

        $product = Product::first();
        $initialStock = $product->stock;

        $res = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/transactions/pos', [
                'payment_method' => 'tunai',
                'amount_paid' => 100000,
                'items' => [
                    [
                        'product_id' => $product->id,
                        'qty' => 2,
                    ],
                ],
            ]);

        $res->assertStatus(201)
            ->assertJsonPath('data.status', 'selesai')
            ->assertJsonPath('data.channel', 'toko');

        $product->refresh();
        $this->assertEquals($initialStock - 2, $product->stock);
    }

    /**
     * Test Customer Online Checkout & Midtrans Webhook Settlement
     */
    public function test_online_checkout_and_webhook(): void
    {
        // Enable online orders first
        StoreSetting::current()->update(['online_orders_enabled' => true]);

        $customer = Customer::first();
        $token = $customer->createToken('cust-token', ['role:customer'])->plainTextToken;

        $product = Product::where('stock', '>', 5)->first();
        $initialStock = $product->stock;

        // 1. Checkout online
        \Laravel\Sanctum\Sanctum::actingAs($customer, ['role:customer']);
        $checkoutRes = $this->postJson('/api/transactions/checkout', [
            'items' => [
                [
                    'product_id' => $product->id,
                    'qty' => 1,
                ],
            ],
        ]);

        $checkoutRes->assertStatus(201)
            ->assertJsonStructure(['status', 'data' => ['transaction', 'snap_token']]);

        $invoiceNo = $checkoutRes->json('data.transaction.invoice_no');

        // 2. Simulate Midtrans Webhook settlement
        $serverKey = config('midtrans.server_key');
        $sig = hash("sha512", $invoiceNo . '200' . (string) $product->price . $serverKey);
        $webhookRes = $this->postJson('/api/webhooks/midtrans', [
            'order_id' => $invoiceNo,
            'status_code' => '200',
            'gross_amount' => (string) $product->price,
            'signature_key' => $sig,
            'transaction_status' => 'settlement',
            'payment_type' => 'qris',
        ]);

        $webhookRes->assertStatus(200);

        $trx = Transaction::where('invoice_no', $invoiceNo)->first();
        $this->assertEquals('paid', $trx->status);
        $this->assertNotNull($trx->qr_token);

        $product->refresh();
        $this->assertEquals($initialStock - 1, $product->stock);

        // 3. Cashier scans QR & confirms pickup
        $cashier = User::where('role', 'admin_kasir')->first();

        \Laravel\Sanctum\Sanctum::actingAs($cashier, ['role:admin_kasir']);
        $scanRes = $this->getJson("/api/transactions/qr/{$trx->qr_token}");
        $scanRes->assertStatus(200)
            ->assertJsonPath('data.id', $trx->id);

        $confirmRes = $this->postJson("/api/transactions/pickup/{$trx->qr_token}");
        $confirmRes->assertStatus(200)
            ->assertJsonPath('data.status', 'diambil');
    }

    /**
     * Test Analytics & Export
     */
    public function test_analytics_and_export(): void
    {
        $admin = User::where('role', 'super_admin')->first();
        $token = $admin->createToken('admin-token', ['role:super_admin'])->plainTextToken;

        // Analytics
        $analyticsRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->getJson('/api/reports/analytics');
        $analyticsRes->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'data' => [
                    'summary' => ['total_revenue', 'total_orders', 'total_products'],
                    'channel_distribution',
                    'payment_distribution',
                    'sales_trend',
                    'top_products',
                ],
            ]);

        // Products Excel Export
        $excelRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->get('/api/reports/products-excel');
        $excelRes->assertStatus(200);
        $this->assertStringContainsString('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', $excelRes->headers->get('content-type'));

        // Sales PDF Export
        $pdfRes = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->get('/api/reports/sales-pdf');
        $pdfRes->assertStatus(200);
        $this->assertStringContainsString('application/pdf', $pdfRes->headers->get('content-type'));
    }

    /**
     * Test Customer Change Password
     */
    public function test_customer_change_password(): void
    {
        $customer = Customer::create([
            'name' => 'Pelanggan Uji',
            'phone' => '081234567899',
            'phone_verified_at' => now(),
            'password' => \Illuminate\Support\Facades\Hash::make('oldpassword123'),
        ]);

        \Laravel\Sanctum\Sanctum::actingAs($customer, ['role:customer']);

        // 1. Wrong current password
        $res = $this->postJson('/api/auth/customer/change-password', [
            'current_password' => 'wrongpass',
            'new_password' => 'newpassword123',
            'new_password_confirmation' => 'newpassword123',
        ]);
        $res->assertStatus(422);

        // 2. Mismatched confirmation
        $res = $this->postJson('/api/auth/customer/change-password', [
            'current_password' => 'oldpassword123',
            'new_password' => 'newpassword123',
            'new_password_confirmation' => 'differentpassword',
        ]);
        $res->assertStatus(422);

        // 3. Success
        $res = $this->postJson('/api/auth/customer/change-password', [
            'current_password' => 'oldpassword123',
            'new_password' => 'newpassword123',
            'new_password_confirmation' => 'newpassword123',
        ]);
        $res->assertStatus(200);

        $customer->refresh();
        $this->assertTrue(\Illuminate\Support\Facades\Hash::check('newpassword123', $customer->password));
    }

    /**
     * Test cashier can delete pending transaction
     */
    public function test_cashier_can_delete_pending_transaction(): void
    {
        $cashier = User::where('role', 'admin_kasir')->first();
        \Laravel\Sanctum\Sanctum::actingAs($cashier, ['role:admin_kasir']);

        $trx = Transaction::create([
            'invoice_no' => 'INV-TEST-DELETE-PENDING',
            'channel' => 'toko',
            'cashier_id' => $cashier->id,
            'payment_method' => 'qris',
            'status' => 'pending',
            'total' => 50000,
        ]);

        $trx->items()->create([
            'product_id' => Product::first()->id,
            'product_name' => 'Obat Test',
            'qty' => 1,
            'price' => 50000,
            'subtotal' => 50000,
        ]);

        $res = $this->deleteJson("/api/transactions/{$trx->id}");
        $res->assertStatus(200)
            ->assertJsonPath('status', 'success');

        $this->assertNull(Transaction::find($trx->id));

        // Cannot delete completed transaction
        $completedTrx = Transaction::create([
            'invoice_no' => 'INV-TEST-DELETE-COMPLETED',
            'channel' => 'toko',
            'cashier_id' => $cashier->id,
            'payment_method' => 'tunai',
            'status' => 'selesai',
            'total' => 10000,
        ]);

        $res2 = $this->deleteJson("/api/transactions/{$completedTrx->id}");
        $res2->assertStatus(400);
    }

    /**
     * Test cashier can toggle online orders trigger and customer actions are guarded
     */
    public function test_cashier_can_toggle_online_orders_and_guard_customer(): void
    {
        $cashier = User::where('role', 'admin_kasir')->first();
        \Laravel\Sanctum\Sanctum::actingAs($cashier, ['role:admin_kasir']);

        // 1. Initial status: online_orders_enabled should be false
        StoreSetting::current()->update(['online_orders_enabled' => false]);
        $statusRes = $this->getJson('/api/store/status');
        $statusRes->assertStatus(200)
            ->assertJsonPath('data.online_orders_enabled', false);

        // 2. Customer cannot register when disabled
        $regRes = $this->postJson('/api/auth/customer/register', [
            'name' => 'Pelanggan Uji',
            'type' => 'email',
            'email' => 'pelanggan_test@example.com',
            'password' => 'password123',
        ]);
        $regRes->assertStatus(403)
            ->assertJsonPath('status', 'error');

        // 3. Customer cannot login when disabled
        $loginRes = $this->postJson('/api/auth/customer/login', [
            'login' => 'pelanggan_test@example.com',
            'password' => 'password123',
        ]);
        $loginRes->assertStatus(403);

        // 4. Products can STILL be viewed by anyone even when online orders is disabled!
        $catalogRes = $this->getJson('/api/products');
        $catalogRes->assertStatus(200);

        // 5. Cashier turns online orders ON
        $toggleOn = $this->postJson('/api/store/online-orders', ['enabled' => true]);
        $toggleOn->assertStatus(200)
            ->assertJsonPath('data.online_orders_enabled', true);

        // 6. Now customer can register
        $regRes2 = $this->postJson('/api/auth/customer/register', [
            'name' => 'Pelanggan Uji',
            'type' => 'email',
            'email' => 'pelanggan_test@example.com',
            'password' => 'password123',
        ]);
        $regRes2->assertStatus(201);

        // 7. Cashier turns online orders back OFF
        $toggleOff = $this->postJson('/api/store/online-orders', ['enabled' => false]);
        $toggleOff->assertStatus(200)
            ->assertJsonPath('data.online_orders_enabled', false);
    }

    /**
     * Test database backup export and import validation
     */
    public function test_database_backup_export_and_import(): void
    {
        $superAdmin = User::where('role', 'super_admin')->first();
        $cashier = User::where('role', 'admin_kasir')->first();

        // 1. Cashier cannot access export or import (403 Forbidden)
        \Laravel\Sanctum\Sanctum::actingAs($cashier, ['role:admin_kasir']);
        $cashierExport = $this->getJson('/api/backup/export');
        $cashierExport->assertStatus(403);

        $cashierImport = $this->postJson('/api/backup/import');
        $cashierImport->assertStatus(403);

        // 2. Super admin exports database
        \Laravel\Sanctum\Sanctum::actingAs($superAdmin, ['role:super_admin']);
        $exportRes = $this->getJson('/api/backup/export');
        $exportRes->assertStatus(200)
            ->assertJsonPath('app', 'apotek-santosa-farma')
            ->assertJsonPath('version', '1.0');

        $backupData = $exportRes->json();
        $this->assertArrayHasKey('tables', $backupData);
        $this->assertArrayHasKey('checksum', $backupData);
        $this->assertNotEmpty($backupData['tables']['users']);
        $this->assertNotEmpty($backupData['tables']['products']);

        // 3. Import without file fails (422)
        $noFileRes = $this->postJson('/api/backup/import');
        $noFileRes->assertStatus(422)
            ->assertJsonPath('status', 'error');

        // 4. Import random file (not JSON or wrong format) fails (422)
        $randomFile = \Illuminate\Http\UploadedFile::fake()->create('random.txt', 10, 'text/plain');
        $randomRes = $this->postJson('/api/backup/import', ['backup_file' => $randomFile]);
        $randomRes->assertStatus(422)
            ->assertJsonPath('status', 'error');

        // 5. Import fake JSON without app signature fails (422)
        $fakeJson = \Illuminate\Http\UploadedFile::fake()->createWithContent(
            'fake.json',
            json_encode(['random_key' => 'random_value'])
        );
        $fakeRes = $this->postJson('/api/backup/import', ['backup_file' => $fakeJson]);
        $fakeRes->assertStatus(422)
            ->assertJsonPath('status', 'error');

        // 6. Import tampered JSON (invalid checksum) fails (422)
        $tamperedData = $backupData;
        $tamperedData['checksum'] = 'invalid_checksum_value_12345';
        $tamperedFile = \Illuminate\Http\UploadedFile::fake()->createWithContent(
            'tampered.json',
            json_encode($tamperedData)
        );
        $tamperedRes = $this->postJson('/api/backup/import', ['backup_file' => $tamperedFile]);
        $tamperedRes->assertStatus(422)
            ->assertJsonPath('status', 'error');

        // 7. Import valid backup succeeds (200)
        $validFile = \Illuminate\Http\UploadedFile::fake()->createWithContent(
            'valid-backup.json',
            json_encode($backupData)
        );
        $validRes = $this->postJson('/api/backup/import', ['backup_file' => $validFile]);
        $validRes->assertStatus(200)
            ->assertJsonPath('status', 'success');

        // Verify users and products still exist and can be queried
        $this->assertDatabaseHas('users', ['username' => 'admin']);
        $this->assertDatabaseHas('users', ['username' => 'kasir']);
    }
}
