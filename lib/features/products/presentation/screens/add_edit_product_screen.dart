import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../../../brands/data/models/brand_model.dart';
import '../../../brands/data/repositories/brand_repository.dart';
import '../../../units/data/models/unit_model.dart';
import '../../../units/data/repositories/unit_repository.dart';

final _categoriesForFormProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.read(categoryRepositoryProvider).getActive();
});

final _brandsForFormProvider = FutureProvider<List<BrandModel>>((ref) {
  return ref.read(brandRepositoryProvider).getActive();
});

final _unitsForFormProvider = FutureProvider<List<UnitModel>>((ref) {
  return ref.read(unitRepositoryProvider).getActive();
});

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductState();
}

class _AddEditProductState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();

  String? _categoryId;
  String? _brandId;
  String? _baseUnitId;
  String _status = 'Active';
  bool _isLoading = false;
  bool _isUploadingImage = false;

  String? _imageUrl;
  bool _initialized = false;
  final _uuid = const Uuid();

  @override
  void dispose() {
    _skuCtrl.dispose();
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
      final product = await ref.read(productRepositoryProvider).getById(widget.productId!);
      _skuCtrl.text = product.sku;
      _nameCtrl.text = product.name;
      _barcodeCtrl.text = product.barcode ?? '';
      _priceCtrl.text = product.sellingPriceBase.toStringAsFixed(2);
      _costCtrl.text = product.costPrice?.toStringAsFixed(2) ?? '';
      _stockCtrl.text = '${product.baseStockQuantity}';
      _reorderCtrl.text = '${product.reorderLevelBase}';
      _categoryId = product.categoryId;
      _brandId = product.brandId;
      _baseUnitId = product.baseUnitId;
      _status = product.status;
      _imageUrl = product.imageUrl;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (file == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final productId = widget.productId ?? _uuid.v4();
      final url = await ref.read(productRepositoryProvider).uploadImage(productId, bytes, extension);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_baseUnitId == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category and Base Unit'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isNew = widget.productId == null;
      final productId = isNew ? _uuid.v4() : widget.productId!;

      final product = ProductModel(
        id: productId,
        sku: _skuCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        sellingPriceBase: double.parse(_priceCtrl.text),
        costPrice: _costCtrl.text.isNotEmpty ? double.tryParse(_costCtrl.text) : null,
        baseStockQuantity: int.parse(_stockCtrl.text.isEmpty ? '0' : _stockCtrl.text),
        reorderLevelBase: int.parse(_reorderCtrl.text.isEmpty ? '0' : _reorderCtrl.text),
        categoryId: _categoryId,
        brandId: _brandId,
        baseUnitId: _baseUnitId,
        attributes: const {},
        status: _status,
        imageUrl: _imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(productRepositoryProvider);
      if (isNew) {
        await repo.create(product);
      } else {
        await repo.update(productId, product.toInsertJson());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? 'Product created' : 'Product updated'), backgroundColor: AppTheme.accent),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadProduct();
    final categoriesAsync = ref.watch(_categoriesForFormProvider);
    final brandsAsync = ref.watch(_brandsForFormProvider);
    final unitsAsync = ref.watch(_unitsForFormProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 28),
                    _buildBasicInfoSection(categoriesAsync, brandsAsync, unitsAsync),
                    const SizedBox(height: 28),
                    _buildPricingSection(),
                    const SizedBox(height: 28),
                    _buildStockSection(),
                    const SizedBox(height: 28),
                    _buildIdentifiersSection(),
                    const SizedBox(height: 28),
                    _buildStatusSection(),
                  ],
                ),
              ),
            ),
          ),
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  // ─── Sections ───────────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return Center(
      child: Column(
        children: [
          Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isUploadingImage ? null : _showImagePickerSheet,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isUploadingImage
                    ? const Center(child: CircularProgressIndicator())
                    : _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isUploadingImage ? null : _showImagePickerSheet,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(_imageUrl != null ? 'Change Image' : 'Upload Image'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(AsyncValue<List<CategoryModel>> cats, AsyncValue<List<BrandModel>> brands, AsyncValue<List<UnitModel>> units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Basic Information'),
        _label('Product Name *'),
        _buildTextField(
          controller: _nameCtrl,
          hint: 'e.g. Hammer',
          validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Category *'),
                  cats.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error', style: TextStyle(color: AppTheme.danger)),
                    data: (data) => _buildDropdown<String>(
                      value: _categoryId,
                      hint: 'Category',
                      items: [
                        ...data.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        const DropdownMenuItem(value: 'add_new', child: Text('+ Add New Category', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))),
                      ],
                      onChanged: (v) {
                        if (v == 'add_new') {
                          context.push(AppRoutes.categories);
                        } else {
                          setState(() => _categoryId = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Brand'),
                  brands.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error', style: TextStyle(color: AppTheme.danger)),
                    data: (data) => _buildDropdown<String>(
                      value: _brandId,
                      hint: 'Brand',
                      items: [
                        ...data.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                        const DropdownMenuItem(value: 'add_new', child: Text('+ Add New Brand', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))),
                      ],
                      onChanged: (v) {
                        if (v == 'add_new') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Brand coming soon')));
                        } else {
                          setState(() => _brandId = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Base Unit *'),
        units.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Error', style: TextStyle(color: AppTheme.danger)),
          data: (data) => _buildDropdown<String>(
            value: _baseUnitId,
            hint: 'Select Base Unit (e.g. Piece)',
            items: data.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
            onChanged: (v) => setState(() => _baseUnitId = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pricing'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Selling Price *'),
                  _buildTextField(
                    controller: _priceCtrl,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v) == null || double.parse(v) < 0) return 'Invalid price';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Cost Price'),
                  _buildTextField(
                    controller: _costCtrl,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    readOnly: widget.productId != null,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0)) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                  _helperText('Used to calculate profit and stock value'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Stock'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Opening Stock *'),
                  _buildTextField(
                    controller: _stockCtrl,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    readOnly: widget.productId != null,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v) == null || int.parse(v) < 0) return 'Invalid stock';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Reorder Level'),
                  _buildTextField(
                    controller: _reorderCtrl,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && (int.tryParse(v) == null || int.parse(v) < 0)) {
                        return 'Invalid level';
                      }
                      return null;
                    },
                  ),
                  _helperText('Alert when stock drops below this quantity'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentifiersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Identifiers'),
        _label('SKU'),
        _buildTextField(
          controller: _skuCtrl,
          hint: 'e.g. HW-001',
          suffixIcon: TextButton(
            onPressed: () {
              // Auto-generate SKU logic based on name or random
              if (_nameCtrl.text.isNotEmpty) {
                 final prefix = _nameCtrl.text.substring(0, 3).toUpperCase();
                 final random = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
                 _skuCtrl.text = '\$prefix-\$random';
              } else {
                 final random = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
                 _skuCtrl.text = 'HW-\$random';
              }
            },
            child: const Text('Auto', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        _helperText('Leave empty to auto-generate if needed'),
        const SizedBox(height: 16),
        _label('Barcode'),
        _buildTextField(
          controller: _barcodeCtrl,
          hint: 'Scan or enter barcode',
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            onPressed: () {
              // Should open scanner. For now just placeholder or use existing scanner
            },
          ),
        ),
        _helperText('Scan barcode for faster billing'),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Status'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Active', label: Text('Active')),
            ButtonSegment(value: 'Inactive', label: Text('Inactive')),
          ],
          selected: {_status},
          onSelectionChanged: (set) => setState(() => _status = set.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.primary.withValues(alpha: 0.1);
              }
              return AppTheme.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.primary;
              }
              return AppTheme.textSecondary;
            }),
            side: const WidgetStatePropertyAll(BorderSide(color: AppTheme.border)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
      );

  Widget _helperText(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
      );

  Widget _imagePlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Tap to add\nproduct image', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        fillColor: readOnly ? AppTheme.background : AppTheme.surface,
        filled: true,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.danger)),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        fillColor: AppTheme.surface,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary)),
      ),
    );
  }
}
