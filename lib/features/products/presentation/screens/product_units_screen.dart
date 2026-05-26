import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../../units/data/models/unit_model.dart';
import '../../../units/data/repositories/unit_repository.dart';

final _unitsForFormProvider = FutureProvider<List<UnitModel>>((ref) {
  return ref.read(unitRepositoryProvider).getActive();
});

class ProductUnitsScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductUnitsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductUnitsScreen> createState() => _ProductUnitsScreenState();
}

class _ProductUnitsScreenState extends ConsumerState<ProductUnitsScreen> {
  bool _isLoading = true;
  ProductModel? _product;
  List<ProductUnitModel> _productUnits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      _product = await repo.getById(widget.productId);
      _productUnits = await repo.getUnitsForProduct(widget.productId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditUnitDialog([ProductUnitModel? existingUnit]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddEditUnitDialog(
        productId: widget.productId,
        existingUnit: existingUnit,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteUnit(String unitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Delete Unit Conversion', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to remove this unit conversion?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => ctx.pop(true), child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(productRepositoryProvider).deleteUnit(unitId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting unit: \$e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Units Management')),
        body: const Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Units for \${_product!.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _productUnits.length,
        itemBuilder: (context, index) {
          final u = _productUnits[index];
          return Card(
            color: AppTheme.cardDark,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(u.unitName ?? 'Unknown Unit', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Multiplier: ${u.baseQuantityMultiplier} | Price: ${u.sellingPrice.toCurrency()}\nBarcode: ${u.barcode ?? "None"}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.accent),
                    onPressed: () => _showAddEditUnitDialog(u),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.danger),
                    onPressed: () => _deleteUnit(u.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditUnitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Unit Conversion'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }
}

class _AddEditUnitDialog extends ConsumerStatefulWidget {
  final String productId;
  final ProductUnitModel? existingUnit;
  final VoidCallback onSaved;

  const _AddEditUnitDialog({
    required this.productId,
    this.existingUnit,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddEditUnitDialog> createState() => _AddEditUnitDialogState();
}

class _AddEditUnitDialogState extends ConsumerState<_AddEditUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _unitId;
  final _multiplierCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isDefaultSales = false;
  bool _isDefaultPurchase = false;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingUnit != null) {
      final u = widget.existingUnit!;
      _unitId = u.unitId;
      _multiplierCtrl.text = u.baseQuantityMultiplier.toString();
      _barcodeCtrl.text = u.barcode ?? '';
      _priceCtrl.text = u.sellingPrice.toStringAsFixed(2);
      _isDefaultSales = u.isDefaultSalesUnit;
      _isDefaultPurchase = u.isDefaultPurchaseUnit;
      _isActive = u.isActive;
    }
  }

  @override
  void dispose() {
    _multiplierCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      
      if (widget.existingUnit == null) {
        // Create
        final newUnit = ProductUnitModel(
          id: const Uuid().v4(), // In real app, might just let DB generate UUID but since model requires it
          productId: widget.productId,
          unitId: _unitId!,
          baseQuantityMultiplier: int.parse(_multiplierCtrl.text),
          barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          sellingPrice: double.parse(_priceCtrl.text),
          isDefaultSalesUnit: _isDefaultSales,
          isDefaultPurchaseUnit: _isDefaultPurchase,
          isActive: _isActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createUnit(newUnit);
      } else {
        // Update
        final updates = {
          'unit_id': _unitId,
          'base_quantity_multiplier': int.parse(_multiplierCtrl.text),
          'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          'selling_price': double.parse(_priceCtrl.text),
          'is_default_sales_unit': _isDefaultSales,
          'is_default_purchase_unit': _isDefaultPurchase,
          'is_active': _isActive,
        };
        await repo.updateUnit(widget.existingUnit!.id, updates);
      }
      
      if (mounted) {
        widget.onSaved();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(_unitsForFormProvider);

    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existingUnit == null ? 'Add Unit Conversion' : 'Edit Unit Conversion', 
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              unitsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading units', style: TextStyle(color: AppTheme.danger)),
                data: (units) => DropdownButtonFormField<String>(
                  value: _unitId,
                  dropdownColor: AppTheme.elevatedDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Unit (e.g. Box, Dozen)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  items: units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                  onChanged: (v) => setState(() => _unitId = v),
                ),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _multiplierCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Base Quantity Multiplier (e.g. 12)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Selling Price for this Unit', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _barcodeCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Barcode (Optional)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 16),
              
              CheckboxListTile(
                title: const Text('Default Sales Unit', style: TextStyle(color: AppTheme.textPrimary)),
                value: _isDefaultSales,
                onChanged: (v) => setState(() => _isDefaultSales = v ?? false),
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Default Purchase Unit', style: TextStyle(color: AppTheme.textPrimary)),
                value: _isDefaultPurchase,
                onChanged: (v) => setState(() => _isDefaultPurchase = v ?? false),
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
