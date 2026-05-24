import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main_layout.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../features/dashboard/presentation/screens/staff_dashboard_screen.dart';
import '../features/purchases/presentation/screens/purchase_order_list_screen.dart';
import '../features/purchases/presentation/screens/add_edit_purchase_order_screen.dart';
import '../features/purchases/presentation/screens/receive_grn_screen.dart';
import '../features/products/presentation/screens/product_list_screen.dart';
import '../features/products/presentation/screens/add_edit_product_screen.dart';
import '../features/products/presentation/screens/product_units_screen.dart';
import '../features/categories/presentation/screens/category_list_screen.dart';
import '../features/pos/presentation/screens/pos_screen.dart';
import '../features/pos/presentation/screens/checkout_screen.dart';
import '../features/pos/presentation/screens/receipt_screen.dart';
import '../features/sales/presentation/screens/sales_history_screen.dart';
import '../features/sales/presentation/screens/sale_detail_screen.dart';
import '../features/staff/presentation/screens/staff_list_screen.dart';
import '../features/staff/presentation/screens/add_staff_screen.dart';
import '../features/stock/presentation/screens/stock_management_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/reports/presentation/screens/stock_valuation_report_screen.dart';
import '../features/reports/presentation/screens/customer_ledger_report_screen.dart';
import '../features/reports/presentation/screens/supplier_ledger_report_screen.dart';
import '../features/suppliers/presentation/screens/supplier_list_screen.dart';
import '../features/payments/presentation/screens/supplier_payments_screen.dart';
import '../features/payments/presentation/screens/customer_payments_screen.dart';
import '../features/quotations/presentation/screens/quotation_list_screen.dart';
import '../features/quotations/presentation/screens/create_quotation_screen.dart';
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
  static const productUnits = '/products/:id/units';
  static const purchases = '/purchases';
  static const addPurchase = '/purchases/add';
  static const receiveGrn = '/purchases/:id/receive';
  static const categories = '/categories';
  static const pos = '/pos';
  static const checkout = '/pos/checkout';
  static const receipt = '/receipt/:saleId';
  static const salesHistory = '/sales';
  static const saleDetail = '/sales/:id';
  static const staff = '/staff';
  static const addStaff = '/staff/add';
  static const stockManagement = '/stock';
  static const reports = '/reports';
  static const stockValuationReport = '/reports/stock-valuation';
  static const customerLedgerReport = '/reports/customer-ledgers';
  static const supplierLedgerReport = '/reports/supplier-ledgers';
  static const customerPayments = '/payments/customer';
  static const supplierPayments = '/payments/supplier';
  static const suppliers = '/suppliers';
  static const quotations = '/quotations';
  static const createQuotation = '/quotations/create';
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

      // ─── Main Layout (Bottom Nav / Side Rail) ──────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.staffDashboard,
            builder: (_, __) => const StaffDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.products,
            builder: (_, __) => const ProductListScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),

      // ─── Outside ShellRoute (Full Screen) ──────────────────────────────
      // POS Screen is intentionally outside the ShellRoute so the cart
      // and checkout flow have full vertical screen space.
      GoRoute(
        path: AppRoutes.pos,
        builder: (_, __) => const PosScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CheckoutScreen(
            subtotal: extra['subtotal'] ?? 0.0,
            discount: extra['discount'] ?? 0.0,
            taxAmount: extra['taxAmount'] ?? 0.0,
            grandTotal: extra['grandTotal'] ?? 0.0,
          );
        },
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
        path: AppRoutes.productUnits,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductUnitsScreen(productId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.purchases,
        builder: (_, __) => const PurchaseOrderListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addPurchase,
        builder: (_, __) => const AddEditPurchaseOrderScreen(),
      ),
      GoRoute(
        path: AppRoutes.receiveGrn,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReceiveGrnScreen(purchaseOrderId: id);
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
        path: AppRoutes.stockValuationReport,
        builder: (_, __) => const StockValuationReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerLedgerReport,
        builder: (_, __) => const CustomerLedgerReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.supplierLedgerReport,
        builder: (_, __) => const SupplierLedgerReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerPayments,
        builder: (_, __) => const CustomerPaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.supplierPayments,
        builder: (_, __) => const SupplierPaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.suppliers,
        builder: (_, __) => const SupplierListScreen(),
      ),
      GoRoute(
        path: AppRoutes.quotations,
        builder: (_, __) => const QuotationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.createQuotation,
        builder: (_, __) => const CreateQuotationScreen(),
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
