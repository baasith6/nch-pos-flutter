import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/staff_repository.dart';

final _addStaffLoadingProvider = StateProvider<bool>((ref) => false);

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_addStaffLoadingProvider.notifier).state = true;
    try {
      await ref.read(staffRepositoryProvider).createStaffUser(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff user created successfully'), backgroundColor: AppTheme.accent),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) ref.read(_addStaffLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_addStaffLoadingProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Staff'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Full Name', _nameCtrl, hint: 'John Doe'),
              _field('Email', _emailCtrl, hint: 'staff@shop.com', keyboard: TextInputType.emailAddress,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null),
              _field('Password', _passCtrl, hint: '••••••••', obscure: true,
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null),
              _field('Phone (optional)', _phoneCtrl, hint: '+94 77 123 4567', keyboard: TextInputType.phone, required: false),
              _field('Username (optional)', _usernameCtrl, hint: 'john_doe', required: false),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Staff user will be created via secure Edge Function. The password will be set immediately.',
                        style: TextStyle(color: AppTheme.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Staff User'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            obscureText: obscure,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(hintText: hint),
            validator: validator ?? (required ? (v) => v?.isEmpty == true ? 'Required' : null : null),
          ),
        ],
      ),
    );
  }
}
