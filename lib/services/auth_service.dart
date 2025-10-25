import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password (WITH EMAIL VERIFICATION)
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required String dateOfBirth,
    required String state,
    required String language,
  }) async {
    try {
      // Firebase Auth will automatically throw error if email exists
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Update display name
      await userCredential.user?.updateDisplayName('$firstName $lastName');

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'uid': userCredential.user?.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'dateOfBirth': dateOfBirth,
        'state': state,
        'language': language,
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'email',
        'profileCompleted': true,
        'emailVerified': false,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
    String? requestedRole,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If role is provided, validate it
      if (requestedRole != null) {
        final userData = await getUserData(userCredential.user!.uid);
        if (userData != null && userData['role'] != requestedRole) {
          await signOut();
          throw 'This email is registered as ${userData['role']}. Please login as ${userData['role']}.';
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  // Sign in with Google
// Sign in with Google (Check role AFTER authentication)
Future<UserCredential?> signInWithGoogle({String? role}) async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      return null; // User cancelled
    }

    // Get Google auth credentials
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase (user is now authenticated)
    UserCredential userCredential = await _auth.signInWithCredential(credential);

    // NOW check if user exists and validate role
    final userDoc = await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    if (userDoc.exists) {
      // Existing user - check role
      final existingRole = userDoc.data()!['role'];
      
      if (existingRole != role) {
        // Role mismatch - sign out
        await signOut();
        throw 'This Google account is already registered as $existingRole. Please login as $existingRole.';
      }
      
      // Role matches - proceed with login
      return userCredential;
    } else {
      // New user - create profile
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'firstName': googleUser.displayName?.split(' ').first ?? '',
        'lastName': googleUser.displayName?.split(' ').last ?? '',
        'role': role ?? 'Student',
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'google',
        'photoUrl': userCredential.user?.photoURL,
        'profileCompleted': false,
        'emailVerified': true, // Google emails are pre-verified
      });
      
      return userCredential;
    }
  } catch (e) {
    throw e.toString();
  }
}


  // Check email verification and update Firestore
  Future<bool> checkAndUpdateEmailVerification() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await currentUser.reload();
      final user = _auth.currentUser;

      if (user != null && user.emailVerified) {
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
        });
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        await currentUser.sendEmailVerification();
      }
    } catch (e) {
      throw 'Error sending verification email: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'An error occurred during sign out';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if profile is complete
  Future<bool> isProfileComplete(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('profileCompleted') ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }
}
