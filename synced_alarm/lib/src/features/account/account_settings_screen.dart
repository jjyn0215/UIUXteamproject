import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/account.dart';
import 'group_setup_screen.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final activeGroup = ref.watch(activeGroupProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.accountSettings,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _ProfileCard(profile: profile, activeGroup: activeGroup),
              const SizedBox(height: AppSpacing.lg),
              _NicknameEditCard(initialNickname: profile?.displayName ?? ''),
              const SizedBox(height: AppSpacing.lg),
              const _SyncedDevicesGroup(),
              const SizedBox(height: AppSpacing.lg),
              _GroupManagementCard(activeGroup: activeGroup),
              const SizedBox(height: AppSpacing.lg),
              const _AccountActionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.activeGroup});

  final AppUserProfile? profile;
  final AlarmGroupSummary? activeGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.displayName ?? l10n.localAlarms,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile?.email ?? l10n.noAccountRequired,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NicknameEditCard extends ConsumerStatefulWidget {
  const _NicknameEditCard({required this.initialNickname});

  final String initialNickname;

  @override
  ConsumerState<_NicknameEditCard> createState() => _NicknameEditCardState();
}

class _NicknameEditCardState extends ConsumerState<_NicknameEditCard> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  bool _isChanged = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _NicknameEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNickname != oldWidget.initialNickname && !_isLoading) {
      _controller.text = widget.initialNickname;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final changed =
        _controller.text.trim() != widget.initialNickname.trim() &&
        _controller.text.trim().isNotEmpty;
    if (changed != _isChanged) {
      setState(() {
        _isChanged = changed;
      });
    }
  }

  Future<void> _saveNickname() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(accountRepositoryProvider).updateDisplayName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).nicknameUpdated)),
        );
        setState(() {
          _isChanged = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.changeNickname,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n.enterNickname,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        _isChanged ? _saveNickname() : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  onPressed: (_isChanged && !_isLoading) ? _saveNickname : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncedDevicesGroup extends ConsumerWidget {
  const _SyncedDevicesGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesVal = ref.watch(groupDevicesProvider);
    final l10n = AppLocalizations.of(context);

    return devicesVal.when(
      data: (devices) {
        if (devices.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                l10n.syncedDevices,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: Column(
                children: [
                  for (var i = 0; i < devices.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            devices[i].platform.toLowerCase() == 'android'
                                ? Icons.android_rounded
                                : (devices[i].platform.toLowerCase() == 'ios'
                                      ? Icons.phone_iphone_rounded
                                      : Icons.computer_rounded),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  devices[i].displayName,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.lastSynced}: ${_formatLastSeen(devices[i].lastSeenAt, l10n)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, st) => const SizedBox.shrink(),
    );
  }

  String _formatLastSeen(DateTime dt, AppLocalizations l10n) {
    final localDt = dt.toLocal();
    final hour = localDt.hour;
    final minute = localDt.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${localDt.month}/${localDt.day} $hour12:$minute $period';
  }
}

class _GroupManagementCard extends StatelessWidget {
  const _GroupManagementCard({required this.activeGroup});

  final AlarmGroupSummary? activeGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sharedGroup,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeGroup?.name ?? l10n.noGroup,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (activeGroup != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.groupId}: ${activeGroup!.groupId}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              l10n.groupMgmt,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              l10n.createJoinSwitch,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.outline,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GroupSetupScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountActionsCard extends ConsumerWidget {
  const _AccountActionsCard();

  Future<void> _onDeleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.deleteAccount,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountConfirm),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.deleteAccountWarning,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.deleteAccountSuccess)));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                l10n.deleteAccount,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Text(l10n.reauthRequired),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message ?? e.toString())));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.signOut,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.outline,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            onTap: () async {
              await ref.read(accountRepositoryProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              l10n.deleteAccount,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              Icons.delete_forever_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            onTap: () => _onDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}
