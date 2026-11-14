import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String _search = '';
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _products = await SupabaseService.instance.getProducts(search: _search);
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Obat?'),
        content: Text('Apakah Anda yakin ingin menghapus "${product.name}" dari katalog? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.instance.deleteProduct(product.id);
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Obat ${product.name} telah dihapus.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF047857),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Obat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (res == true) _loadProducts();
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari obat...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF059669)),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _search = '');
                          _loadProducts();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                _search = val;
                _loadProducts();
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                : _products.isEmpty
                    ? const Center(
                        child: Text('Tidak ada data obat', style: TextStyle(color: Color(0xFF64748B))),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: const Color(0xFF059669),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final isOutOfStock = product.stock <= 0;

                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: product.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: product.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Icon(Icons.medication, color: Colors.grey),
                                        )
                                      : const Icon(Icons.medication, color: Colors.grey),
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (product.category != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              product.category!,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isOutOfStock ? 'Stok Habis' : 'Stok: ${product.stock}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isOutOfStock ? Colors.red : (product.stock < 10 ? Colors.amber[800] : const Color(0xFF16A34A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currency.format(product.price),
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 13),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF059669), size: 20),
                                      onPressed: () async {
                                        final res = await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
                                        );
                                        if (res == true) _loadProducts();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _confirmDelete(product),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
