import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../models/alarm.dart';

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

  @override
  Widget build(BuildContext context) {
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
                      label: const Text('Snooze'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _run(widget.onDismiss),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: SereneWakeColors.primary,
                        minimumSize: const Size.fromHeight(58),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Dismiss'),
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
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }
}
