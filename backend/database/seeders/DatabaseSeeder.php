<?php

namespace Database\Seeders;

use App\Models\Customer;
use App\Models\Product;
use App\Models\StoreSetting;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Staff Users
        User::updateOrCreate(
            ['username' => 'admin'],
            [
                'name' => 'Super Admin Santosa',
                'password' => Hash::make('password123'),
                'role' => 'super_admin',
            ]
        );

        $cashier = User::updateOrCreate(
            ['username' => 'kasir'],
            [
                'name' => 'Budi Santosa (Kasir)',
                'password' => Hash::make('password123'),
                'role' => 'admin_kasir',
            ]
        );

        // 2. Customer
        $customer = Customer::updateOrCreate(
            ['email' => 'siti@example.com'],
            [
                'name' => 'Siti Rahmah',
                'phone' => '081234567890',
                'phone_verified_at' => now(),
                'email_verified_at' => now(),
                'password' => Hash::make('password123'),
            ]
        );

        // 3. Store Setting
        StoreSetting::updateOrCreate(
            ['id' => 1],
            [
                'is_open' => true,
                'last_opened_at' => now(),
            ]
        );

        // 4. Products
        $productsData = [
            [
                'name' => 'Amoxicillin 500mg Strip (10 Kaplet)',
                'category' => 'Antibiotik',
                'price' => 12000,
                'stock' => 50,
                'description' => 'Antibiotik untuk mengobati berbagai infeksi bakteri pada saluran pernapasan, telinga, hidung, dan tenggorokan.',
            ],
            [
                'name' => 'Antasida Doen Tablet Kunyah',
                'category' => 'Pencernaan',
                'price' => 6000,
                'stock' => 80,
                'description' => 'Mengurangi gejala yang berhubungan dengan kelebihan asam lambung, gastritis, tukak lambung, dan tukak usus dua belas jari.',
            ],
            [
                'name' => 'Betadine Antiseptic Solution 30ml',
                'category' => 'P3K',
                'price' => 32000,
                'stock' => 35,
                'description' => 'Antiseptik untuk membersihkan dan mencegah infeksi pada luka khitan, lecet, luka bakar ringan, dan luka potong.',
            ],
            [
                'name' => 'Bodrex Sakit Kepala Strip (20 Tablet)',
                'category' => 'Analgesik',
                'price' => 11000,
                'stock' => 100,
                'description' => 'Meredakan sakit kepala, sakit gigi, dan menurunkan demam dengan cepat.',
            ],
            [
                'name' => 'CDR Vitamin C Effervescent Rasa Jeruk (10 Tablet)',
                'category' => 'Vitamin',
                'price' => 48000,
                'stock' => 40,
                'description' => 'Suplemen kalsium, vitamin C, D, dan B6 untuk menjaga kesehatan tulang dan daya tahan tubuh.',
            ],
            [
                'name' => 'Combantrin Jeruk 125mg Suspensi 10ml',
                'category' => 'Obat Cacing',
                'price' => 21000,
                'stock' => 25,
                'description' => 'Obat cacing untuk melumpuhkan dan membasmi cacing kremi, cacing gelang, dan cacing tambang.',
            ],
            [
                'name' => 'Decolgen Strip (4 Tablet)',
                'category' => 'Flu & Batuk',
                'price' => 4500,
                'stock' => 75,
                'description' => 'Meringankan gejala flu seperti demam, sakit kepala, hidung tersumbat, dan bersin-bersin.',
            ],
            [
                'name' => 'Diapet Kapsul (Box 25 Strip)',
                'category' => 'Pencernaan',
                'price' => 7000,
                'stock' => 90,
                'description' => 'Membantu mengurangi frekuensi buang air besar dan memadatkan feses pada diare bukan karena bakteri spesifik.',
            ],
            [
                'name' => 'Enervon-C Multivitamin Strip (4 Tablet)',
                'category' => 'Vitamin',
                'price' => 8500,
                'stock' => 120,
                'description' => 'Kombinasi vitamin C dan B kompleks untuk membantu memelihara daya tahan tubuh.',
            ],
            [
                'name' => 'Hansaplast Plester Luka Standar (10 Lembar)',
                'category' => 'P3K',
                'price' => 7500,
                'stock' => 150,
                'description' => 'Plester elastis pelindung luka dari kotoran dan bakteri.',
            ],
            [
                'name' => 'Imboost Force Tablet Strip (10 Kaplet)',
                'category' => 'Daya Tahan Tubuh',
                'price' => 85000,
                'stock' => 30,
                'description' => 'Suplemen imunomodulator dengan Echinacea purpurea dan Black elderberry untuk daya tahan tubuh maksimal.',
            ],
            [
                'name' => 'Minyak Kayu Putih Cap Lang 60ml',
                'category' => 'Minyak Angin',
                'price' => 24000,
                'stock' => 60,
                'description' => 'Membantu meredakan perut kembung, mual, masuk angin, gatal-gatal gigitan serangga, dan menghangatkan tubuh.',
            ],
            [
                'name' => 'Mylanta Sirup Cair 150ml',
                'category' => 'Pencernaan',
                'price' => 45000,
                'stock' => 45,
                'description' => 'Obat maag cair cepat meredakan perih di ulu hati dan kembung.',
            ],
            [
                'name' => 'Neozep Forte Strip (4 Tablet)',
                'category' => 'Flu & Batuk',
                'price' => 4000,
                'stock' => 80,
                'description' => 'Meredakan gejala hidung tersumbat, bersin-bersin, dan demam akibat salesma dan flu.',
            ],
            [
                'name' => 'OBH Tropica Plus Anak Sirup 100ml',
                'category' => 'Flu & Batuk',
                'price' => 22000,
                'stock' => 40,
                'description' => 'Sirup obat batuk dan flu dengan rasa yang disukai anak.',
            ],
            [
                'name' => 'Panadol Extra Merah Strip (10 Kaplet)',
                'category' => 'Analgesik',
                'price' => 14000,
                'stock' => 110,
                'description' => 'Kombinasi Paracetamol & Caffeine untuk meredakan sakit kepala membandel dan sakit gigi.',
            ],
            [
                'name' => 'Paracetamol 500mg Strip (10 Kaplet)',
                'category' => 'Analgesik',
                'price' => 5000,
                'stock' => 200,
                'description' => 'Meredakan demam dan nyeri ringan hingga sedang.',
            ],
            [
                'name' => 'Promag Double Action Tablet Kunyah',
                'category' => 'Pencernaan',
                'price' => 18000,
                'stock' => 65,
                'description' => 'Kombinasi antasida dan penghambat asam H2 untuk meredakan sakit maag dengan cepat dan tahan lama.',
            ],
            [
                'name' => 'Rohto Cool Tetes Mata 10ml',
                'category' => 'Mata',
                'price' => 19500,
                'stock' => 40,
                'description' => 'Meredakan mata merah akibat iritasi ringan dengan sensasi dingin menyegarkan.',
            ],
            [
                'name' => 'Sangobion Kapsul Strip (10 Kapsul)',
                'category' => 'Vitamin',
                'price' => 22500,
                'stock' => 55,
                'description' => 'Suplemen zat besi dan vitamin untuk mencegah dan mengatasi anemia karena defisiensi zat besi.',
            ],
            [
                'name' => 'Tolak Angin Cair Herbal (Box 12 Sachet)',
                'category' => 'Herbal',
                'price' => 42000,
                'stock' => 70,
                'description' => 'Obat herbal terstandar untuk mengatasi masuk angin, mual, kembung, dan badan meriang.',
            ],
            [
                'name' => 'Woods Peppermint Antitussive Sirup 100ml',
                'category' => 'Flu & Batuk',
                'price' => 31000,
                'stock' => 35,
                'description' => 'Sirup pereda batuk kering tidak berdahak yang disertai alergi.',
            ],
        ];

        $createdProducts = [];
        foreach ($productsData as $pData) {
            $createdProducts[] = Product::updateOrCreate(
                ['name' => $pData['name']],
                $pData
            );
        }

        // 5. Initial Sample Transactions (for sales analytics & POS demo)
        $t1 = Transaction::updateOrCreate(
            ['invoice_no' => 'INV-POS-20260825-001'],
            [
                'channel' => 'toko',
                'cashier_id' => $cashier->id,
                'payment_method' => 'tunai',
                'status' => 'selesai',
                'total' => 29000,
                'amount_paid' => 50000,
                'change_amount' => 21000,
                'paid_at' => now()->subDay(),
                'created_at' => now()->subDay(),
            ]
        );
        $t1->items()->createMany([
            [
                'product_id' => $createdProducts[0]->id,
                'product_name' => $createdProducts[0]->name,
                'qty' => 1,
                'price' => 12000,
                'subtotal' => 12000,
            ],
            [
                'product_id' => $createdProducts[3]->id,
                'product_name' => $createdProducts[3]->name,
                'qty' => 1,
                'price' => 11000,
                'subtotal' => 11000,
            ],
            [
                'product_id' => $createdProducts[1]->id,
                'product_name' => $createdProducts[1]->name,
                'qty' => 1,
                'price' => 6000,
                'subtotal' => 6000,
            ],
        ]);

        $t2 = Transaction::updateOrCreate(
            ['invoice_no' => 'INV-ONL-20260825-002'],
            [
                'channel' => 'online',
                'customer_id' => $customer->id,
                'payment_method' => 'qris',
                'status' => 'paid',
                'total' => 97000,
                'midtrans_order_id' => 'INV-ONL-20260825-002',
                'qr_token' => 'PKP-' . Str::random(24),
                'paid_at' => now()->subHours(5),
                'created_at' => now()->subHours(6),
            ]
        );
        $t2->items()->createMany([
            [
                'product_id' => $createdProducts[4]->id,
                'product_name' => $createdProducts[4]->name,
                'qty' => 1,
                'price' => 48000,
                'subtotal' => 48000,
            ],
            [
                'product_id' => $createdProducts[10]->id,
                'product_name' => $createdProducts[10]->name,
                'qty' => 1,
                'price' => 85000,
                'subtotal' => 85000,
            ],
        ]);
    }
}
