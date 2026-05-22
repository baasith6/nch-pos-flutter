import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/supplier_repository.dart';
import 'add_edit_supplier_screen.dart';

final suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) {
  return ref.read(supplierRepositoryProvider).getAll();
});

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditSupplierScreen(),
            ),
          ).then((_) => ref.refresh(suppliersProvider));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
        ),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(
              child: Text(
                'No suppliers found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Card(
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    supplier.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    supplier.contactName ?? 'No Contact Person',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditSupplierScreen(supplier: supplier),
                      ),
                    ).then((_) => ref.refresh(suppliersProvider));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
