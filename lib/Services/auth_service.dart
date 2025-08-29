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
      if (_rememberMe) {
        _currentUser = user;
        if (user != null) {
          await _loadUserData();
        }
      } else {
        _currentUser = null;
        _userRole = null;
        _userName = null;
      }
      notifyListeners();
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

  Future<void> _loadUserData() async {
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
        } else {
          print('No user document found in Firestore');
        }
      } catch (e) {
        print('Error loading user data: $e');
        // Don't set error state, just continue without role data
      }
    }
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

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _saveRememberMe(remember);
      _currentUser = _auth.currentUser;

      if (_currentUser != null) {
        await _loadUserData();
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        default:
          return 'Login failed. Please try again.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
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

      // Now store user data in Firestore using a different approach
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
          return 'Email already in use.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password is too weak.';
        default:
          return 'Registration failed. Try again.';
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

      return 'Registration failed: $e';
    }
  }

  // Separate method for Firestore operations
  Future<void> _saveUserToFirestore(String uid, String name, String email, String role) async {
    try {
      // Use add with explicit document ID instead of set
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': DateTime.now().millisecondsSinceEpoch, // Use timestamp instead of FieldValue
      }, SetOptions(merge: false));

      print('User data saved to Firestore successfully');

    } catch (e) {
      print('Firestore save error: $e');
      throw e; // Re-throw to handle in calling method
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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _userRole = null;
    _userName = null;
    await _saveRememberMe(false);
    notifyListeners();
  }
}