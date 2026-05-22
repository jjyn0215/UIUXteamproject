import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/app_providers.dart';
import '../../design/app_theme.dart';
import '../../design/app_localizations.dart';
import '../../platform/alarm_task_controller.dart';

class PermissionGuideScreen extends ConsumerStatefulWidget {
  const PermissionGuideScreen({super.key});

  @override
  ConsumerState<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends ConsumerState<PermissionGuideScreen> with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _exactAlarmGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notificationStatus = await Permission.notification.status;
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    final batteryOptimizationStatus = await Permission.ignoreBatteryOptimizations.status;

    if (mounted) {
      setState(() {
        _notificationGranted = notificationStatus.isGranted;
        _exactAlarmGranted = exactAlarmStatus.isGranted;
        _batteryOptimizationIgnored = batteryOptimizationStatus.isGranted;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAppSettingsDialog(String message) async {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? SereneWakeColors.primaryDarkBtn : SereneWakeColors.accent;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? SereneWakeColors.surfaceDark : SereneWakeColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            localizations.permissionDialogTitle,
            style: TextStyle(
              color: isDark ? SereneWakeColors.textDark : SereneWakeColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? SereneWakeColors.mutedTextDark : SereneWakeColors.mutedText,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                localizations.cancel,
                style: TextStyle(
                  color: isDark ? SereneWakeColors.mutedTextDark : SereneWakeColors.mutedText,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final opened = await AlarmTaskController.openNotificationSettings();
                if (!opened) {
                  await openAppSettings();
                }
              },
              child: Text(localizations.permissionDialogSettings),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.status;
    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      await _showAppSettingsDialog(
        AppLocalizations.of(context).permissionDialogPermanentlyMsg,
      );
      _checkPermissions();
      return;
    }

    final result = await Permission.notification.request();
    if (!mounted) return;

    if (result.isPermanentlyDenied || result.isDenied) {
      await _showAppSettingsDialog(
        AppLocalizations.of(context).permissionDialogMsg,
      );
    }
    _checkPermissions();
  }

  Future<void> _requestExactAlarm() async {
    final status = await Permission.scheduleExactAlarm.request();
    setState(() {
      _exactAlarmGranted = status.isGranted;
    });
    _checkPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryOptimizationIgnored = status.isGranted;
    });
    _checkPermissions();
  }

  Future<void> _onComplete() async {
    if (_notificationGranted && _exactAlarmGranted) {
      await ref.read(permissionStateProvider.notifier).completeGuide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryColor = isDark ? SereneWakeColors.primaryDarkBtn : SereneWakeColors.accent;
    final cardColor = isDark ? SereneWakeColors.surfaceDark : SereneWakeColors.surface;
    final textStyle = TextStyle(
      color: isDark ? SereneWakeColors.textDark : SereneWakeColors.text,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final mutedTextStyle = TextStyle(
      color: isDark ? SereneWakeColors.mutedTextDark : SereneWakeColors.mutedText,
      fontSize: 14,
    );

    final allRequiredGranted = _notificationGranted && _exactAlarmGranted;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                localizations.permissionTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? SereneWakeColors.textDark : SereneWakeColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                localizations.permissionSubtitle,
                style: mutedTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionCard(
                      icon: Icons.notifications_active_outlined,
                      title: localizations.permissionNotify,
                      description: localizations.permissionNotifyDesc,
                      isGranted: _notificationGranted,
                      onTap: _requestNotification,
                      primaryColor: primaryColor,
                      cardColor: cardColor,
                      textStyle: textStyle,
                      mutedTextStyle: mutedTextStyle,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPermissionCard(
                      icon: Icons.alarm_on_outlined,
                      title: localizations.permissionExact,
                      description: localizations.permissionExactDesc,
                      isGranted: _exactAlarmGranted,
                      onTap: _requestExactAlarm,
                      primaryColor: primaryColor,
                      cardColor: cardColor,
                      textStyle: textStyle,
                      mutedTextStyle: mutedTextStyle,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPermissionCard(
                      icon: Icons.battery_saver_outlined,
                      title: localizations.permissionBattery,
                      description: localizations.permissionBatteryDesc,
                      isGranted: _batteryOptimizationIgnored,
                      onTap: _requestBatteryOptimization,
                      primaryColor: primaryColor,
                      cardColor: cardColor,
                      textStyle: textStyle,
                      mutedTextStyle: mutedTextStyle,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              if (!allRequiredGranted)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    '시작하려면 필수 권한을 모두 허용해 주세요.',
                    style: TextStyle(
                      color: SereneWakeColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              FilledButton(
                onPressed: allRequiredGranted ? _onComplete : null,
                style: FilledButton.styleFrom(
                  backgroundColor: allRequiredGranted 
                      ? primaryColor 
                      : (isDark ? SereneWakeColors.surfaceContainerDark : SereneWakeColors.surfaceContainer),
                  foregroundColor: allRequiredGranted 
                      ? (isDark ? SereneWakeColors.backgroundDark : SereneWakeColors.surface)
                      : (isDark ? SereneWakeColors.mutedTextDark : SereneWakeColors.mutedText),
                ),
                child: Text(
                  localizations.permissionStart,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color cardColor,
    required TextStyle textStyle,
    required TextStyle mutedTextStyle,
    required bool isDark,
  }) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted 
              ? SereneWakeColors.success.withValues(alpha: 0.3) 
              : (isDark ? SereneWakeColors.outlineDark : SereneWakeColors.surfaceContainer),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isGranted
                    ? SereneWakeColors.success.withValues(alpha: 0.1)
                    : primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isGranted ? SereneWakeColors.success : primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textStyle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: mutedTextStyle),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isGranted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: SereneWakeColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: SereneWakeColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context).permissionGranted,
                      style: const TextStyle(
                        color: SereneWakeColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).permissionGrant,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
