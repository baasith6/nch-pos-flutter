import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/report_repository.dart';

// ─── Date range preset ────────────────────────────────────────────────────────
enum _DatePreset { today, week, month, custom }

class _DateRange {
  final _DatePreset preset;
  final DateTime from;
  final DateTime to;
  const _DateRange({required this.preset, required this.from, required this.to});
}

_DateRange _presetRange(_DatePreset preset, [DateTimeRange? custom]) {
  final now = DateTime.now();
  switch (preset) {
    case _DatePreset.today:
      return _DateRange(
        preset: preset,
        from: DateTime(now.year, now.month, now.day),
        to: now,
      );
    case _DatePreset.week:
      return _DateRange(
        preset: preset,
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
    case _DatePreset.month:
      return _DateRange(
        preset: preset,
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
    case _DatePreset.custom:
      return _DateRange(
        preset: preset,
        from: custom?.start ?? DateTime(now.year, now.month, now.day),
        to: custom?.end ?? now,
      );
  }
}

final _dateRangeProvider = StateProvider<_DateRange>(
  (_) => _presetRange(_DatePreset.today),
);

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_dateRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Date range selector ──────────────────────────────────────
          _DateRangeSelector(
            currentPreset: range.preset,
            from: range.from,
            to: range.to,
            onPresetSelected: (preset) {
              if (preset == _DatePreset.custom) {
                _pickCustomRange(context, ref);
              } else {
                ref.read(_dateRangeProvider.notifier).state =
                    _presetRange(preset);
              }
            },
          ),
          const SizedBox(height: 16),

          // ── Report tiles ─────────────────────────────────────────────
          _ReportTile(
            icon: Icons.today_outlined,
            label: 'Sales Summary',
            color: AppTheme.primary,
            onTap: () => _showSalesReport(context, ref, range),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.inventory_outlined,
            label: 'Product Sales',
            color: const Color(0xFF8B5CF6),
            onTap: () => _showProductReport(context, ref, range),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.people_outline,
            label: 'Staff Sales',
            color: const Color(0xFFF59E0B),
            onTap: () => _showStaffReport(context, ref, range),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.payments_outlined,
            label: 'Payment Methods',
            color: const Color(0xFF06D6A0),
            onTap: () => _showPaymentReport(context, ref, range),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.trending_up_rounded,
            label: 'Profit Report',
            color: AppTheme.danger,
            subtitle: 'Admin only',
            onTap: () => _showProfitReport(context, ref, range),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.warning_amber_rounded,
            label: 'Low Stock',
            color: AppTheme.warning,
            onTap: () => context.push('/stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext ctx, WidgetRef ref) async {
    final range = ref.read(_dateRangeProvider);
    final picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          DateTimeRange(start: range.from, end: range.to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.cardDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(_dateRangeProvider.notifier).state =
          _presetRange(_DatePreset.custom, picked);
    }
  }

  void _showSalesReport(
      BuildContext ctx, WidgetRef ref, _DateRange range) {
    _openSheet(
        ctx,
        _SalesReportSheet(
            from: range.from, to: range.to, ref: ref));
  }

  void _showProductReport(
      BuildContext ctx, WidgetRef ref, _DateRange range) {
    _openSheet(
        ctx,
        _ProductReportSheet(
            from: range.from, to: range.to, ref: ref),
        scrollControlled: true);
  }

  void _showStaffReport(
      BuildContext ctx, WidgetRef ref, _DateRange range) {
    _openSheet(
        ctx,
        _StaffReportSheet(from: range.from, to: range.to, ref: ref),
        scrollControlled: true);
  }

  void _showPaymentReport(
      BuildContext ctx, WidgetRef ref, _DateRange range) {
    _openSheet(
        ctx,
        _PaymentReportSheet(
            from: range.from, to: range.to, ref: ref));
  }

  void _showProfitReport(
      BuildContext ctx, WidgetRef ref, _DateRange range) {
    _openSheet(
        ctx,
        _ProfitReportSheet(from: range.from, to: range.to, ref: ref));
  }

  void _openSheet(BuildContext ctx, Widget sheet,
      {bool scrollControlled = false}) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: scrollControlled,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => sheet,
    );
  }
}

