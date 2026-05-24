import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../app/router.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/payment_method_repository.dart';

final _settingsProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.read(settingsRepositoryProvider).getSettings();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _newMethodCtrl = TextEditingController();
  bool _taxEnabled = false;
  final _taxPctCtrl = TextEditingController(text: '0');
  bool _isSaving = false;
  bool _initialized = false;

  void _initFrom(Map<String, dynamic>? data) {
    if (_initialized || data == null) return;
    _initialized = true;
    _shopNameCtrl.text = data['shop_name'] ?? '';
    _addressCtrl.text = data['address'] ?? '';
    _phoneCtrl.text = data['phone'] ?? '';
    _emailCtrl.text = data['email'] ?? '';
    _footerCtrl.text = data['receipt_footer'] ?? '';
    _taxEnabled = data['tax_enabled'] as bool? ?? false;
    _taxPctCtrl.text = '${data['tax_percentage'] ?? 0}';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateSettings({
        'shop_name': _shopNameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'receipt_footer': _footerCtrl.text.trim(),
        'tax_enabled': _taxEnabled,
        'tax_percentage': double.tryParse(_taxPctCtrl.text) ?? 0,
      });
      ref.invalidate(_settingsProvider);
      ref.invalidate(shopSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppTheme.accent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addPaymentMethod() async {
    final name = _newMethodCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(paymentMethodRepositoryProvider).addPaymentMethod(name);
      _newMethodCtrl.clear();
      ref.invalidate(paymentMethodsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"$name" added'),
            backgroundColor: AppTheme.accent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _toggleMethod(String name, String currentStatus) async {
    final newStatus =
        currentStatus == 'Active' ? 'Inactive' : 'Active';
    await ref
        .read(paymentMethodRepositoryProvider)
        .setStatus(name, newStatus);
    ref.invalidate(paymentMethodsProvider);
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _footerCtrl.dispose();
    _taxPctCtrl.dispose();
    _newMethodCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_settingsProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final profile = ref.read(currentProfileProvider).value;
              if (profile?.isAdmin == true) {
                context.go(AppRoutes.adminDashboard);
              } else {
                context.go(AppRoutes.staffDashboard);
              }
            }
          },
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          _initFrom(data);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Shop Information'),
                _field('Shop Name', _shopNameCtrl, hint: 'My Shop'),
                _field('Address', _addressCtrl, hint: '123 Main St'),
                _field('Phone', _phoneCtrl,
                    hint: '+94 11 234 5678',
                    keyboard: TextInputType.phone),
                _field('Email', _emailCtrl,
                    hint: 'shop@example.com',
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 8),

                _section('Receipt'),
                _field('Receipt Footer', _footerCtrl,
                    hint: 'Thank you for shopping!', maxLines: 3),
                const SizedBox(height: 8),

                _section('Tax'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enable Tax',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14)),
                    Switch(
                      value: _taxEnabled,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (v) =>
                          setState(() => _taxEnabled = v),
                    ),
                  ],
                ),
                if (_taxEnabled) ...[
                  const SizedBox(height: 8),
                  _field('Tax Percentage (%)', _taxPctCtrl,
                      hint: '0', keyboard: TextInputType.number),
                ],
                const SizedBox(height: 8),

                _section('Payment Methods'),
                paymentMethodsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (methods) => FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getAllMethods(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final all = snap.data!;
                      return Column(
                        children: [
                          ...all.map((m) {
                            final name = m['name'] as String;
                            final status = m['status'] as String;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14)),
                              trailing: Switch(
                                value: status == 'Active',
                                activeThumbColor: AppTheme.accent,
                                onChanged: (_) =>
                                    _toggleMethod(name, status),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newMethodCtrl,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary),
                                  decoration: const InputDecoration(
                                    hintText: 'New payment method…',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addPaymentMethod,
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 40)),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Settings'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllMethods() async {
    final data = await ref
        .read(paymentMethodRepositoryProvider)
        .getAllPaymentMethodsWithStatus();
    return data;
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 8),
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

  Widget _field(String label, TextEditingController ctrl,
      {String hint = '',
      TextInputType keyboard = TextInputType.text,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLines: maxLines,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
