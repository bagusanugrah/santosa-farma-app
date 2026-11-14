import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

class CartItem {
  final Product product;
  int qty;

  CartItem({required this.product, this.qty = 1});

  double get subtotal => product.price * qty;
}

class PosProvider extends ChangeNotifier {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final Map<int, CartItem> _cart = {};

  List<Product> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  Map<int, CartItem> get cart => _cart;

  int get totalItemsInCart => _cart.values.fold(0, (sum, item) => sum + item.qty);
  double get grandTotal => _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  final List<String> categories = [
    'Semua',
    'Antibiotik',
    'Analgesik',
    'Flu & Batuk',
    'Pencernaan',
    'P3K',
    'Vitamin',
    'Daya Tahan Tubuh',
    'Minyak Angin',
    'Obat Cacing',
  ];

  PosProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allProducts = await SupabaseService.instance.getProducts();
      _applyFilter();
    } catch (e) {
      // Load products fallback
    }
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _applyFilter();
  }

  void _applyFilter() {
    _filteredProducts = _allProducts.where((p) {
      final matchesCat = _selectedCategory == 'Semua' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
    notifyListeners();
  }

  // Cart operations
  void addToCart(Product product) {
    if (product.stock <= 0) return;

    if (_cart.containsKey(product.id)) {
      if (_cart[product.id]!.qty < product.stock) {
        _cart[product.id]!.qty++;
      }
    } else {
      _cart[product.id] = CartItem(product: product, qty: 1);
    }
    notifyListeners();
  }

  void decrementQty(int productId) {
    if (!_cart.containsKey(productId)) return;
    if (_cart[productId]!.qty > 1) {
      _cart[productId]!.qty--;
    } else {
      _cart.remove(productId);
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<TransactionModel> checkout({
    required String paymentMethod, // 'tunai' or 'qris'
    double? amountPaid,
    double? changeAmount,
    int? cashierId,
  }) async {
    final itemsPayload = _cart.values.map((item) {
      return {
        'product': item.product,
        'qty': item.qty,
        'price': item.product.price,
        'subtotal': item.subtotal,
      };
    }).toList();

    final trx = await SupabaseService.instance.createPosTransaction(
      items: itemsPayload,
      total: grandTotal,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      cashierId: cashierId,
    );

    clearCart();
    await loadProducts(); // reload updated stock
    return trx;
  }
}
