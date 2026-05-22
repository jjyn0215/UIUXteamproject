import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/alarm.dart';
import '../../platform/alarm_task_controller.dart';
import '../../platform/alarm_notification_service.dart';
import '../settings/settings_sheet.dart';
import 'alarm_due_tick_tracker.dart';
import 'alarm_editor_sheet.dart';
import 'alarm_ring_screen.dart';

class AlarmHomeScreen extends ConsumerStatefulWidget {
  const AlarmHomeScreen({super.key});

  @override
  ConsumerState<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends ConsumerState<AlarmHomeScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  ProviderSubscription<AsyncValue<List<Alarm>>>? _alarmScheduleSubscription;
  StreamSubscription<AlarmNotificationLaunch>? _alarmLaunchSubscription;
  StreamSubscription<AlarmNotificationActionRequest>? _alarmActionSubscription;
  final AlarmDueTickTracker _dueTickTracker = AlarmDueTickTracker();
  final Map<int, _ForegroundAlarmTimerEntry> _foregroundAlarmTimers = {};
  AlarmNotificationLaunch? _pendingAlarmLaunch;
  AlarmNotificationActionRequest? _pendingAlarmAction;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alarmScheduleSubscription = ref.listenManual<AsyncValue<List<Alarm>>>(
      alarmsProvider,
      (_, next) {
        final alarms = next.value;
        if (alarms != null) {
          unawaited(_handlePendingAlarmAction(alarms));
          unawaited(_handlePendingAlarmLaunch(alarms));
          _syncForegroundAlarmTimers(alarms);
          if (ref.read(ringingAlarmProvider) == null) {
            unawaited(
              ref.read(alarmListControllerProvider).syncScheduledAlarms(alarms),
            );
          }
        }
      },
      fireImmediately: true,
    );
    _alarmLaunchSubscription = AlarmNotificationService.instance.alarmLaunches
        .listen((launch) {
          unawaited(_handleAlarmLaunch(launch));
        });
    _alarmActionSubscription = AlarmNotificationService.instance.alarmActions
        .listen((action) {
          unawaited(_handleAlarmAction(action));
        });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        if (_selectedTab == 0) {
          setState(() {});
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handlePendingAlarmAction());
      unawaited(_handlePendingAlarmLaunch());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmScheduleSubscription?.close();
    unawaited(_alarmLaunchSubscription?.cancel());
    unawaited(_alarmActionSubscription?.cancel());
    _timer?.cancel();
    _cancelForegroundAlarmTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    final alarms = ref.read(alarmsProvider).value;
    if (_isForegroundVisible && alarms != null) {
      _syncForegroundAlarmTimers(alarms);
    } else if (!_isForegroundVisible) {
      _cancelForegroundAlarmTimers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmsProvider);
    final ringingAlarm = ref.watch(ringingAlarmProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final l10n = AppLocalizations.of(context);
    if (ringingAlarm != null) {
      return AlarmRingScreen(
        alarm: ringingAlarm,
        onDismiss: () {
          return _runAlarmScreenAction(ringingAlarm, () {
            return ref
                .read(alarmListControllerProvider)
                .dismiss(ringingAlarm, clearRingingAlarm: false);
          });
        },
        onSnooze: () {
          return _runAlarmScreenAction(ringingAlarm, () {
            return ref
                .read(alarmListControllerProvider)
                .snooze(ringingAlarm, clearRingingAlarm: false);
          });
        },
      );
    }

    final title = switch (_selectedTab) {
      0 => l10n.alarms,
      1 => l10n.history,
      _ => l10n.settings,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          _SyncStatusButton(
            status: syncStatus,
            onPressed: () => setState(() => _selectedTab = 2),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            switch (_selectedTab) {
              0 => alarms.when(
                data: (items) => _AlarmListView(
                  alarms: items,
                  now: DateTime.now(),
                  onCreate: () => showAlarmEditor(context),
                  onEdit: (alarm) => showAlarmEditor(context, alarm: alarm),
                  onToggle: (alarm, enabled) {
                    return ref
                        .read(alarmListControllerProvider)
                        .toggleAlarm(alarm, enabled);
                  },
                  onDelete: (alarm) {
                    return ref
                        .read(alarmListControllerProvider)
                        .deleteAlarm(alarm);
                  },
                  onTestRing: (alarm) {
                    return ref.read(alarmListControllerProvider).ring(alarm);
                  },
                ),
                error: (error, _) => _ErrorPanel(
                  error: error,
                  onRetry: () => ref.invalidate(alarmsProvider),
                ),
                loading: () => const _LoadingPanel(),
              ),
              1 => const _HistoryPanel(),
              _ => const SettingsPanel(),
            },
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              tooltip: l10n.newAlarm,
              onPressed: () => showAlarmEditor(context),
              backgroundColor: SereneWakeColors.primary,
              foregroundColor: SereneWakeColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.alarm_outlined),
            selectedIcon: const Icon(Icons.alarm_rounded),
            label: l10n.alarms,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  bool get _isForegroundVisible {
    return _lifecycleState == AppLifecycleState.resumed ||
        _lifecycleState == AppLifecycleState.inactive;
  }

  Future<void> _handleAlarmLaunch(AlarmNotificationLaunch launch) async {
    final pendingLaunch =
        AlarmNotificationService.instance.consumePendingAlarmLaunch() ?? launch;
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null || !(await _showLaunchedAlarm(pendingLaunch, alarms))) {
      _pendingAlarmLaunch = pendingLaunch;
    }
  }

  Future<void> _handleAlarmAction(AlarmNotificationActionRequest action) async {
    final pendingAction =
        AlarmNotificationService.instance.consumePendingAlarmAction() ?? action;
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null ||
        !(await _runAlarmNotificationAction(pendingAction, alarms))) {
      _pendingAlarmAction = pendingAction;
    }
  }

