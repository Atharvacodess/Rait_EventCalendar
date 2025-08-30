import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  String? _userRole;
  String? _userName;
  bool _isLoading = false;
  bool _rememberMe = false;

  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  User? get currentUser => _currentUser;
  String? get userRole => _userRole;
  String? get userName => _userName;

  AuthService() {
    _loadUser();
    _auth.authStateChanges().listen((User? user) async {
      print('Auth state changed - User: ${user?.uid}');

      if (user == null) {
        // User signed out - clear all data
        _currentUser = null;
        _userRole = null;
        _userName = null;
        print('User signed out - cleared all data');
        notifyListeners();
      } else if (_rememberMe) {
        // User signed in and remember me is enabled
        _currentUser = user;
        await _loadUserData();
        notifyListeners();
      } else {
        // User signed in but remember me is disabled
        _currentUser = user;
        await _loadUserData();
        notifyListeners();
      }
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMe = prefs.getBool('rememberMe') ?? false;

    if (_rememberMe) {
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        await _loadUserData();
      }
    } else {
      _currentUser = null;
      _userRole = null;
      _userName = null;
    }
    notifyListeners();
  }

  Future<bool> _loadUserData() async {
    if (_currentUser != null) {
      try {
        print('Loading user data for: ${_currentUser!.uid}');
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          _userRole = userData['role']?.toString();
          _userName = userData['name']?.toString();
          print('User data loaded - Role: $_userRole, Name: $_userName');
          return true; // User exists in database
        } else {
          print('No user document found in Firestore for UID: ${_currentUser!.uid}');
          return false; // User doesn't exist in database
        }
      } catch (e) {
        print('Error loading user data: $e');
        return false; // Error loading user data
      }
    }
    return false;
  }

  Future<void> _saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', value);
    _rememberMe = value;
  }

  // Sign in with email, password and rememberMe option
  Future<String?> signInWithEmailPassword(String email, String password, bool remember) async {
    try {
      _isLoading = true;
      notifyListeners();

      // First, authenticate with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('Firebase Auth successful for: ${userCredential.user!.uid}');

      // Now check if user exists in Firestore database
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        // User authenticated but not in our database
        print('User authenticated but not found in Firestore database');
        await _auth.signOut(); // Sign them out
        _isLoading = false;
        notifyListeners();
        return 'user-not-in-database'; // Return specific error code
      }

      // User exists in database, proceed with login
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      await _saveRememberMe(remember);
      _currentUser = userCredential.user;
      _userRole = userData['role']?.toString();
      _userName = userData['name']?.toString();

      print('Login successful - Role: $_userRole, Name: $_userName');

      _isLoading = false;
      notifyListeners();
      return null; // Success

    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Firebase Auth Error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          return 'user-not-found';
        case 'wrong-password':
          return 'wrong-password';
        case 'invalid-email':
          return 'invalid-email';
        case 'invalid-credential':
          return 'invalid-credential';
        case 'too-many-requests':
          return 'too-many-requests';
        case 'network-request-failed':
          return 'network-request-failed';
        default:
          return 'auth-error';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Unexpected error during login: $e');
      return 'unknown-error';
    }
  }

  // Register user with role
  Future<String?> registerUser(String name, String email, String password, String role) async {
    UserCredential? result;

    try {
      _isLoading = true;
      notifyListeners();

      print('Starting registration for: $email with role: $role');

      // First create the Firebase Auth user
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('Firebase Auth user created: ${result.user!.uid}');

      // Now store user data in Firestore
      await _saveUserToFirestore(result.user!.uid, name.trim(), email.trim(), role);

      _currentUser = result.user;
      _userName = name.trim();
      _userRole = role;

      _isLoading = false;
      notifyListeners();
      return null;

    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Firebase Auth Error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'email-already-in-use':
          return 'email-already-in-use';
        case 'invalid-email':
          return 'invalid-email';
        case 'weak-password':
          return 'weak-password';
        default:
          return 'registration-failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('General Error during registration: $e');

      // If Firestore failed but auth succeeded, try to clean up
      if (result?.user != null) {
        try {
          await result!.user!.delete();
          print('Cleaned up auth user after Firestore failure');
        } catch (deleteError) {
          print('Could not clean up auth user: $deleteError');
        }
      }

      return 'firestore-error';
    }
  }

  // Separate method for Firestore operations
  Future<void> _saveUserToFirestore(String uid, String name, String email, String role) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: false));

      print('User data saved to Firestore successfully');

    } catch (e) {
      print('Firestore save error: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  // Method to check if current user is valid and in database
  Future<bool> validateCurrentUser() async {
    if (_currentUser == null) return false;

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      return userDoc.exists && userDoc.data() != null;
    } catch (e) {
      print('Error validating user: $e');
      return false;
    }
  }

  // Legacy method for backward compatibility
  Future<String?> registerAdmin(String email, String password) async {
    return await registerUser('Admin', email, password, 'hod');
  }

  // Check if user can manage events (HOD or Principal)
  bool canManageEvents() {
    return _userRole == 'hod' || _userRole == 'principal';
  }

  // Check if user is principal
  bool isPrincipal() {
    return _userRole == 'principal';
  }

  // Check if user is HOD
  bool isHOD() {
    return _userRole == 'hod';
  }

  // Check if user is student
  bool isStudent() {
    return _userRole == 'student';
  }

  // Check if user is authenticated and has valid role
  bool get isAuthenticated => _currentUser != null && _userRole != null;

  // Sign out
  Future<void> signOut() async {
    try {
      print('Starting sign out process...');

      // Clear local data first
      _currentUser = null;
      _userRole = null;
      _userName = null;

      // Clear remember me preference
      await _saveRememberMe(false);

      // Sign out from Firebase
      await _auth.signOut();

      print('Sign out completed successfully');
      notifyListeners();

    } catch (e) {
      print('Error during sign out: $e');
      // Even if there's an error, clear the local data
      _currentUser = null;
      _userRole = null;
      _userName = null;
      await _saveRememberMe(false);
      notifyListeners();
    }
  }
}