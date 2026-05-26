import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../providers/customer_providers.dart';
import 'add_edit_customer_screen.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
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
              builder: (_) => const AddEditCustomerScreen(),
            ),
          ).then((_) => ref.refresh(customersProvider));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger)),
        ),
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(
              child: Text(
                'No customers found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    customer.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    customer.phone ?? 'No Phone Number',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: customer.creditLimit > 0 
                      ? Text(
                          'Limit: ${customer.creditLimit.toCurrency()}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditCustomerScreen(customer: customer),
                      ),
                    ).then((_) => ref.refresh(customersProvider));
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