  Future<void> _handlePendingAlarmLaunch([List<Alarm>? alarms]) async {
    final initialLaunch = AlarmNotificationService.instance
        .consumePendingAlarmLaunch();
    if (initialLaunch != null) {
      _pendingAlarmLaunch = initialLaunch;
    }

    final pendingLaunch = _pendingAlarmLaunch;
    if (pendingLaunch == null) return;
    final availableAlarms = alarms ?? ref.read(alarmsProvider).value;
    if (availableAlarms == null) return;
    await _showLaunchedAlarm(pendingLaunch, availableAlarms);
  }

  Future<void> _handlePendingAlarmAction([List<Alarm>? alarms]) async {
    final initialAction = AlarmNotificationService.instance
        .consumePendingAlarmAction();
    if (initialAction != null) {
      _pendingAlarmAction = initialAction;
    }

    final pendingAction = _pendingAlarmAction;
    if (pendingAction == null) return;
    final availableAlarms = alarms ?? ref.read(alarmsProvider).value;
    if (availableAlarms == null) return;
    await _runAlarmNotificationAction(pendingAction, availableAlarms);
  }

  Future<bool> _runAlarmNotificationAction(
    AlarmNotificationActionRequest action,
    List<Alarm> alarms,
  ) async {
    final alarm = _findAlarmById(alarms, action.alarmId);
    if (alarm == null) return false;

    _pendingAlarmAction = null;
    await _dueTickTracker.markHandled(alarm, DateTime.now());
    final controller = ref.read(alarmListControllerProvider);
    switch (action.type) {
      case AlarmNotificationActionType.dismiss:
        unawaited(controller.dismiss(alarm));
      case AlarmNotificationActionType.snooze:
        unawaited(controller.snooze(alarm));
    }
    return true;
  }

