import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // ← add this import
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '834515432222-6vshiln5b28a9jhnn65t4trf9l840ho7.apps.googleusercontent.com',
  );

  User? get currentFirebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String get currentUserFirstName {
    final name = _auth.currentUser?.displayName ?? '';
    return name.isNotEmpty ? name.split(' ').first : 'Staff';
  }

  String get currentUserFullName =>
      _auth.currentUser?.displayName ?? 'Staff';

  String get currentUserEmail => _auth.currentUser?.email ?? '';

  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;

  Future<UserModel?> signInAsStaff() async {
    return _signInWithGoogle(isAdmin: false);
  }

  Future<UserModel?> signInAsAdmin() async {
    return _signInWithGoogle(isAdmin: true);
  }

  Future<UserModel?> _signInWithGoogle({required bool isAdmin}) async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      await firebaseUser.getIdToken(true);
      await Future.delayed(const Duration(milliseconds: 1000));

      final docRef = _db.collection('users').doc(firebaseUser.uid);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final existingIsAdmin = data['isAdmin'] ?? false;

        if (existingIsAdmin != isAdmin) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw Exception(
            existingIsAdmin
                ? 'This account is registered as Admin. Please use "Sign in as Admin".'
                : 'This account is registered as Staff. Please use "Sign in with Google" under Staff Member.',
          );
        }

        return UserModel.fromFirestore(docSnap);
      } else {
        final newUser = UserModel.fromFirebaseUser(
          firebaseUser,
          isAdmin: isAdmin,
        );
        await docRef.set(newUser.toMap());
        return newUser;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    // ← ADDED: catch Google Play Services network errors
    } on PlatformException catch (e) {
      throw _handlePlatformError(e);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.getIdToken(false);

    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    if (!data.containsKey('isAdmin')) {
      await docRef.update({'isAdmin': false});
      final updated = await docRef.get();
      return UserModel.fromFirestore(updated);
    }

    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> streamCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .handleError((error) {})
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
  }

  Exception _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return Exception(
            'This email is registered with a different sign-in method.');
      case 'invalid-credential':
        return Exception('Invalid credentials. Please try again.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'network-request-failed':
        return Exception('No internet connection. Check your network.');
      default:
        return Exception('Authentication error: ${e.message}');
    }
  }

  // ← ADDED: friendly messages for Google Play Services errors
  Exception _handlePlatformError(PlatformException e) {
    switch (e.code) {
      case 'network_error':
        return Exception(
            'No internet connection. Please check your network and try again.');
      case 'sign_in_failed':
        return Exception('Google Sign-In failed. Please try again.');
      case 'sign_in_canceled':
        return Exception('Sign-in was cancelled.');
      default:
        return Exception(
            'Google Sign-In error. Please check your internet and try again.');
    }
  }
}