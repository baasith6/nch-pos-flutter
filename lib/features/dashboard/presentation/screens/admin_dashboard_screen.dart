import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../products/data/repositories/product_repository.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final todayAsync = ref.watch(_todaySummaryProvider);
    final lowStockAsync = ref.watch(_lowStockCountProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (profile) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good ${_greeting()}, 👋',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile?.fullName ?? 'Admin',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _AvatarButton(
                          name: profile?.fullName ?? 'A',
                          onTap: () => context.push(AppRoutes.profile),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: todayAsync.when(
                      loading: () => _SummarySkeleton(),
                      error: (e, _) => const SizedBox(),
                      data: (summary) => Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: "Today's Sales",
                              value: (summary['total'] as double).toCurrency(),
                              icon: Icons.trending_up_rounded,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Transactions',
                              value: '${summary['count']}',
                              icon: Icons.receipt_long_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: lowStockAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (count) => count > 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: _AlertBanner(
                              message: '$count products are low on stock',
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              onTap: () => context.push(AppRoutes.stockManagement),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      _QuickAction(
                        icon: Icons.point_of_sale_rounded,
                        label: 'POS',
                        color: AppTheme.primary,
                        onTap: () => context.push(AppRoutes.pos),
                      ),
                      _QuickAction(
                        icon: Icons.inventory_2_outlined,
                        label: 'Products',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.push(AppRoutes.products),
                      ),
                      _QuickAction(
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        color: const Color(0xFF06B6D4),
                        onTap: () => context.push(AppRoutes.categories),
                      ),
                      _QuickAction(
                        icon: Icons.people_outline_rounded,
                        label: 'Staff',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.push(AppRoutes.staff),
                      ),
                      _QuickAction(
                        icon: Icons.local_shipping_outlined,
                        label: 'Suppliers',
                        color: const Color(0xFF3B82F6),
                        onTap: () => context.push(AppRoutes.suppliers),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_outlined,
                        label: 'Sales',
                        color: const Color(0xFF10B981),
                        onTap: () => context.push(AppRoutes.salesHistory),
                      ),
                      _QuickAction(
                        icon: Icons.request_quote_outlined,
                        label: 'Quotations',
                        color: const Color(0xFF6366F1),
                        onTap: () => context.push(AppRoutes.quotations),
                      ),
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Reports',
                        color: const Color(0xFFEF4444),
                        onTap: () => context.push(AppRoutes.reports),
                      ),
                      _QuickAction(
                        icon: Icons.warehouse_outlined,
                        label: 'Stock',
                        color: const Color(0xFFEC4899),
                        onTap: () => context.push(AppRoutes.stockManagement),
                      ),
                      _QuickAction(
                        icon: Icons.shopping_cart_checkout_rounded,
                        label: 'Purchasing',
                        color: const Color(0xFF14B8A6),
                        onTap: () => context.push(AppRoutes.purchases),
                      ),
                      _QuickAction(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        color: AppTheme.textSecondary,
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

final _todaySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(salesRepositoryProvider).getTodaySummary();
});

final _lowStockCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.read(productRepositoryProvider).getLowStock();
  return products.length;
});

class _AvatarButton extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _AvatarButton({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AlertBanner({required this.message, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16)))),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16)))),
      ],
    );
  }
}