  Future<bool> _showLaunchedAlarm(
    AlarmNotificationLaunch launch,
    List<Alarm> alarms,
  ) async {
    final alarm = _findAlarmById(alarms, launch.alarmId);
    if (alarm == null || !alarm.enabled) return false;
    final ringingAlarm = ref.read(ringingAlarmProvider);
    if (ringingAlarm?.id == alarm.id) {
      _pendingAlarmLaunch = null;
      return true;
    }
    final now = DateTime.now();
    final shouldValidateDueTick =
        launch.source != AlarmNotificationLaunchSource.notification;
    if (shouldValidateDueTick &&
        !(await _dueTickTracker.shouldRing(alarm, now))) {
      return false;
    }
    if (!shouldValidateDueTick) {
      await _dueTickTracker.markHandled(alarm, now);
    }
    _pendingAlarmLaunch = null;
    unawaited(
      AlarmNotificationService.instance.scheduleForegroundTriggersForAlarm(
        alarm,
      ),
    );
    ref.read(ringingAlarmProvider.notifier).show(alarm);
    if (mounted && _selectedTab != 0) {
      setState(() => _selectedTab = 0);
    }
    return true;
  }

  void _syncForegroundAlarmTimers(List<Alarm> alarms) {
    if (!_isForegroundVisible) {
      _cancelForegroundAlarmTimers();
      return;
    }

    final now = DateTime.now();
    final plans = <int, _ForegroundAlarmTimerPlan>{};
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      for (final request in AlarmNotificationRequest.scheduledRequestsFromAlarm(
        alarm,
        from: now,
      )) {
        if (!request.scheduledAt.isAfter(now)) continue;
        plans[request.id] = _ForegroundAlarmTimerPlan(
          id: request.id,
          alarmId: alarm.id,
          scheduledAt: request.scheduledAt,
        );
      }
    }

    for (final id in _foregroundAlarmTimers.keys.toList()) {
      final plan = plans[id];
      final entry = _foregroundAlarmTimers[id];
      if (plan == null ||
          entry == null ||
          entry.scheduledAt != plan.scheduledAt) {
        entry?.timer.cancel();
        _foregroundAlarmTimers.remove(id);
      }
    }

    for (final plan in plans.values) {
      if (_foregroundAlarmTimers.containsKey(plan.id)) continue;
      final delay = plan.scheduledAt.difference(DateTime.now());
      final timer = Timer(delay.isNegative ? Duration.zero : delay, () {
        unawaited(_handleForegroundAlarmTimer(plan));
      });
      _foregroundAlarmTimers[plan.id] = _ForegroundAlarmTimerEntry(
        alarmId: plan.alarmId,
        scheduledAt: plan.scheduledAt,
        timer: timer,
      );
    }
  }

  Future<void> _handleForegroundAlarmTimer(
    _ForegroundAlarmTimerPlan plan,
  ) async {
    _foregroundAlarmTimers.remove(plan.id)?.timer.cancel();
    if (!mounted || !_isForegroundVisible) return;
    final launch = AlarmNotificationLaunch(
      alarmId: plan.alarmId,
      source: AlarmNotificationLaunchSource.foregroundTimer,
    );
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null || !(await _showLaunchedAlarm(launch, alarms))) {
      _pendingAlarmLaunch = launch;
      return;
    }
    _syncForegroundAlarmTimers(alarms);
  }

  void _cancelForegroundAlarmTimers() {
    for (final entry in _foregroundAlarmTimers.values) {
      entry.timer.cancel();
    }
    _foregroundAlarmTimers.clear();
  }

  Alarm? _findAlarmById(List<Alarm> alarms, String alarmId) {
    for (final alarm in alarms) {
      if (alarm.id == alarmId) return alarm;
    }
    return null;
  }

  Future<void> _runAlarmScreenAction(
    Alarm alarm,
    Future<void> Function() action,
  ) async {
    try {
      await _dueTickTracker.markHandled(alarm, DateTime.now());
      await action();
    } finally {
      final finished = await AlarmTaskController.finishAlarmPresentation();
      if (!finished) {
        ref.read(ringingAlarmProvider.notifier).clear();
      }
    }
  }
}

