import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/account.dart';
import '../account/account_settings_screen.dart';
import '../account/auth_screen.dart';
import '../alarms/permission_guide_screen.dart';

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
                    value:
                        profile?.displayName ?? profile?.email ?? l10n.active,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.open),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSectionLabel(l10n.alarmDefaults),
            const _DefaultAlarmSettingsGroup(),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSectionLabel(l10n.general),
            const _SettingsGroup(
              children: [
                _ThemeSettingsRow(),
                Divider(height: 1),
                _LanguageSettingsRow(),
                Divider(height: 1),
                _PermissionDiagnosticRow(),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSectionLabel(l10n.appInfo),
            _SettingsGroup(
              children: [
                _SettingsRow(title: l10n.appVersion, value: '1.0.0+1'),
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

class _ThemeSettingsRow extends ConsumerWidget {
  const _ThemeSettingsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.themeSetting,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getThemeName(themeMode, l10n),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: themeMode,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(12),
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                }
              },
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.themeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.themeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.themeDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }
}

class _PermissionDiagnosticRow extends ConsumerWidget {
  const _PermissionDiagnosticRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionStateProvider);
    final l10n = AppLocalizations.of(context);

    return permissionState.when(
      data: (allGranted) {
        final color = allGranted
            ? SereneWakeColors.primary
            : Theme.of(context).colorScheme.error;
        final text = allGranted
            ? l10n.permissionAllGranted
            : l10n.permissionNeedsAttention;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PermissionGuideScreen(isModal: true),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.permissionDiagnostic,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, st) => const SizedBox.shrink(),
    );
  }
}

class _DefaultAlarmSettingsGroup extends ConsumerWidget {
  const _DefaultAlarmSettingsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(defaultAlarmSettingsProvider);
    final notifier = ref.read(defaultAlarmSettingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return _SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.defaultSnooze,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: settings.snoozeMinutes,
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (val) {
                    if (val != null) notifier.setSnoozeMinutes(val);
                  },
                  items: [5, 10, 15, 20].map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text('$m${l10n.min}'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.defaultRing,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: settings.ringDurationMinutes,
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (val) {
                    if (val != null) notifier.setRingDurationMinutes(val);
                  },
                  items: [1, 3, 5, 10].map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text('$m${l10n.min}'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(
            l10n.defaultSound,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          value: settings.soundEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          activeTrackColor: Theme.of(context).colorScheme.primaryContainer,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          onChanged: notifier.setSoundEnabled,
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(
            l10n.defaultVibration,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          value: settings.vibrationEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          activeTrackColor: Theme.of(context).colorScheme.primaryContainer,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          onChanged: notifier.setVibrationEnabled,
        ),
      ],
    );
  }
}

class _LanguageSettingsRow extends ConsumerWidget {
  const _LanguageSettingsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.language,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentLocale == null
                      ? l10n.themeSystem
                      : (currentLocale.languageCode == 'ko'
                            ? '한국어'
                            : 'English'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentLocale?.languageCode ?? 'system',
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(12),
              onChanged: (String? val) {
                if (val == 'system') {
                  ref.read(localeProvider.notifier).setLocale(null);
                } else if (val != null) {
                  ref.read(localeProvider.notifier).setLocale(Locale(val));
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.themeSystem),
                ),
                const DropdownMenuItem(value: 'ko', child: Text('한국어')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
