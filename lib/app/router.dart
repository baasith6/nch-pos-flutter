import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../features/dashboard/presentation/screens/staff_dashboard_screen.dart';
import '../features/products/presentation/screens/product_list_screen.dart';
import '../features/products/presentation/screens/add_edit_product_screen.dart';
import '../features/categories/presentation/screens/category_list_screen.dart';
import '../features/pos/presentation/screens/pos_screen.dart';
import '../features/pos/presentation/screens/receipt_screen.dart';
import '../features/sales/presentation/screens/sales_history_screen.dart';
import '../features/sales/presentation/screens/sale_detail_screen.dart';
import '../features/staff/presentation/screens/staff_list_screen.dart';
import '../features/staff/presentation/screens/add_staff_screen.dart';
import '../features/stock/presentation/screens/stock_management_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/auth/presentation/screens/profile_screen.dart';
import '../features/auth/presentation/screens/change_password_screen.dart';

// Route path constants
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const adminDashboard = '/admin';
  static const staffDashboard = '/staff';
  static const products = '/products';
  static const addProduct = '/products/add';
  static const editProduct = '/products/edit/:id';
  static const categories = '/categories';
  static const pos = '/pos';
  static const receipt = '/receipt/:saleId';
  static const salesHistory = '/sales';
  static const saleDetail = '/sales/:id';
  static const staff = '/staff';
  static const addStaff = '/staff/add';
  static const stockManagement = '/stock';
  static const reports = '/reports';
  static const settings = '/settings';
  static const profile = '/profile';
  static const changePassword = '/change-password';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      // Let splash handle initial redirect
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

      // ─── Admin Routes ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.products,
        builder: (_, __) => const ProductListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addProduct,
        builder: (_, __) => const AddEditProductScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProduct,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditProductScreen(productId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (_, __) => const CategoryListScreen(),
      ),
      GoRoute(
        path: AppRoutes.staff,
        builder: (_, __) => const StaffListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addStaff,
        builder: (_, __) => const AddStaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.stockManagement,
        builder: (_, __) => const StockManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),

      // ─── Shared Routes ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.staffDashboard,
        builder: (_, __) => const StaffDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.pos,
        builder: (_, __) => const PosScreen(),
      ),
      GoRoute(
        path: AppRoutes.receipt,
        builder: (context, state) {
          final saleId = state.pathParameters['saleId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ReceiptScreen(saleId: saleId, receiptData: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.salesHistory,
        builder: (_, __) => const SalesHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.saleDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SaleDetailScreen(saleId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, __) => const ChangePasswordScreen(),
      ),
    ],
  );
});
