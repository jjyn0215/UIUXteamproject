import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../alarms/alarm_home_screen.dart';
import '../alarms/permission_guide_screen.dart';

class AccountGate extends ConsumerWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useFirebase) {
      ref.watch(firebaseReadyProvider);
    }

    final permissionState = ref.watch(permissionStateProvider);

    return permissionState.when(
      data: (allGranted) {
        if (allGranted) {
          return const AlarmHomeScreen();
        } else {
          return const PermissionGuideScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('권한 확인 오류: $err'),
        ),
      ),
    );
  }
}
