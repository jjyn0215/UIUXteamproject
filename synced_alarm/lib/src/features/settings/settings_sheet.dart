import 'package:flutter/material.dart';

import '../../data/app_providers.dart';
import '../../design/app_theme.dart';

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

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    this.showHandle = false,
    this.showTitle = false,
  });

  final bool showHandle;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
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
                    color: SereneWakeColors.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (showTitle) ...[
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: SereneWakeColors.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const _ProfileHeader(),
            const SizedBox(height: AppSpacing.lg),
            const _SettingsSectionLabel('SYNC & ACCOUNT'),
            _SettingsCard(
              icon: Icons.cloud_sync_outlined,
              title: 'Cloud Synchronization',
              value: useFirebase ? 'Active' : 'Local demo',
              detail: useFirebase
                  ? 'Auth, Firestore, Functions, and FCM are active.'
                  : 'Enable Firebase with dart-define after FlutterFire setup.',
              trailing: Switch(value: useFirebase, onChanged: null),
            ),
            _SettingsCard(
              icon: Icons.devices_other_rounded,
              title: 'Shared group',
              value: defaultGroupId,
              detail: 'Access code comes from dart-define or demo defaults.',
            ),
            const _SettingsSectionLabel('ALARM DEFAULTS'),
            const _SettingsCard(
              icon: Icons.snooze_rounded,
              title: 'Snooze Duration',
              value: '5 mins',
              detail: 'Used when a ringing alarm is snoozed.',
            ),
            const _SettingsCard(
              icon: Icons.notifications_active_outlined,
              title: 'Notification scope',
              value: 'Android / Web FCM',
              detail: 'Windows and Linux sync through Firestore while running.',
            ),
            const _SettingsSectionLabel('APPEARANCE'),
            const _SettingsCard(
              icon: Icons.palette_outlined,
              title: 'Design reference',
              value: 'Stitch Alarm App',
              detail: 'Project 15792280768664650353 provides the UI baseline.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: SereneWakeColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.alarm_rounded,
            color: SereneWakeColors.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Demo Group',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: SereneWakeColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        Text(
          'demo@synced-alarm.app',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SereneWakeColors.mutedText),
        ),
      ],
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
          color: SereneWakeColors.mutedText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SereneWakeColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: SereneWakeColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: SereneWakeColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SereneWakeColors.text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SereneWakeColors.mutedText,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
