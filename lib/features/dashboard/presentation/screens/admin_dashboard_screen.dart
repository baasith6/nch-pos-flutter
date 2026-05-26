import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../quotations/data/repositories/quotation_repository.dart';
import '../../../sales/data/models/sale_model.dart';

final _todaySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(salesRepositoryProvider).getTodaySummary();
});

final _lowStockCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.read(productRepositoryProvider).getLowStock();
  return products.length;
});

final _pendingQuotationsCountProvider = FutureProvider<int>((ref) async {
  return ref.read(quotationRepositoryProvider).getPendingQuotationsCount();
});

final _recentSalesProvider = FutureProvider<List<SaleModel>>((ref) async {
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final sales = await ref.read(salesRepositoryProvider).getAllSales(from: startOfDay);
  return sales.take(3).toList();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final todayAsync = ref.watch(_todaySummaryProvider);
    final lowStockAsync = ref.watch(_lowStockCountProvider);
    final pendingQuotationsAsync = ref.watch(_pendingQuotationsCountProvider);
    final recentSalesAsync = ref.watch(_recentSalesProvider);

    final lowStockCount = lowStockAsync.value ?? 0;
    final pendingQuoteCount = pendingQuotationsAsync.value ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) => CustomScrollView(
            slivers: [
              // --- 1. Header ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_greeting()}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Main Branch · Open',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _AvatarButton(
                        name: profile?.fullName ?? 'A',
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 2. Primary POS Action ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start New Sale',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Scan barcode or open billing',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go(AppRoutes.pos),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                label: const Text('Open POS', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.go(AppRoutes.pos), // Will implement held bills later
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.pause_circle_outline_rounded, size: 20),
                                label: const Text('Held Bills (0)', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 3. Today Summary Strip ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: todayAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox(),
                    data: (summary) {
                      final salesTotal = summary['total'] as double;
                      final txCount = summary['count'] as int;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStripItem('Today\'s Sales', salesTotal.toCurrency(), AppTheme.primary, isCurrency: true),
                            _buildStripDivider(),
                            _buildStripItem('Bills', '$txCount', AppTheme.textPrimary),
                            _buildStripDivider(),
                            _buildStripItem('Cash Sales', '0', AppTheme.textPrimary),
                            _buildStripDivider(),
                            _buildStripItem('Low Stock', '$lowStockCount', lowStockCount > 0 ? AppTheme.warning : AppTheme.textPrimary),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // --- 4. Needs Action ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Needs Action',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            _buildActionRow('Low Stock Items', lowStockCount, AppTheme.warning, () => context.push(AppRoutes.stockManagement)),
                            const Divider(height: 1, color: AppTheme.border),
                            _buildActionRow('Pending Quotations', pendingQuoteCount, const Color(0xFF6366F1), () => context.push(AppRoutes.quotations)),
                            const Divider(height: 1, color: AppTheme.border),
                            _buildActionRow('Supplier Dues', 0, const Color(0xFF3B82F6), () {}),
                            const Divider(height: 1, color: AppTheme.border),
                            _buildActionRow('Held Bills', 0, AppTheme.textSecondary, () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 5. Fast Operations ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fast Operations',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOperationChip('Add Product', Icons.add_box_rounded, () => context.push(AppRoutes.addProduct))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOperationChip('Adjust Stock', Icons.tune_rounded, () => context.push(AppRoutes.stockManagement))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOperationChip('Create Quote', Icons.request_quote_rounded, () => context.push(AppRoutes.createQuotation))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOperationChip('View Sales', Icons.receipt_long_rounded, () => context.push(AppRoutes.salesHistory))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- 6. Recent Bills ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Bills',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.salesHistory),
                            child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      recentSalesAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                        error: (e, _) => const Text('Failed to load recent sales'),
                        data: (sales) {
                          if (sales.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: const Text('No sales yet today.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textHint)),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: sales.asMap().entries.map((entry) {
                                final isLast = entry.key == sales.length - 1;
                                final sale = entry.value;
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('#${sale.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          Text(sale.grandTotal.toCurrency(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Today, ${DateFormat('h:mm a').format(sale.createdAt)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                      onTap: () {}, // Will link to details later
                                    ),
                                    if (!isLast) const Divider(height: 1, color: AppTheme.border),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // --- 7. More Tools ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'More Tools',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildToolChip('Products', Icons.inventory_2_rounded, () => context.go(AppRoutes.products)),
                          _buildToolChip('Suppliers', Icons.local_shipping_rounded, () => context.push(AppRoutes.suppliers)),
                          _buildToolChip('Customers', Icons.people_alt_rounded, () => context.push(AppRoutes.customers)),
                          _buildToolChip('Categories', Icons.category_rounded, () => context.push(AppRoutes.categories)),
                          _buildToolChip('Reports', Icons.bar_chart_rounded, () => context.push(AppRoutes.reports)),
                          _buildToolChip('Staff', Icons.people_rounded, () => context.push(AppRoutes.staff)),
                          _buildToolChip('Settings', Icons.settings_rounded, () => context.go(AppRoutes.settings)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildStripItem(String label, String value, Color color, {bool isCurrency = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildStripDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppTheme.border,
    );
  }

  Widget _buildActionRow(String label, int count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              const Text('0', style: TextStyle(color: AppTheme.textHint, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _AvatarButton({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
