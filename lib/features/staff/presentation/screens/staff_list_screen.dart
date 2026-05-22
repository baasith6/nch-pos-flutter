import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../features/auth/data/models/profile_model.dart';
import '../../data/repositories/staff_repository.dart';

final _staffListProvider = FutureProvider<List<ProfileModel>>((ref) {
  return ref.read(staffRepositoryProvider).getAllStaff();
});

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addStaff).then((_) => ref.invalidate(_staffListProvider)),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Staff'),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
        data: (staff) => staff.isEmpty
            ? const Center(child: Text('No staff yet', style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: staff.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = staff[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderDark, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.fullName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(s.role, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Toggle active/inactive
                        Switch(
                          value: s.isActive,
                          activeColor: AppTheme.accent,
                          onChanged: (v) async {
                            await ref.read(staffRepositoryProvider).updateStatus(
                              staffId: s.id,
                              status: v ? 'Active' : 'Inactive',
                            );
                            ref.invalidate(_staffListProvider);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
