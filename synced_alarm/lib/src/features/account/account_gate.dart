import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../alarms/alarm_home_screen.dart';

class AccountGate extends ConsumerWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useFirebase) {
      ref.watch(firebaseReadyProvider);
    }
    return const AlarmHomeScreen();
  }
}
