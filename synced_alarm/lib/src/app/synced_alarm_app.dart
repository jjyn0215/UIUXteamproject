import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../design/app_localizations.dart';
import '../design/app_theme.dart';
import '../features/account/account_gate.dart';

class SyncedAlarmApp extends StatelessWidget {
  const SyncedAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildSereneWakeTheme(brightness: Brightness.light),
      darkTheme: buildSereneWakeTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('ko', '')],
      home: const AccountGate(),
    );
  }
}