class _ForegroundAlarmTimerPlan {
  const _ForegroundAlarmTimerPlan({
    required this.id,
    required this.alarmId,
    required this.scheduledAt,
  });

  final int id;
  final String alarmId;
  final DateTime scheduledAt;
}

class _ForegroundAlarmTimerEntry {
  const _ForegroundAlarmTimerEntry({
    required this.alarmId,
    required this.scheduledAt,
    required this.timer,
  });

  final String alarmId;
  final DateTime scheduledAt;
  final Timer timer;
}

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton({required this.status, required this.onPressed});

  final SyncStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (status.type == SyncStatusType.syncing) {
      return IconButton(
        tooltip: status.label,
        onPressed: onPressed,
        icon: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return IconButton(
      tooltip: _tooltip,
      icon: Icon(_icon),
      color: _color(context),
      onPressed: onPressed,
    );
  }

  String get _tooltip {
    final detail = status.detail;
    if (detail == null || detail.isEmpty) return status.label;
    return '${status.label}: $detail';
  }

  IconData get _icon {
    return switch (status.type) {
      SyncStatusType.local => Icons.sync_disabled_rounded,
      SyncStatusType.needsGroup => Icons.sync_problem_rounded,
      SyncStatusType.syncing => Icons.sync_rounded,
      SyncStatusType.active => Icons.cloud_done_rounded,
      SyncStatusType.error => Icons.error_outline_rounded,
    };
  }

  Color _color(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status.type) {
      SyncStatusType.local => colorScheme.outline,
      SyncStatusType.needsGroup => Colors.orange.shade700,
      SyncStatusType.syncing => colorScheme.primary,
      SyncStatusType.active => colorScheme.primary,
      SyncStatusType.error => colorScheme.error,
    };
  }
}

class _AlarmListView extends StatelessWidget {
  const _AlarmListView({
    required this.alarms,
    required this.now,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onTestRing,
  });

  final List<Alarm> alarms;
  final DateTime now;
  final VoidCallback onCreate;
  final ValueChanged<Alarm> onEdit;
  final Future<void> Function(Alarm alarm, bool enabled) onToggle;
  final Future<void> Function(Alarm alarm) onDelete;
  final Future<void> Function(Alarm alarm) onTestRing;

