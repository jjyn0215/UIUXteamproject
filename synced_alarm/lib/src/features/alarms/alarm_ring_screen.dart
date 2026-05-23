import 'dart:async';
import 'package:flutter/material.dart';

import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/alarm.dart';
import '../../platform/alarm_task_controller.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({
    super.key,
    required this.alarm,
    required this.onDismiss,
    required this.onSnooze,
  });

  final Alarm alarm;
  final Future<void> Function() onDismiss;
  final Future<void> Function() onSnooze;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  bool _busy = false;
  Timer? _autoSnoozeTimer;

  bool get _canSnooze {
    return widget.alarm.maxSnoozeCount > 0 &&
        widget.alarm.snoozeCount < widget.alarm.maxSnoozeCount;
  }

  @override
  void initState() {
    super.initState();
    _startAlarmVibration();
    _startAutoSnoozeTimer();
  }

  @override
  void didUpdateWidget(covariant AlarmRingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarm.id != widget.alarm.id ||
        oldWidget.alarm.vibrationEnabled != widget.alarm.vibrationEnabled ||
        oldWidget.alarm.ringDurationMinutes !=
            widget.alarm.ringDurationMinutes) {
      unawaited(AlarmTaskController.stopAlarmVibration());
      _autoSnoozeTimer?.cancel();
      _startAlarmVibration();
      _startAutoSnoozeTimer();
    }
  }

  void _startAlarmVibration() {
    unawaited(
      AlarmTaskController.startAlarmVibration(
        vibrationEnabled: widget.alarm.vibrationEnabled,
        duration: Duration(minutes: widget.alarm.ringDurationMinutes),
      ),
    );
  }

  void _startAutoSnoozeTimer() {
    final duration = Duration(minutes: widget.alarm.ringDurationMinutes);
    _autoSnoozeTimer = Timer(duration, () {
      if (mounted && !_busy) {
        _run(_canSnooze ? widget.onSnooze : widget.onDismiss);
      }
    });
  }

  @override
  void dispose() {
    _autoSnoozeTimer?.cancel();
    unawaited(AlarmTaskController.stopAlarmVibration());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: SereneWakeColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withAlpha(55)),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.alarm.timeLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.alarm.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withAlpha(220),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (_canSnooze) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _run(widget.onSnooze),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(170)),
                          minimumSize: const Size.fromHeight(58),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.snooze_rounded),
                        label: Text(l10n.snooze),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _run(widget.onDismiss),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: SereneWakeColors.primary,
                        minimumSize: const Size.fromHeight(58),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.dismiss),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    _autoSnoozeTimer?.cancel();
    await AlarmTaskController.stopAlarmVibration();
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }
}
