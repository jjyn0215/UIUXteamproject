import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/account.dart';
import '../account/auth_screen.dart';
import '../account/group_setup_screen.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: SereneWakeColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SettingsPanel(showHandle: true, showTitle: true),
    );
  }
}

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({
    super.key,
    this.showHandle = false,
    this.showTitle = false,
  });

  final bool showHandle;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final activeGroup = ref.watch(activeGroupProvider);
    final signedIn = ref.watch(authStateProvider).value != null;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (showTitle) ...[
              Text(
                l10n.settings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _ProfileHeader(profile: profile, activeGroup: activeGroup),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSectionLabel(l10n.syncAccount),
            _SettingsGroup(
              children: [
                if (!useFirebase)
                  _SettingsRow(
                    title: l10n.account,
                    value: l10n.localOnly,
                    detail: l10n.firebaseModeDisabled,
                  )
                else if (!signedIn)
                  _SettingsRow(
                    title: l10n.account,
                    value: l10n.localMode,
                    detail: l10n.signInToSync,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AuthScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.signIn),
                    ),
                  )
                else
                  _SettingsRow(
                    title: l10n.account,
                    value: profile?.email ?? l10n.active,
                    trailing: TextButton(
                      onPressed: () {
                        ref.read(accountRepositoryProvider).signOut();
                      },
                      child: Text(l10n.signOut),
                    ),
                  ),
                if (useFirebase && signedIn) ...[
                  const Divider(height: 1),
                  _SettingsRow(
                    title: l10n.sharedGroup,
                    value: activeGroup?.name ?? l10n.noGroup,
                    detail: activeGroup == null
                        ? l10n.needGroupToSync
                        : '${l10n.groupId}: ${activeGroup.groupId}',
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    title: l10n.groupMgmt,
                    value: l10n.createJoinSwitch,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GroupSetupScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.open),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.activeGroup});

  final AppUserProfile? profile;
  final AlarmGroupSummary? activeGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.alarm_rounded,
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
                activeGroup?.name ?? profile?.displayName ?? l10n.localAlarms,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile?.email ??
                    activeGroup?.groupId ??
                    l10n.noAccountRequired,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.value,
    this.detail,
    this.trailing,
  });

  final String title;
  final String value;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final detailText = detail;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: detailText == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                if (detailText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Align(
              alignment: detailText == null
                  ? Alignment.center
                  : Alignment.topCenter,
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
