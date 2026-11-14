import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../widgets/cart_view.dart';
import '../widgets/product_card.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final posProvider = context.watch<PosProvider>();
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final catalogContent = Column(
      children: [
        // Search & Category Filter Section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Search Input
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama obat (misal: Amoxicillin, Bodrex)...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF059669)),
                  suffixIcon: posProvider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => posProvider.setSearchQuery(''),
                        )
                      : null,
                ),
                onChanged: (val) => posProvider.setSearchQuery(val),
              ),
              const SizedBox(height: 10),

              // Horizontal Category Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: posProvider.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = posProvider.categories[index];
                    final isSelected = posProvider.selectedCategory == cat;
                    return FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF047857) : const Color(0xFF475569),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFDCFCE7),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) => posProvider.setSelectedCategory(cat),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Products Grid
        Expanded(
          child: posProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF059669)),
                )
              : posProvider.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'Tidak ada obat yang cocok',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Coba ubah kata kunci pencarian atau kategori obat',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => posProvider.loadProducts(),
                      color: const Color(0xFF059669),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 3 : 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: posProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = posProvider.products[index];
                          final inCartQty = posProvider.cart[product.id]?.qty ?? 0;
                          return ProductCard(
                            product: product,
                            inCartQty: inCartQty,
                            onAddToCart: () => posProvider.addToCart(product),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (isTablet) {
      // Tablet Dual-Pane
      return Row(
        children: [
          Expanded(flex: 6, child: catalogContent),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(
            width: 360,
            child: CartView(),
          ),
        ],
      );
    }

    // Smartphone Layout with Bottom Cart Drawer Bar
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: posProvider.totalItemsInCart > 0 ? 76 : 0),
          child: catalogContent,
        ),
        if (posProvider.totalItemsInCart > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Material(
              color: const Color(0xFF047857),
              borderRadius: BorderRadius.circular(20),
              elevation: 8,
              shadowColor: const Color(0xFF059669).withOpacity(0.4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: const CartView(isBottomSheet: true),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${posProvider.totalItemsInCart} Obat',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currency.format(posProvider.grandTotal),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                      const Text(
                        'Lihat Keranjang',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