// ─── Date range selector widget ───────────────────────────────────────────────
class _DateRangeSelector extends StatelessWidget {
  final _DatePreset currentPreset;
  final DateTime from;
  final DateTime to;
  final void Function(_DatePreset) onPresetSelected;

  const _DateRangeSelector({
    required this.currentPreset,
    required this.from,
    required this.to,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _chip(_DatePreset.today, 'Today'),
            _chip(_DatePreset.week, 'This Week'),
            _chip(_DatePreset.month, 'This Month'),
            _chip(_DatePreset.custom, 'Custom…',
                icon: Icons.calendar_today_outlined),
          ],
        ),
        if (currentPreset == _DatePreset.custom) ...[
          const SizedBox(height: 6),
          Text(
            '${from.day}/${from.month}/${from.year} → ${to.day}/${to.month}/${to.year}',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _chip(_DatePreset preset, String label, {IconData? icon}) {
    final selected = currentPreset == preset;
    return GestureDetector(
      onTap: () => onPresetSelected(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.elevatedDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.borderDark,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 12,
                  color: selected ? AppTheme.primary : AppTheme.textHint),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Report Tiles ─────────────────────────────────────────────────────────────
class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ReportTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderDark, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Sales Summary Sheet ──────────────────────────────────────────────────────
class _SalesReportSheet extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final WidgetRef ref;
  const _SalesReportSheet(
      {required this.from, required this.to, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getSalesByDateRange(from: from, to: to),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sales = snap.data ?? [];
        double total = sales.fold(
            0,
            (s, e) =>
                s + ((e['grand_total'] as num?)?.toDouble() ?? 0));
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sales Summary',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _ReportStat(
                  label: 'Total Transactions',
                  value: '${sales.length}'),
              _ReportStat(
                  label: 'Revenue', value: total.toCurrency()),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ─── Product Report Sheet ─────────────────────────────────────────────────────
class _ProductReportSheet extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final WidgetRef ref;
  const _ProductReportSheet(
      {required this.from, required this.to, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getProductSalesReport(from: from, to: to),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Product Sales',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...items.map((e) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(
                                e['product_name'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13))),
                        Text('${e['total_quantity']} sold',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(
                            (e['total_revenue'] as double)
                                .toCurrency(),
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ─── Staff Report Sheet ───────────────────────────────────────────────────────
class _StaffReportSheet extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final WidgetRef ref;
  const _StaffReportSheet(
      {required this.from, required this.to, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getStaffSalesReport(from: from, to: to),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Staff Sales',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...items.map((e) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(
                                e['staff_name'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13))),
                        Text('${e['total_sales']} sales',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(
                            (e['total_revenue'] as double)
                                .toCurrency(),
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ─── Payment Report Sheet ─────────────────────────────────────────────────────
class _PaymentReportSheet extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final WidgetRef ref;
  const _PaymentReportSheet(
      {required this.from, required this.to, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getPaymentMethodReport(from: from, to: to),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Methods',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...items.map((e) => _ReportStat(
                    label: e['payment_method'] ?? '',
                    value:
                        '${e['count']} × ${(e['total'] as double).toCurrency()}',
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ─── Profit Report Sheet ──────────────────────────────────────────────────────
class _ProfitReportSheet extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final WidgetRef ref;
  const _ProfitReportSheet(
      {required this.from, required this.to, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getProfitReport(from: from, to: to),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator());
        }
        final data = snap.data ?? {};
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profit Report',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ReportStat(
                  label: 'Total Revenue',
                  value: (data['total_revenue'] as double? ?? 0)
                      .toCurrency()),
              _ReportStat(
                  label: 'Total Cost',
                  value: (data['total_cost'] as double? ?? 0)
                      .toCurrency()),
              _ReportStat(
                  label: 'Gross Profit',
                  value: (data['gross_profit'] as double? ?? 0)
                      .toCurrency(),
                  highlight: true),
              _ReportStat(
                  label: 'Margin',
                  value:
                      '${(data['margin_percent'] as double? ?? 0).toStringAsFixed(1)}%'),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ReportStat(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                color:
                    highlight ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: highlight ? 16 : 13,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
