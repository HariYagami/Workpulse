import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  // Watch auth state — re-run this stream whenever auth changes
  final authState = ref.watch(firebaseAuthStateProvider).value;
  if (authState == null) return Stream.value(null);
  // Stream from Firestore, errors return null and recover on next emit
  return AuthService().streamCurrentUser();
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(firebaseAuthStateProvider).value != null;
});

final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider).value?.role;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<UserModel?> signInAsStaff() async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService().signInAsStaff();
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await AuthService().signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});