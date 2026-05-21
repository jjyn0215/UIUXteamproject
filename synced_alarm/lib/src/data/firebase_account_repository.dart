import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account.dart';
import 'account_repository.dart';
import 'firebase_operation_timeout.dart';

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  @override
  Stream<AppUserProfile?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return AppUserProfile.fromJson(doc.id, data);
    });
  }

  @override
  Stream<List<AlarmGroupSummary>> watchUserGroups(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groups')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AlarmGroupSummary.fromJson(doc.id, doc.data());
          }).toList();
        });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await withFirebaseOperationTimeout(
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password),
      operationName: 'sign in',
    );
    await _upsertCurrentUserProfile();
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await withFirebaseOperationTimeout(
      _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
      operationName: 'create account',
    );
    final user = credential.user;
    if (user != null && displayName.trim().isNotEmpty) {
      await withFirebaseOperationTimeout(
        user.updateDisplayName(displayName.trim()),
        operationName: 'update profile',
      );
      await user.reload();
    }
    await _upsertCurrentUserProfile(displayName: displayName);
  }

  @override
  Future<void> signOut() {
    return withFirebaseOperationTimeout(
      _auth.signOut(),
      operationName: 'sign out',
    );
  }

  @override
  Future<String> createGroup({
    required String name,
    required String inviteCode,
  }) async {
    final user = _requireUser();
    await _upsertCurrentUserProfile();
    final result = await withFirebaseOperationTimeout(
      _functions.httpsCallable('createGroup').call<Map<String, Object?>>({
        'name': name.trim(),
        'inviteCode': inviteCode.trim(),
      }),
      operationName: 'create group',
    );
    final data = result.data;
    final groupId = data['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      throw StateError('Group creation did not return a group id.');
    }
    await setActiveGroup(groupId);
    await _upsertCurrentUserProfile(uid: user.uid);
    return groupId;
  }

  @override
  Future<void> joinGroup({
    required String groupId,
    required String inviteCode,
  }) async {
    await _upsertCurrentUserProfile();
    await withFirebaseOperationTimeout(
      _functions.httpsCallable('joinGroup').call<Map<String, Object?>>({
        'groupId': groupId.trim(),
        'accessCode': inviteCode.trim(),
      }),
      operationName: 'join group',
    );
    await setActiveGroup(groupId.trim());
  }

  @override
  Future<void> setActiveGroup(String groupId) async {
    final user = _requireUser();
    await withFirebaseOperationTimeout(
      _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': _displayName(user),
        'lastActiveGroupId': groupId,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)),
      operationName: 'set active group',
    );
  }

  Future<void> _upsertCurrentUserProfile({String? uid, String? displayName}) {
    final user = _requireUser();
    return withFirebaseOperationTimeout(
      _firestore.collection('users').doc(uid ?? user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : _displayName(user),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)),
      operationName: 'upsert user profile',
    );
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before using account features.');
    }
    return user;
  }

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user.email?.split('@').first.trim() ?? 'User';
  }
}
