import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/purchases_repository.dart';
import '../../../suppliers/data/models/supplier_model.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/models/product_unit_model.dart';
import '../../../products/data/repositories/product_repository.dart';

final _suppliersProvider = FutureProvider<List<SupplierModel>>((ref) {
  return ref.read(supplierRepositoryProvider).getActive();
});

class AddEditPurchaseOrderScreen extends ConsumerStatefulWidget {
  const AddEditPurchaseOrderScreen({super.key});

  @override
  ConsumerState<AddEditPurchaseOrderScreen> createState() => _AddEditPurchaseOrderState();
}

class _AddEditPurchaseOrderState extends ConsumerState<AddEditPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poNoCtrl = TextEditingController();
  
  String? _supplierId;
  final List<Map<String, dynamic>> _items = []; // {product: ProductModel, unit: ProductUnitModel, qty: int, cost: double}
  
  bool _isLoading = false;

  @override
  void dispose() {
    _poNoCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0, (sum, item) {
      final qty = item['qty'] as int;
      final cost = item['cost'] as double;
      return sum + (qty * cost);
    });
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddPoItemDialog(
        onAdd: (product, unit, qty, cost) {
          setState(() {
            _items.add({
              'product': product,
              'unit': unit,
              'qty': qty,
              'cost': cost,
            });
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier'), backgroundColor: AppTheme.danger));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item'), backgroundColor: AppTheme.danger));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final itemsToInsert = _items.map((i) {
        final product = i['product'] as ProductModel;
        final unit = i['unit'] as ProductUnitModel?;
        final qty = i['qty'] as int;
        final cost = i['cost'] as double;
        
        final baseMultiplier = unit?.baseQuantityMultiplier ?? 1;
        
        return {
          'id': const Uuid().v4(),
          'product_id': product.id,
          'product_unit_id': unit?.id ?? product.baseUnitId,
          'ordered_qty': qty,
          'ordered_qty_base': qty * baseMultiplier,
          'unit_cost': cost,
          'unit_cost_base': cost / baseMultiplier,
          'line_total': qty * cost,
        };
      }).toList();

      await ref.read(purchasesRepositoryProvider).createPurchaseOrder(
        supplierId: _supplierId!,
        poNo: _poNoCtrl.text.trim(),
        subtotal: _subtotal,
        tax: 0, // Ignoring tax for simplicity in V1
        grandTotal: _subtotal,
        items: itemsToInsert,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Order created'), backgroundColor: AppTheme.accent));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(_suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Purchase Order'),
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
              TextFormField(
                controller: _poNoCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'PO Number', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              
              suppliersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Error: $err', style: const TextStyle(color: AppTheme.danger)),
                data: (suppliers) => DropdownButtonFormField<String>(
                  value: _supplierId,
                  dropdownColor: AppTheme.elevatedDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Supplier', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Items', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add, color: AppTheme.accent),
                    label: const Text('Add Item', style: TextStyle(color: AppTheme.accent)),
                  )
                ],
              ),
              const Divider(color: AppTheme.borderDark),
              
              ..._items.map((i) {
                final product = i['product'] as ProductModel;
                final unit = i['unit'] as ProductUnitModel?;
                final qty = i['qty'] as int;
                final cost = i['cost'] as double;
                return ListTile(
                  title: Text(product.name, style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text('Qty: $qty ${unit?.unitName ?? "Base"} | Cost: ${cost.toCurrency()}', style: const TextStyle(color: AppTheme.textSecondary)),
                  trailing: Text((qty * cost).toCurrency(), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                );
              }),
              
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No items added', style: TextStyle(color: AppTheme.textSecondary))),
                ),
                
              const Divider(color: AppTheme.borderDark),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Grand Total: ', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                    Flexible(
                      child: Text(_subtotal.toCurrency(), style: const TextStyle(color: AppTheme.accent, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppTheme.accent,
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create PO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPoItemDialog extends ConsumerStatefulWidget {
  final void Function(ProductModel, ProductUnitModel?, int, double) onAdd;
  const _AddPoItemDialog({required this.onAdd});

  @override
  ConsumerState<_AddPoItemDialog> createState() => _AddPoItemDialogState();
}

class _AddPoItemDialogState extends ConsumerState<_AddPoItemDialog> {
  final _searchCtrl = TextEditingController();
  List<ProductModel> _searchResults = [];
  ProductModel? _selectedProduct;
  List<ProductUnitModel> _units = [];
  ProductUnitModel? _selectedUnit;
  
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();

  Future<void> _search() async {
    final res = await ref.read(productRepositoryProvider).searchProducts(_searchCtrl.text);
    setState(() => _searchResults = res);
  }

  Future<void> _selectProduct(ProductModel p) async {
    setState(() {
      _selectedProduct = p;
      _costCtrl.text = p.costPrice?.toStringAsFixed(2) ?? '0.00';
      _searchResults = [];
    });
    
    final units = await ref.read(productRepositoryProvider).getUnitsForProduct(p.id);
    setState(() {
      _units = units;
      _selectedUnit = units.where((u) => u.isDefaultPurchaseUnit).firstOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add PO Item', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (_selectedProduct == null) ...[
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search product...',
                  hintStyle: const TextStyle(color: AppTheme.textHint),
                  suffixIcon: IconButton(icon: const Icon(Icons.search, color: AppTheme.accent), onPressed: _search),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) {
                    final p = _searchResults[i];
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(p.sku, style: const TextStyle(color: AppTheme.textSecondary)),
                      onTap: () => _selectProduct(p),
                    );
                  },
                ),
              ),
            ] else ...[
              Text('Selected: \${_selectedProduct!.name}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (_units.isNotEmpty)
                DropdownButtonFormField<ProductUnitModel>(
                  value: _selectedUnit,
                  dropdownColor: AppTheme.elevatedDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Unit', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.unitName ?? ''))).toList(),
                  onChanged: (v) => setState(() => _selectedUnit = v),
                )
              else
                Text('Unit: \${_selectedProduct!.baseUnitName}', style: const TextStyle(color: AppTheme.textSecondary)),
                
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Unit Cost', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => context.pop(), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      final qty = int.tryParse(_qtyCtrl.text) ?? 1;
                      final cost = double.tryParse(_costCtrl.text) ?? 0;
                      widget.onAdd(_selectedProduct!, _selectedUnit, qty, cost);
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('Add'),
                  )
                ],
              )
            ],
          ],
        ),
      ),
    );
  }
}
