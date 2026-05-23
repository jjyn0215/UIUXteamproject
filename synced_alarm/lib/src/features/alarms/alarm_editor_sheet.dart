import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/alarm.dart';

Future<void> showAlarmEditor(BuildContext context, {Alarm? alarm}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AlarmEditorSheet(alarm: alarm),
  );
}

class AlarmEditorSheet extends ConsumerStatefulWidget {
  const AlarmEditorSheet({super.key, this.alarm});

  final Alarm? alarm;

  @override
  ConsumerState<AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends ConsumerState<AlarmEditorSheet> {
  late final TextEditingController _labelController;
  late TimeOfDay _time;
  late Set<int> _repeatWeekdays;
  late int _ringDurationMinutes;
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  late int _snoozeMinutes;
  late int _maxSnoozeCount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _labelController = TextEditingController(text: alarm?.label ?? '');
    final now = DateTime.now();
    final oneMinuteLater = now.add(const Duration(minutes: 1));
    _time = alarm?.timeOfDay ?? TimeOfDay.fromDateTime(oneMinuteLater);
    _repeatWeekdays = {
      ...(alarm?.repeatWeekdays ?? defaultAlarmRepeatWeekdays),
    };
    final defaultSettings = ref.read(defaultAlarmSettingsProvider);
    _ringDurationMinutes =
        alarm?.ringDurationMinutes ?? defaultSettings.ringDurationMinutes;
    _soundEnabled = alarm?.soundEnabled ?? defaultSettings.soundEnabled;
    _vibrationEnabled = alarm?.vibrationEnabled ?? defaultSettings.vibrationEnabled;
    _snoozeMinutes = alarm?.snoozeMinutes ?? defaultSettings.snoozeMinutes;
    _maxSnoozeCount = alarm?.maxSnoozeCount ?? defaultAlarmMaxSnoozeCount;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.alarm == null ? l10n.newAlarm : l10n.editAlarm;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _TimeButton(time: _time, onPressed: _pickTime),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _labelController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.label,
                    hintText: l10n.wakeUp,
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(l10n.repeat),
                _WeekdaySelector(
                  selected: _repeatWeekdays,
                  onChanged: (weekdays) {
                    setState(() => _repeatWeekdays = weekdays);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(l10n.sound),
                _OptionDropdown(
                  label: l10n.ringDuration,
                  icon: Icons.timer_outlined,
                  value: _ringDurationMinutes,
                  options: const [1, 3, 5, 10, 15],
                  suffix: l10n.min,
                  onChanged: (value) {
                    setState(() => _ringDurationMinutes = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _SwitchSetting(
                  icon: Icons.volume_up_outlined,
                  title: l10n.sound,
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _SwitchSetting(
                  icon: Icons.vibration_rounded,
                  title: l10n.vibration,
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() => _vibrationEnabled = value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(l10n.snooze),
                _OptionDropdown(
                  label: l10n.snoozeAfter,
                  icon: Icons.snooze_rounded,
                  value: _snoozeMinutes,
                  options: const [5, 10, 15, 30],
                  suffix: l10n.min,
                  onChanged: (value) {
                    setState(() => _snoozeMinutes = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _OptionDropdown(
                  label: l10n.maxSnoozes,
                  icon: Icons.repeat_rounded,
                  value: _maxSnoozeCount,
                  options: const [0, 1, 2, 3, 5],
                  suffix: l10n.times,
                  onChanged: (value) {
                    setState(() => _maxSnoozeCount = value);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      widget.alarm == null ? l10n.setAlarm : l10n.saveAlarm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Set<int> _safeRepeatWeekdays() {
    if (_repeatWeekdays.isEmpty) return defaultAlarmRepeatWeekdays;
    return Set.unmodifiable(_repeatWeekdays);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: SereneWakeColors.primary,
              secondary: SereneWakeColors.accent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = ref.read(alarmListControllerProvider);
    final l10n = AppLocalizations.of(context);
    final minutes = _time.hour * 60 + _time.minute;
    final trimmedLabel = _labelController.text.trim();
    final label = trimmedLabel.isEmpty ? l10n.alarm : trimmedLabel;

    try {
      final alarm = widget.alarm;
      if (alarm == null) {
        await controller.createAlarm(
          label: label,
          timeOfDayMinutes: minutes,
          repeatWeekdays: _safeRepeatWeekdays(),
          ringDurationMinutes: _ringDurationMinutes,
          soundEnabled: _soundEnabled,
          vibrationEnabled: _vibrationEnabled,
          snoozeMinutes: _snoozeMinutes,
          maxSnoozeCount: _maxSnoozeCount,
        );
      } else {
        await controller.updateAlarm(
          alarm.copyWith(
            label: label,
            timeOfDayMinutes: minutes,
            enabled: true,
            clearSnooze: true,
            repeatWeekdays: _safeRepeatWeekdays(),
            ringDurationMinutes: _ringDurationMinutes,
            soundEnabled: _soundEnabled,
            vibrationEnabled: _vibrationEnabled,
            snoozeMinutes: _snoozeMinutes,
            maxSnoozeCount: _maxSnoozeCount,
            updatedBy: defaultDeviceId,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorCouldNotSaveAlarm}: $error')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = [
      (DateTime.monday, l10n.mon),
      (DateTime.tuesday, l10n.tue),
      (DateTime.wednesday, l10n.wed),
      (DateTime.thursday, l10n.thu),
      (DateTime.friday, l10n.fri),
      (DateTime.saturday, l10n.sat),
      (DateTime.sunday, l10n.sun),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final day in days)
          FilterChip(
            label: Text(day.$2),
            selected: selected.contains(day.$1),
            onSelected: (enabled) {
              final next = {...selected};
              if (enabled) {
                next.add(day.$1);
              } else {
                next.remove(day.$1);
              }
              onChanged(next.isEmpty ? defaultAlarmRepeatWeekdays : next);
            },
          ),
      ],
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int value;
  final List<int> options;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: options.contains(value) ? value : options.first,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text('$option $suffix')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onPressed});

  final TimeOfDay time;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$hour:$minute',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                period,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
