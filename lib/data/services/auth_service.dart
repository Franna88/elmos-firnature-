import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  // Firebase dependencies with nullable instantiation to handle initialization errors
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  GoogleSignIn? _googleSignIn;

  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _userRole;

  // Flag to track if we're using local auth
  bool _usingLocalAuth = false;

  // Flag to enable auto-login for development
  bool _enableDevAutoLogin = true; // Set to true for development

  // Action code settings for email links
  final ActionCodeSettings _actionCodeSettings = ActionCodeSettings(
    url: 'https://www.example.com/finishSignUp?cartId=1234',
    handleCodeInApp: true,
    iOSBundleId: 'com.example.ios',
    androidPackageName: 'com.example.android',
    androidInstallApp: true,
    androidMinimumVersion: '12',
    dynamicLinkDomain: 'custom-domain.com',
  );

  // For local authentication when Firebase isn't available
  final Map<String, Map<String, dynamic>> _localUsers = {
    'admin@example.com': {
      'name': 'Admin User',
      'password': 'password123',
      'role': 'admin',
    },
    'manager@elmosfurniture.com': {
      'name': 'John Carpenter',
      'password': 'password123',
      'role': 'manager',
    },
    'assembly@elmosfurniture.com': {
      'name': 'Mike Wood',
      'password': 'password123',
      'role': 'assembly',
    },
    'finishing@elmosfurniture.com': {
      'name': 'Lisa Stain',
      'password': 'password123',
      'role': 'finishing',
    },
    'cnc@elmosfurniture.com': {
      'name': 'Robert CNC',
      'password': 'password123',
      'role': 'machinery',
    },
    'quality@elmosfurniture.com': {
      'name': 'Sarah Quality',
      'password': 'password123',
      'role': 'quality',
    }
  };

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userRole => _userRole;
  bool get usingLocalAuth => _usingLocalAuth;

  AuthService() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // First try to load persisted login state
      await _loadFromStorage();

      // Then attempt to initialize Firebase (if available)
      try {
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        _googleSignIn = GoogleSignIn();

        // Test if Firebase is working
        await _auth!.authStateChanges().first;

        if (kDebugMode) {
          print(
              'Using Firebase authentication with project: ${_auth!.app.options.projectId}');
        }

        // Check if there's already a current user
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          if (kDebugMode) {
            print('Found existing Firebase user: ${currentUser.email}');
          }
          await _setUserData(currentUser);
        }

        // If using Firebase, listen for authentication state changes
        _auth!.authStateChanges().listen((User? user) {
          if (user != null && !_usingLocalAuth) {
            _setUserData(user);
          } else if (!_usingLocalAuth && _isLoggedIn) {
            // Only clear user data if we're not using local auth
            // and no Firebase user exists but we think we're logged in
            _clearUserData();
          }
        });

        // If we're in development mode and auto-login is enabled, try to auto-login
        if (_enableDevAutoLogin && kDebugMode && _auth!.currentUser == null) {
          await autoLogin();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Firebase initialization error: $e');
          print('Falling back to local authentication');
        }
        _usingLocalAuth = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Service initialization error: $e');
        print('Falling back to local authentication');
      }
      _usingLocalAuth = true;

      // If we're in development mode and auto-login is enabled, try local auto-login
      if (_enableDevAutoLogin && kDebugMode) {
        await _localLogin('admin@example.com', 'password123');
      } else if (!_isLoggedIn) {
        await _loadFromStorage();
      }
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedIsLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final savedUsingLocalAuth = prefs.getBool('usingLocalAuth') ?? false;

      if (savedIsLoggedIn) {
        _isLoggedIn = true;
        _userId = prefs.getString('userId');
        _userEmail = prefs.getString('userEmail');
        _userName = prefs.getString('userName');
        _userRole = prefs.getString('userRole') ?? 'user';
        _usingLocalAuth = savedUsingLocalAuth;

        if (kDebugMode) {
          print('Restored login session for: $_userName ($_userEmail)');
        }

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading auth from storage: $e');
      }
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', _isLoggedIn);
      await prefs.setBool('usingLocalAuth', _usingLocalAuth);

      if (_isLoggedIn) {
        await prefs.setString('userId', _userId!);
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userRole', _userRole ?? 'user');

        if (kDebugMode) {
          print('Saved login session for: $_userName ($_userEmail)');
        }
      } else {
        await prefs.remove('userId');
        await prefs.remove('userEmail');
        await prefs.remove('userName');
        await prefs.remove('userRole');

        if (kDebugMode) {
          print('Cleared login session');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving auth to storage: $e');
      }
    }
  }

  Future<void> _setUserData(User user) async {
    _isLoggedIn = true;
    _userId = user.uid;
    _userEmail = user.email;
    _userName = user.displayName ?? user.email?.split('@').first;

    // Get user role from Firestore
    try {
      final userDoc = await _firestore!.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        _userRole = userDoc.data()?['role'] ?? 'user';
      } else {
        // Create a new user document if it doesn't exist
        await _firestore!.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@').first,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _userRole = 'user';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user role: $e');
      }
      _userRole = 'user';
    }

    await _saveToStorage();
    notifyListeners();
  }

  void _clearUserData() {
    _isLoggedIn = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _userRole = null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      // First try Firebase authentication
      if (!_usingLocalAuth) {
        try {
          if (kDebugMode) {
            print('Attempting Firebase login with email: $email');
          }

          final userCredential = await _auth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (kDebugMode) {
            print(
                'Firebase login successful for user: ${userCredential.user?.email}');
          }

          // Make sure user data is set
          if (userCredential.user != null) {
            await _setUserData(userCredential.user!);
          }

          return;
        } catch (e) {
          if (kDebugMode) {
            print('Firebase login failed: $e');
            print('Falling back to local authentication');
          }
          _usingLocalAuth = true;
        }
      }

      // If Firebase failed or we're using local auth, try local authentication
      final localLoginSuccess = await _localLogin(email, password);

      if (!localLoginSuccess) {
        // If both Firebase and local auth failed, throw an exception
        throw Exception('Authentication failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login failed: $e');
      }
      rethrow;
    }
  }

  Future<bool> _localLogin(String email, String password) async {
    if (_localUsers.containsKey(email) &&
        _localUsers[email]!['password'] == password) {
      _isLoggedIn = true;
      _userId = email;
      _userEmail = email;
      _userName = _localUsers[email]!['name'];
      _userRole = _localUsers[email]!['role'];

      await _saveToStorage();
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> signInWithGoogle() async {
    if (_usingLocalAuth) {
      return _localGoogleSignIn();
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();

      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth!.signInWithCredential(credential);
      return userCredential.user != null;
    } catch (e) {
      if (kDebugMode) {
        print('Google sign-in error: $e');
        print('Falling back to local Google sign-in simulation');
      }

      _usingLocalAuth = true;
      return _localGoogleSignIn();
    }
  }

  Future<bool> _localGoogleSignIn() async {
    const email = 'google@elmosfurniture.com';

    if (!_localUsers.containsKey(email)) {
      _localUsers[email] = {
        'name': 'Elmo Woodcraft',
        'password': 'google123',
        'role': 'manager',
      };
    }

    _isLoggedIn = true;
    _userId = email;
    _userEmail = email;
    _userName = _localUsers[email]!['name'];
    _userRole = _localUsers[email]!['role'];

    await _saveToStorage();
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    if (_usingLocalAuth) {
      return _localRegister(name, email, password);
    }

    try {
      final UserCredential userCredential =
          await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        return false;
      }

      // Update user profile
      await userCredential.user!.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore!.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase registration error: $e');
        print('Falling back to local registration');
      }

      _usingLocalAuth = true;
      return _localRegister(name, email, password);
    }
  }

  Future<bool> _localRegister(
      String name, String email, String password) async {
    if (_localUsers.containsKey(email)) {
      return false; // Email already in use
    }

    _localUsers[email] = {
      'name': name,
      'password': password,
      'role': 'user',
    };

    _isLoggedIn = true;
    _userId = email;
    _userEmail = email;
    _userName = name;
    _userRole = 'user';

    await _saveToStorage();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    if (!_usingLocalAuth) {
      try {
        await _auth?.signOut();
      } catch (e) {
        if (kDebugMode) {
          print('Firebase logout error: $e');
        }
      }
    }

    _isLoggedIn = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _userRole = null;

    await _saveToStorage();

    // Also clear any other session-related data
    await clearCachedEmailForSignIn();
    _tempUserData = {};

    notifyListeners();
  }

  // Development-friendly logout that allows auto-login on next hot reload
  Future<void> devFriendlyLogout() async {
    if (!_usingLocalAuth) {
      try {
        await _auth?.signOut();
      } catch (e) {
        if (kDebugMode) {
          print('Firebase logout error: $e');
        }
      }
    }

    _isLoggedIn = false;
    // Don't clear these fields to enable smoother hot reload experience
    // _userId = null;
    // _userEmail = null;
    // _userName = null;
    // _userRole = null;

    // Only mark as logged out but keep credentials in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    if (kDebugMode) {
      print(
          'Development-friendly logout completed. Auto-login will work on next reload.');
    }

    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    if (_usingLocalAuth) {
      return _localResetPassword(email);
    }

    try {
      await _auth?.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Reset password error: $e');
      }

      _usingLocalAuth = true;
      return _localResetPassword(email);
    }
  }

  Future<bool> _localResetPassword(String email) async {
    // Simulate password reset
    if (_localUsers.containsKey(email)) {
      if (kDebugMode) {
        print('Password reset link would be sent to $email in a real app');
      }
      return true;
    }
    return false;
  }

  // New method for email link sign-in
  Future<bool> sendSignInLinkToEmail(String email) async {
    if (_usingLocalAuth) {
      return _localSendSignInLink(email);
    }

    try {
      await _auth!.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: _actionCodeSettings,
      );

      // Save the email locally so you can retrieve it when the user clicks on the link
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', email);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Email link sign-in error: $e');
        print('Falling back to local email link sign-in simulation');
      }

      _usingLocalAuth = true;
      return _localSendSignInLink(email);
    }
  }

  Future<bool> _localSendSignInLink(String email) async {
    // Store the email for sign-in
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emailForSignIn', email);

    // Add the user to local users if not present
    if (!_localUsers.containsKey(email)) {
      _localUsers[email] = {
        'name': email.split('@').first,
        'password': 'email_link_user',
        'role': 'user',
      };
    }

    if (kDebugMode) {
      print('Email link would be sent to $email in a real app');
      print('For local testing, consider the user as signed in');
    }

    // For local testing, consider the user as pre-authorized
    _isLoggedIn = true;
    _userId = email;
    _userEmail = email;
    _userName = _localUsers[email]!['name'];
    _userRole = _localUsers[email]!['role'];

    await _saveToStorage();
    notifyListeners();

    return true;
  }

  // Process the sign-in link
  Future<bool> signInWithEmailLink(String email, String link) async {
    if (_usingLocalAuth) {
      return _localSignInWithEmailLink(email);
    }

    try {
      if (_auth!.isSignInWithEmailLink(link)) {
        final userCredential = await _auth!.signInWithEmailLink(
          email: email,
          emailLink: link,
        );

        return userCredential.user != null;
      } else {
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Email link sign-in completion error: $e');
        print('Falling back to local email link sign-in simulation');
      }

      _usingLocalAuth = true;
      return _localSignInWithEmailLink(email);
    }
  }

  Future<bool> _localSignInWithEmailLink(String email) async {
    if (!_localUsers.containsKey(email)) {
      return false;
    }

    _isLoggedIn = true;
    _userId = email;
    _userEmail = email;
    _userName = _localUsers[email]!['name'];
    _userRole = _localUsers[email]!['role'];

    await _saveToStorage();
    notifyListeners();
    return true;
  }

  // Check if an incoming link is a sign-in link
  bool isSignInWithEmailLink(String link) {
    if (_usingLocalAuth) {
      // For local testing, any link containing "signIn" would be considered valid
      return link.contains('signIn');
    }

    try {
      return _auth?.isSignInWithEmailLink(link) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking email link: $e');
      }
      return false;
    }
  }

  // Get the cached email for sign-in
  Future<String?> getCachedEmailForSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('emailForSignIn');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached email: $e');
      }
      return null;
    }
  }

  // Clear the cached email after sign-in is complete
  Future<void> clearCachedEmailForSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emailForSignIn');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cached email: $e');
      }
    }
  }

  // Temporary storage for user data during multi-step registration
  Map<String, dynamic> _tempUserData = {};

  // Store temporary user data for multi-step registration
  void setTemporaryUserData(Map<String, dynamic> userData) {
    _tempUserData = userData;
  }

  // Get temporary user data
  Map<String, dynamic> getTemporaryUserData() {
    return _tempUserData;
  }

  // Check if user is authenticated and force refresh from storage if needed
  Future<bool> checkAuthentication({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _loadFromStorage();
    }
    return _isLoggedIn;
  }

  // Verify credentials without logging in
  Future<bool> verifyCredentials(String email, String password) async {
    if (_usingLocalAuth) {
      return _localUsers.containsKey(email) &&
          _localUsers[email]!['password'] == password;
    }

    try {
      // Use Firebase to check credentials
      // This is just a validation, it won't actually sign in the user
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // If user is already signed in, we can reauthenticate
      if (_auth!.currentUser != null) {
        await _auth!.currentUser!.reauthenticateWithCredential(credential);
        return true;
      } else {
        // Otherwise, we need to try signing in but not updating state
        final userCredential = await _auth!.signInWithCredential(credential);
        final isValid = userCredential.user != null;
        // Sign out immediately to not affect current state
        if (isValid) {
          await _auth!.signOut();
        }
        return isValid;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Credential verification error: $e');
      }
      return false;
    }
  }

  // Register both company and user in a single operation
  Future<bool> registerCompanyAndUser(
      String companyName, String companyEmail) async {
    // Get the user data from temporary storage
    final userData = getTemporaryUserData();

    if (userData.isEmpty) {
      return false; // No user data available
    }

    if (_usingLocalAuth) {
      return _localRegisterCompanyAndUser(userData, companyName, companyEmail);
    }

    try {
      // First, register the user
      final UserCredential userCredential =
          await _auth!.createUserWithEmailAndPassword(
        email: userData['email'],
        password: userData['password'],
      );

      if (userCredential.user == null) {
        return false;
      }

      // Update user profile
      await userCredential.user!.updateDisplayName(userData['name']);

      // Create user document in Firestore
      await _firestore!.collection('users').doc(userCredential.user!.uid).set({
        'email': userData['email'],
        'name': userData['name'],
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create company document linked to this user
      final companyRef = await _firestore!.collection('companies').add({
        'name': companyName,
        'email': companyEmail,
        'createdBy': userCredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user with company reference
      await _firestore!
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'companyId': companyRef.id,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase company registration error: $e');
        print('Falling back to local registration');
      }

      _usingLocalAuth = true;
      return _localRegisterCompanyAndUser(userData, companyName, companyEmail);
    }
  }

  Future<bool> _localRegisterCompanyAndUser(Map<String, dynamic> userData,
      String companyName, String companyEmail) async {
    final String email = userData['email'];

    if (_localUsers.containsKey(email)) {
      return false; // Email already in use
    }

    // Add user to local users
    _localUsers[email] = {
      'name': userData['name'],
      'password': userData['password'],
      'role': 'user',
      'companyName': companyName,
      'companyEmail': companyEmail,
    };

    _isLoggedIn = true;
    _userId = email;
    _userEmail = email;
    _userName = userData['name'];
    _userRole = 'user';

    // Clear temporary data after successful registration
    _tempUserData = {};

    await _saveToStorage();
    notifyListeners();
    return true;
  }

  // Auto-login with default credentials (for development/testing)
  Future<bool> autoLogin() async {
    try {
      if (_usingLocalAuth) {
        return _localAutoLogin();
      }

      // Try Firebase auto-login first with current user
      try {
        final user = _auth!.currentUser;
        if (user != null) {
          if (kDebugMode) {
            print(
                'Firebase auto-login successful with existing user: ${user.email}');
          }
          await _setUserData(user);
          return true;
        }

        // If no current user, try to sign in with development credentials
        if (kDebugMode) {
          try {
            // Use the correct email for the elmos-furniture Firebase project
            final userCredential = await _auth!.signInWithEmailAndPassword(
              email:
                  'admin@elmosfurniture.com', // Updated to match your Firebase account
              password: 'password123',
            );
            if (userCredential.user != null) {
              if (kDebugMode) {
                print(
                    'Firebase development login successful with: ${userCredential.user!.email}');
              }
              await _setUserData(userCredential.user!);
              return true;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Firebase development login failed: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Firebase auto-login failed: $e');
          print('Falling back to local authentication');
        }
        _usingLocalAuth = true;
      }

      // If Firebase failed or we're using local auth, try local auto-login
      return _localAutoLogin();
    } catch (e) {
      if (kDebugMode) {
        print('Auto-login failed: $e');
      }
      return false;
    }
  }

  Future<bool> _localAutoLogin() async {
    if (_localUsers.containsKey('admin@example.com')) {
      _isLoggedIn = true;
      _userId = 'admin@example.com';
      _userEmail = 'admin@example.com';
      _userName = 'Admin User';
      _userRole = 'admin';

      await _saveToStorage();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Enable or disable development auto-login
  void setDevAutoLogin(bool enable) {
    _enableDevAutoLogin = enable;
  }

  // Toggle development auto-login
  void toggleDevAutoLogin() {
    _enableDevAutoLogin = !_enableDevAutoLogin;
    if (kDebugMode) {
      print(
          'Development auto-login ${_enableDevAutoLogin ? 'enabled' : 'disabled'}');
    }
  }
}
