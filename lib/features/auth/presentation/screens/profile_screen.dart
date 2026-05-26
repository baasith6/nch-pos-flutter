import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Profile Header ---
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName ?? 'Admin',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile?.role == 'Admin' ? 'System Administrator' : (profile?.role ?? 'User'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile?.status ?? 'Active',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last login: Today, ${DateFormat('h:mm a').format(DateTime.now())}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- Account Information ---
                const Text(
                  'Account Information',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline,
                      label: 'Username',
                      value: profile?.username?.isNotEmpty == true ? profile!.username : 'Not added',
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: Supabase.instance.client.auth.currentUser?.email ?? 'Not added',
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: profile?.phone?.isNotEmpty == true ? profile!.phone : 'Not added',
                    ),
                    const _SettingsDivider(),
                    const _SettingsRow(
                      icon: Icons.storefront_outlined,
                      label: 'Store / Branch',
                      value: 'Main Branch',
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // --- Security ---
                const Text(
                  'Security',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change Password',
                      isEditable: true,
                      onTap: () => context.push(AppRoutes.changePassword),
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.pin_outlined,
                      label: 'App Lock / PIN',
                      isEditable: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App Lock feature coming soon.')),
                        );
                      },
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.timer_outlined,
                      label: 'Session Timeout',
                      value: '30 mins',
                      isEditable: true,
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session timeout settings coming soon.')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- Danger Zone ---
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showSignOutDialog(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isEditable;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.isEditable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textHint, size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                if (isEditable) ...[
                  if (value != null) const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint, size: 20),
                ]
              ],
            ),
          ),
        ],
      ),
    );

    if (isEditable || onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: AppTheme.border, indent: 52);
  }
}
