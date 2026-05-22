import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';

final _categoriesForFormProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.read(categoryRepositoryProvider).getActive();
});

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductState();
}

class _AddEditProductState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _reorderCtrl = TextEditingController(text: '0');
  String? _categoryId;
  String _status = 'Active';
  bool _isLoading = false;
  bool _isUploadingImage = false;

  String? _imageUrl; // existing or newly uploaded URL
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (_initialized || widget.productId == null) return;
    _initialized = true;
    try {
      final product =
          await ref.read(productRepositoryProvider).getById(widget.productId!);
      _nameCtrl.text = product.name;
      _barcodeCtrl.text = product.barcode ?? '';
      _priceCtrl.text = product.sellingPrice.toStringAsFixed(2);
      _costCtrl.text = product.costPrice?.toStringAsFixed(2) ?? '';
      _stockCtrl.text = '${product.stockQuantity}';
      _reorderCtrl.text = '${product.reorderLevel}';
      _categoryId = product.categoryId;
      _status = product.status;
      _imageUrl = product.imageUrl;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (file == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final productId =
          widget.productId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final url = await ref
          .read(productRepositoryProvider)
          .uploadImage(productId, bytes, extension);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image upload failed: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final product = ProductModel(
        id: widget.productId ?? '',
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        sellingPrice: double.parse(_priceCtrl.text),
        costPrice:
            _costCtrl.text.isNotEmpty ? double.tryParse(_costCtrl.text) : null,
        stockQuantity: int.parse(_stockCtrl.text),
        reorderLevel: int.parse(_reorderCtrl.text),
        categoryId: _categoryId,
        status: _status,
        imageUrl: _imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(productRepositoryProvider);
      if (widget.productId == null) {
        await repo.create(product);
      } else {
        await repo.update(widget.productId!, product.toInsertJson());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.productId == null
              ? 'Product created'
              : 'Product updated'),
          backgroundColor: AppTheme.accent,
        ),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadProduct();
    final categoriesAsync = ref.watch(_categoriesForFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image picker ────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.elevatedDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.borderDark, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isUploadingImage
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _isUploadingImage ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(_imageUrl != null
                      ? 'Change Image'
                      : 'Upload Image'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 6),

              _label('Product Name'),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration:
                    const InputDecoration(hintText: 'e.g. Coca-Cola 330ml'),
                validator: (v) =>
                    v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _label('Barcode (optional)'),
              TextFormField(
                controller: _barcodeCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration:
                    const InputDecoration(hintText: '1234567890'),
              ),
              const SizedBox(height: 14),
              _label('Category'),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load categories',
                    style: TextStyle(color: AppTheme.danger)),
                data: (cats) => DropdownButtonFormField<String>(
                  value: _categoryId,
                  dropdownColor: AppTheme.elevatedDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Select category'),
                  items: cats
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Selling Price'),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            style:
                                const TextStyle(color: AppTheme.textPrimary),
                            decoration:
                                const InputDecoration(hintText: '0.00'),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Cost Price'),
                          TextFormField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            style:
                                const TextStyle(color: AppTheme.textPrimary),
                            decoration:
                                const InputDecoration(hintText: '0.00'),
                          ),
                        ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Stock Qty'),
                          TextFormField(
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            style:
                                const TextStyle(color: AppTheme.textPrimary),
                            decoration:
                                const InputDecoration(hintText: '0'),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Reorder Level'),
                          TextFormField(
                            controller: _reorderCtrl,
                            keyboardType: TextInputType.number,
                            style:
                                const TextStyle(color: AppTheme.textPrimary),
                            decoration:
                                const InputDecoration(hintText: '0'),
                          ),
                        ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('Status'),
              DropdownButtonFormField<String>(
                value: _status,
                dropdownColor: AppTheme.elevatedDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: ['Active', 'Inactive']
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(widget.productId == null
                        ? 'Create Product'
                        : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: AppTheme.textHint.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 6),
          const Text('Tap to add\nimage',
              style: TextStyle(color: AppTheme.textHint, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      );
}