  @override
  Widget build(BuildContext context) {
    final sortedAlarms = [...alarms]
      ..sort((a, b) => a.timeOfDayMinutes.compareTo(b.timeOfDayMinutes));
    final nextAlarm = _nextAlarm(sortedAlarms, now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 560.0);
        return Center(
          child: SizedBox(
            width: maxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                120,
              ),
              children: [
                if (nextAlarm != null) ...[
                  _NextAlarmCard(alarm: nextAlarm, now: now),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (sortedAlarms.isEmpty)
                  _EmptyAlarmPanel(onCreate: onCreate)
                else
                  for (final alarm in sortedAlarms) ...[
                    _AlarmCard(
                      alarm: alarm,
                      now: now,
                      onEdit: () => onEdit(alarm),
                      onToggle: (enabled) => onToggle(alarm, enabled),
                      onDelete: () => onDelete(alarm),
                      onTestRing: () => onTestRing(alarm),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Alarm? _nextAlarm(List<Alarm> alarms, DateTime now) {
    final enabledAlarms = alarms.where((alarm) => alarm.enabled).toList();
    if (enabledAlarms.isEmpty) return null;
    enabledAlarms.sort(
      (a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)),
    );
    return enabledAlarms.first;
  }
}

class _NextAlarmCard extends StatelessWidget {
  const _NextAlarmCard({required this.alarm, required this.now});

  final Alarm alarm;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = alarm.nextOccurrence(now);
    final duration = next.difference(now);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).abs();
    final remaining = hours <= 0
        ? '$minutes min'
        : '${hours}h ${minutes.toString().padLeft(2, '0')}m';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SereneWakeColors.primarySoft.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SereneWakeColors.primarySoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nextAlarm,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            alarm.timeLabel,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  alarm.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              Text(
                l10n.startsIn(remaining),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlarmCard extends ConsumerStatefulWidget {
  const _AlarmCard({
    required this.alarm,
    required this.now,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onTestRing,
  });

  final Alarm alarm;
  final DateTime now;
  final VoidCallback onEdit;
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function() onDelete;
  final Future<void> Function() onTestRing;

  @override
  ConsumerState<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends ConsumerState<_AlarmCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alarm = widget.alarm;
    final subtitle = alarm.enabled
        ? _formatNext(alarm.nextOccurrence(widget.now), widget.now, l10n)
        : l10n.off;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alarm.timeLabel,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: alarm.enabled
                                    ? Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color
                                    : Theme.of(context).colorScheme.outline,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          alarm.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: alarm.enabled,
                    onChanged: _busy
                        ? null
                        : (enabled) async {
                            setState(() => _busy = true);
                            try {
                              await widget.onToggle(enabled);
                            } catch (error) {
                              _showActionError(error);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                  ),
                  PopupMenuButton<_AlarmAction>(
                    tooltip: l10n.alarmActions,
                    onSelected: (action) async {
                      try {
                        switch (action) {
                          case _AlarmAction.edit:
                            widget.onEdit();
                            return;
                          case _AlarmAction.test:
                            await widget.onTestRing();
                            return;
                          case _AlarmAction.delete:
                            await _confirmDelete(context, l10n);
                            return;
                        }
                      } catch (error) {
                        _showActionError(error);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _AlarmAction.edit,
                        child: Text(l10n.editAlarm),
                      ),
                      PopupMenuItem(
                        value: _AlarmAction.test,
                        child: Text(l10n.testRing),
                      ),
                      PopupMenuItem(
                        value: _AlarmAction.delete,
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DayChips(alarm: alarm),
              if (alarm.enabled &&
                  alarm.snoozeUntil != null &&
                  alarm.snoozeUntil!.isAfter(widget.now)) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SereneWakeColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: SereneWakeColors.primary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.snooze_rounded,
                            size: 14,
                            color: SereneWakeColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.snoozingStatus(
                              alarm.snoozeCount,
                              alarm.maxSnoozeCount,
                              _formatSnoozeTime(alarm.snoozeUntil!),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: SereneWakeColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await ref
                                    .read(alarmListControllerProvider)
                                    .dismiss(alarm);
                              } catch (error) {
                                _showActionError(error);
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      icon: const Icon(Icons.alarm_off_rounded, size: 16),
                      label: Text(l10n.dismissSnooze),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatSnoozeTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(widget.alarm.timeLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDelete();
    }
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.errorAlarmActionFailed}: $error')),
    );
  }

  String _formatNext(DateTime next, DateTime now, AppLocalizations l10n) {
    final duration = next.difference(now);
    if (duration.inMinutes < 1) return l10n.ringsNow;
    if (duration.inHours < 1) return l10n.ringsIn('${duration.inMinutes} min');
    return l10n.ringsIn(
      '${duration.inHours}h '
      '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m',
    );
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({required this.alarm});

  final Alarm alarm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.mon,
      l10n.tue,
      l10n.wed,
      l10n.thu,
      l10n.fri,
      l10n.sat,
      l10n.sun,
    ];
    return Wrap(
      spacing: 6,
      children: [
        for (var index = 0; index < labels.length; index++)
          _DayChip(
            label: labels[index],
            active: alarm.enabled && alarm.repeatWeekdays.contains(index + 1),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margin),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.noHistory,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAlarmPanel extends StatelessWidget {
  const _EmptyAlarmPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.alarm_add_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.noAlarms,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newAlarm),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.syncUnavailable,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AlarmAction { edit, test, delete }
