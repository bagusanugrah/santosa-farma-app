import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null for add, non-null for edit

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descController;

  File? _pickedImage;
  bool _isLoading = false;

  final List<String> _categoryOptions = [
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

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(text: p?.category ?? 'Vitamin');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _stockController = TextEditingController(text: p != null ? p.stock.toString() : '');
    _descController = TextEditingController(text: p?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ambil Foto Obat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF059669)),
                title: const Text('Buka Kamera HP'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF059669)),
                title: const Text('Pilih dari Galeri Foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final desc = _descController.text.trim();

    try {
      if (widget.product == null) {
        // Add
        await SupabaseService.instance.addProduct(
          name: name,
          category: category,
          price: price,
          stock: stock,
          description: desc,
          imageFile: _pickedImage,
          fileName: _pickedImage?.path.split('/').last,
        );
      } else {
        // Update
        final updated = widget.product!.copyWith(
          name: name,
          category: category,
          price: price,
          stock: stock,
          description: desc,
        );
        await SupabaseService.instance.updateProduct(
          updated,
          imageFile: _pickedImage,
          fileName: _pickedImage?.path.split('/').last,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'Obat baru berhasil ditambahkan!' : 'Data obat berhasil diperbarui!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Data Obat' : 'Tambah Obat Baru', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isLoading ? null : _saveProduct,
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photo Box
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _pickedImage != null
                              ? Image.file(_pickedImage!, fit: BoxFit.cover)
                              : (widget.product?.imageUrl.isNotEmpty ?? false)
                                  ? CachedNetworkImage(
                                      imageUrl: widget.product!.imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(Icons.medication, size: 48, color: Colors.grey),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_a_photo, size: 36, color: Color(0xFF64748B)),
                                          SizedBox(height: 4),
                                          Text('Foto Obat', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Material(
                            color: const Color(0xFF059669),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _showImagePickerSheet,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap Obat',
                      hintText: 'Contoh: Amoxicillin 500mg Strip (10 Kaplet)',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Nama obat wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    value: _categoryOptions.contains(_categoryController.text) ? _categoryController.text : _categoryOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Obat',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categoryOptions.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _categoryController.text = val;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price & Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual (Rp)',
                            prefixText: 'Rp ',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Harga wajib diisi';
                            if (double.tryParse(val) == null) return 'Format angka tidak valid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Stok',
                            suffixText: 'unit',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Stok wajib diisi';
                            if (int.tryParse(val) == null) return 'Harus bilangan bulat';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi / Aturan Pakai Obat',
                      hintText: 'Khasiat, aturan minum, dan peringatan...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
