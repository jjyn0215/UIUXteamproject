import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synced_alarm/src/data/account_repository.dart';
import 'package:synced_alarm/src/data/app_providers.dart';
import 'package:synced_alarm/src/design/app_localizations.dart';
import 'package:synced_alarm/src/features/account/account_gate.dart';
import 'package:synced_alarm/src/features/account/auth_screen.dart';
import 'package:synced_alarm/src/features/account/group_setup_screen.dart';
import 'package:synced_alarm/src/features/settings/settings_sheet.dart';
import 'package:synced_alarm/src/models/account.dart';
import 'package:synced_alarm/src/models/alarm.dart';

void main() {
  testWidgets(
    'shows local alarm home when Firebase is enabled but no user is signed in',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseReadyProvider.overrideWith((ref) async => true),
            authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
            alarmsProvider.overrideWith(
              (ref) => Stream<List<Alarm>>.value(const []),
            ),
            deviceRegistrationProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: AccountGate()),
        ),
      );

      await tester.pump();

      expect(find.text('Sign in'), findsNothing);
      expect(find.byTooltip('New alarm'), findsOneWidget);
    },
  );

  testWidgets('shows local mode and account entry point while signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWith((ref) async => true),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          userGroupsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsPanel()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Local alarms'), findsOneWidget);
    expect(find.text('No account required'), findsOneWidget);
  });

  testWidgets('creates an account from the auth screen', (tester) async {
    final accountRepository = _FakeAccountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWith((ref) => accountRepository),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.tap(find.text('Create a new account'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'June');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'june@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(accountRepository.createdEmail, 'june@example.com');
    expect(accountRepository.createdDisplayName, 'June');
  });

  testWidgets('creates a group from the setup screen', (tester) async {
    final accountRepository = _FakeAccountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWith((ref) => accountRepository),
          userGroupsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: GroupSetupScreen()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Invite code'),
      'class-code',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pump();

    expect(accountRepository.createdGroupName, 'Family alarms');
    expect(accountRepository.createdInviteCode, 'class-code');
  });

  testWidgets('joins a group from the setup screen', (tester) async {
    final accountRepository = _FakeAccountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWith((ref) => accountRepository),
          userGroupsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: GroupSetupScreen()),
      ),
    );

    await tester.tap(find.text('Join'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Group ID'),
      'family-alarms',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Invite code'),
      'class-code',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join group'));
    await tester.pump();

    expect(accountRepository.joinedGroupId, 'family-alarms');
    expect(accountRepository.joinedInviteCode, 'class-code');
  });
}

class _FakeAccountRepository implements AccountRepository {
  String? createdEmail;
  String? createdDisplayName;
  String? createdGroupName;
  String? createdInviteCode;
  String? joinedGroupId;
  String? joinedInviteCode;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    createdEmail = email;
    createdDisplayName = displayName;
  }

  @override
  Future<String> createGroup({
    required String name,
    required String inviteCode,
  }) async {
    createdGroupName = name;
    createdInviteCode = inviteCode;
    return 'family-alarms';
  }

  @override
  Future<void> joinGroup({
    required String groupId,
    required String inviteCode,
  }) async {
    joinedGroupId = groupId;
    joinedInviteCode = inviteCode;
  }

  @override
  Future<void> setActiveGroup(String groupId) async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<List<AlarmGroupSummary>> watchUserGroups(String uid) {
    return Stream.value(const []);
  }

  @override
  Stream<AppUserProfile?> watchUserProfile(String uid) {
    return Stream.value(null);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    createdDisplayName = displayName;
  }

  @override
  Future<void> deleteAccount() async {}
}
