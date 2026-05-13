import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _labelController = TextEditingController(text: alarm?.label ?? 'Wake up');
    _time = alarm?.timeOfDay ?? TimeOfDay.now();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.alarm == null ? 'New alarm' : 'Edit alarm';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: SereneWakeColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SereneWakeColors.text,
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
              decoration: const InputDecoration(
                labelText: 'Label',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              onSubmitted: (_) => _save(),
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
                label: Text(widget.alarm == null ? 'Set alarm' : 'Save alarm'),
              ),
            ),
          ],
        ),
      ),
    );
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
    final minutes = _time.hour * 60 + _time.minute;
    final label = _labelController.text.trim();

    try {
      final alarm = widget.alarm;
      if (alarm == null) {
        await controller.createAlarm(label: label, timeOfDayMinutes: minutes);
      } else {
        await controller.updateAlarm(
          alarm.copyWith(
            label: label,
            timeOfDayMinutes: minutes,
            enabled: true,
            clearSnooze: true,
            updatedBy: defaultDeviceId,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save alarm: $error')));
    }
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
      color: SereneWakeColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: SereneWakeColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$hour:$minute',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: SereneWakeColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                period,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SereneWakeColors.primary,
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
