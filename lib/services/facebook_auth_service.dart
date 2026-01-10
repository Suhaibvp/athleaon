import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class FacebookAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential?> signInWithFacebook({required String role}) async {
    print('🔵 [FB] signInWithFacebook START, role=$role');

    try {
      print('🔵 [FB] Calling FacebookAuth.instance.login()');
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      print('🔵 [FB] login() result.status = ${result.status}, message = ${result.message}');

      if (result.status != LoginStatus.success) {
        print('⚠️ [FB] Login not successful, returning null');
        return null;
      }

      final accessToken = result.accessToken!;
      print('🔵 [FB] Got accessToken: ${accessToken.tokenString.substring(0, 10)}...');

      final credential = FacebookAuthProvider.credential(accessToken.tokenString);
      print('🔵 [FB] Firebase signInWithCredential()');
      final userCred = await _auth.signInWithCredential(credential);

      final user = userCred.user;
      print('🔵 [FB] Firebase user: ${user?.uid} email=${user?.email}');
      if (user == null) return null;

      print('🔵 [FB] Fetching extra user data from Facebook');
      final fbData = await FacebookAuth.instance.getUserData();
      print('🔵 [FB] fbData = $fbData');

      final usersRef = _firestore.collection('users').doc(user.uid);
      final snap = await usersRef.get();
      print('🔵 [FB] Firestore user exists = ${snap.exists}');

      if (!snap.exists) {
        final fullName = (fbData['name'] ?? '') as String;
        final parts = fullName.split(' ');
        final firstName = parts.isNotEmpty ? parts.first : '';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        print('🔵 [FB] Creating new Firestore user doc with role=$role');
        await usersRef.set({
          'uid': user.uid,
          'email': fbData['email'] ?? user.email ?? '',
          'firstName': firstName,
          'lastName': lastName,
          'photoUrl': fbData['picture']?['data']?['url'] ?? user.photoURL,
          'role': role,
          'authProvider': 'facebook',
          'createdAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        });
      } else {
        final data = snap.data()!;
        final existingRole = data['role']?.toString() ?? 'Student';
        print('🔵 [FB] Existing Firestore user role=$existingRole');

        if (existingRole != role) {
          final msg =
              'This email is already registered as $existingRole. Please switch role.';
          print('❌ [FB] ROLE MISMATCH: $msg');
          throw Exception(msg);
        }

        print('🔵 [FB] Updating user updatedAt');
        await usersRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ [FB] signInWithFacebook SUCCESS for uid=${user.uid}');
      return userCred;
    } catch (e, st) {
      print('❌ [FB] signInWithFacebook ERROR: $e');
      print('❌ [FB] STACKTRACE:\n$st');
      rethrow;
    }
  }
}
