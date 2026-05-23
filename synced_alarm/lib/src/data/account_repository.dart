import 'package:firebase_auth/firebase_auth.dart';

import '../models/account.dart';

abstract interface class AccountRepository {
  Stream<User?> authStateChanges();

  Stream<AppUserProfile?> watchUserProfile(String uid);

  Stream<List<AlarmGroupSummary>> watchUserGroups(String uid);

  Future<void> signIn({required String email, required String password});

  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<String> createGroup({
    required String name,
    required String inviteCode,
  });

  Future<void> joinGroup({required String groupId, required String inviteCode});

  Future<void> setActiveGroup(String groupId);
  
  Future<void> updateDisplayName(String displayName);

  Future<void> deleteAccount();
}
