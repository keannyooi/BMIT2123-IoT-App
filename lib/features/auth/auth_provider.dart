import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => currentUser?.uid;
  bool get isLoggedIn => currentUser != null;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile => _profile ?? (isLoggedIn ? {
    'name': currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'User',
    'email': currentUser?.email,
  } : null);
  bool _loadingProfile = false;
  bool get loadingProfile => _loadingProfile;

  bool _isRecoveringPassword = false;
  bool get isRecoveringPassword => _isRecoveringPassword;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      debugPrint('Auth Change Event: ${user == null ? 'Signed Out' : 'Signed In'}');

      if (user != null) {
        _startProfileListener(user.uid);
      } else {
        _stopProfileListener();
        _profile = null;
        _isRecoveringPassword = false;
        notifyListeners();
      }
    });

    if (isLoggedIn) _startProfileListener(currentUser!.uid);
  }

  void _startProfileListener(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        _profile = doc.data();
      } else {
        _profile = {
          'name': currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'User',
          'email': currentUser?.email,
        };
      }
      notifyListeners();
    });
  }

  void _stopProfileListener() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  // ── Sign In ────────────────────────────────────────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  // ── Register ───────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'id': credential.user!.uid,
          'username': name,
          'email': email,
          'registerTimestamp': FieldValue.serverTimestamp(),
        });
        await fetchProfile();
      }
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'Email already in use by a registered account.';
      }
      return e.message;
    } catch (e) {
      return 'Registration failed: ${e.toString()}';
    }
  }

  // ── Forgot Password ────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send reset email.';
    }
  }

  // ── Update Password ────────────────────────────────────────
  Future<String?> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      _isRecoveringPassword = false;
      // Sign out after reset to force the user back to the login page
      await signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to update password.';
    }
  }

  void cancelRecovery() {
    _isRecoveringPassword = false;
    signOut();
  }

  // ── Fetch Profile ──────────────────────────────────────────
  Future<void> fetchProfile() async {
    if (userId == null) return;
    _loadingProfile = true;
    notifyListeners();
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _profile = doc.data();
      } else {
        _profile = {
          'name': currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'User',
          'email': currentUser?.email,
        };
      }
    } catch (_) {
      _profile = {
        'name': currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'User',
        'email': currentUser?.email,
      };
    }
    _loadingProfile = false;
    notifyListeners();
  }

  // ── Update Profile ─────────────────────────────────────────
  Future<String?> updateProfile({
    required String name,
    String? phone,
    String? bio,
  }) async {
    if (userId == null) return 'Not logged in.';
    try {
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'phone': ?phone,
        'bio': ?bio,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Also update Auth Display Name for immediate availability
      await currentUser?.updateDisplayName(name);

      await fetchProfile();
      return null;
    } catch (e) {
      return 'Failed to update profile.';
    }
  }

  @override
  void dispose() {
    _stopProfileListener();
    super.dispose();
  }

  // ── Sign Out ───────────────────────────────────────────────
  Future<void> signOut() async {
    _stopProfileListener();
    await _auth.signOut();
    _profile = null;
    notifyListeners();
  }

  // ── Delete Account ─────────────────────────────────────────
  Future<String?> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) return 'No user logged in';
      
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      _profile = null;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to delete account: $e';
    }
  }
}
