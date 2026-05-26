import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import 'theme.dart';
import '../core/services/auth_session_service.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (!isMobile) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppTheme.surface,
              selectedIndex: _calculateSelectedIndex(context),
              onDestinationSelected: (idx) => _onItemTapped(idx, context, ref),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              unselectedIconTheme: const IconThemeData(color: AppTheme.mutedText),
              unselectedLabelTextStyle: const TextStyle(color: AppTheme.mutedText),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('POS')),
                NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Sales')),
                NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Stock')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppTheme.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: child,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 18, right: 18, bottom: 12, top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(context, ref, 0, Icons.dashboard_rounded, 'Home'),
                  _buildNavItem(context, ref, 1, Icons.point_of_sale_rounded, 'POS'),
                  _buildNavItem(context, ref, 2, Icons.receipt_long_rounded, 'Sales'),
                  _buildNavItem(context, ref, 3, Icons.inventory_2_rounded, 'Stock'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, int index, IconData icon, String label) {
    final isSelected = _calculateSelectedIndex(context) == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index, context, ref),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 66,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? Colors.white : AppTheme.mutedText,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.mutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.pos)) return 1;
    if (location.startsWith(AppRoutes.salesHistory)) return 2;
    if (location.startsWith(AppRoutes.stockManagement) || location.startsWith(AppRoutes.products)) return 3;
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        final profile = ref.read(currentProfileProvider).value;
        if (profile?.isAdmin == true) {
          context.go(AppRoutes.adminDashboard);
        } else {
          context.go(AppRoutes.staffDashboard);
        }
        break;
      case 1:
        context.go(AppRoutes.pos);
        break;
      case 2:
        context.go(AppRoutes.salesHistory);
        break;
      case 3:
        context.go(AppRoutes.stockManagement);
        break;
    }
  }
}
