import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/purchases_repository.dart';
import '../../data/models/purchase_order_model.dart';

final _purchaseOrderDetailsProvider = FutureProvider.family<PurchaseOrderModel, String>((ref, id) {
  return ref.read(purchasesRepositoryProvider).getPurchaseOrderById(id);
});

class ReceiveGrnScreen extends ConsumerStatefulWidget {
  final String purchaseOrderId;
  const ReceiveGrnScreen({super.key, required this.purchaseOrderId});

  @override
  ConsumerState<ReceiveGrnScreen> createState() => _ReceiveGrnScreenState();
}

class _ReceiveGrnScreenState extends ConsumerState<ReceiveGrnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _grnNoCtrl = TextEditingController();
  final _supplierRefCtrl = TextEditingController();
  
  bool _isLoading = false;
  Map<String, int> _receivedQtys = {}; // Item ID to received quantity
  Map<String, double> _receivedCosts = {}; // Item ID to received unit cost

  @override
  void dispose() {
    _grnNoCtrl.dispose();
    _supplierRefCtrl.dispose();
    super.dispose();
  }

  void _initializeValues(PurchaseOrderModel po) {
    if (_receivedQtys.isEmpty) {
      for (final item in po.items) {
        _receivedQtys[item.id] = item.orderedQty;
        _receivedCosts[item.id] = item.unitCost;
      }
    }
  }

  Future<void> _submit(PurchaseOrderModel po) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate we are receiving something
    final receivingItems = po.items.where((item) => (_receivedQtys[item.id] ?? 0) > 0).toList();
    if (receivingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot receive 0 items'), backgroundColor: AppTheme.danger));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final grnItems = receivingItems.map((item) {
        final rQty = _receivedQtys[item.id]!;
        final rCost = _receivedCosts[item.id]!;
        final baseMultiplier = item.orderedQty == 0 ? 1 : item.orderedQtyBase / item.orderedQty; // Approx multiplier
        
        return {
          'id': const Uuid().v4(),
          'purchase_order_item_id': item.id,
          'product_id': item.productId,
          'product_unit_id': item.productUnitId,
          'received_qty': rQty,
          'received_qty_base': rQty * baseMultiplier.round(),
          'unit_cost': rCost,
          'unit_cost_base': rCost / baseMultiplier,
          'line_total': rQty * rCost,
        };
      }).toList();

      await ref.read(purchasesRepositoryProvider).createGrnAndReceive(
        poId: widget.purchaseOrderId,
        grnNo: _grnNoCtrl.text.trim(),
        supplierReference: _supplierRefCtrl.text.trim(),
        items: grnItems,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GRN Received successfully! Stock & WAC updated.'), backgroundColor: AppTheme.accent));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poAsync = ref.watch(_purchaseOrderDetailsProvider(widget.purchaseOrderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive GRN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: poAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
        data: (po) {
          _initializeValues(po);
          
          if (po.receivingStatus == 'Fully Received') {
            return const Center(child: Text('This PO is already fully received.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.elevatedDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purchase Order: \${po.poNo}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Supplier: \${po.supplierName}', style: const TextStyle(color: AppTheme.textSecondary)),
                        Text('Status: \${po.receivingStatus}', style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _grnNoCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(labelText: 'GRN Number', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _supplierRefCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(labelText: 'Supplier Invoice/Ref (Optional)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  const Text('Items to Receive', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(color: AppTheme.borderDark),
                  
                  ...po.items.map((item) {
                    return Card(
                      color: AppTheme.cardDark,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                            Text('Ordered: \${item.orderedQty} \${item.unitName ?? ''}', style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _receivedQtys[item.id]?.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: const InputDecoration(labelText: 'Received Qty', isDense: true),
                                    onChanged: (v) {
                                      _receivedQtys[item.id] = int.tryParse(v) ?? 0;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _receivedCosts[item.id]?.toStringAsFixed(2),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: const InputDecoration(labelText: 'Actual Unit Cost', isDense: true),
                                    onChanged: (v) {
                                      _receivedCosts[item.id] = double.tryParse(v) ?? 0;
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _submit(po),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppTheme.accent,
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Receive GRN'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
