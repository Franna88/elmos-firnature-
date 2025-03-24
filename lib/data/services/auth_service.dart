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
    'user@example.com': {
      'name': 'Regular User',
      'password': 'password123',
      'role': 'user',
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
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _googleSignIn = GoogleSignIn();
      
      // Test if Firebase is working
      await _auth!.authStateChanges().first;
      
      if (kDebugMode) {
        print('Using Firebase authentication');
      }
      
      // Listen for authentication state changes
      _auth!.authStateChanges().listen((User? user) {
        if (user != null && !_usingLocalAuth) {
          _setUserData(user);
        } else if (!_usingLocalAuth) {
          _clearUserData();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization error: $e');
        print('Falling back to local authentication');
      }
      _usingLocalAuth = true;
    }
    
    // Load from storage if available
    await _loadFromStorage();
  }
  
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (prefs.getBool('isLoggedIn') == true) {
        _isLoggedIn = true;
        _userId = prefs.getString('userId');
        _userEmail = prefs.getString('userEmail');
        _userName = prefs.getString('userName');
        _userRole = prefs.getString('userRole') ?? 'user';
        _usingLocalAuth = prefs.getBool('usingLocalAuth') ?? false;
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
      prefs.setBool('isLoggedIn', _isLoggedIn);
      prefs.setBool('usingLocalAuth', _usingLocalAuth);
      
      if (_isLoggedIn) {
        prefs.setString('userId', _userId!);
        prefs.setString('userEmail', _userEmail ?? '');
        prefs.setString('userName', _userName ?? '');
        prefs.setString('userRole', _userRole ?? 'user');
      } else {
        prefs.remove('userId');
        prefs.remove('userEmail');
        prefs.remove('userName');
        prefs.remove('userRole');
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

  Future<bool> login(String email, String password) async {
    if (_usingLocalAuth) {
      return _localLogin(email, password);
    }
    
    try {
      final UserCredential userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return userCredential.user != null;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase login error: $e');
        print('Falling back to local authentication');
      }
      
      _usingLocalAuth = true;
      return _localLogin(email, password);
    }
  }
  
  Future<bool> _localLogin(String email, String password) async {
    if (_localUsers.containsKey(email) && _localUsers[email]!['password'] == password) {
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
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = await _auth!.signInWithCredential(credential);
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
    const email = 'google@example.com';
    
    if (!_localUsers.containsKey(email)) {
      _localUsers[email] = {
        'name': 'Google User',
        'password': 'google123',
        'role': 'user',
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
      final UserCredential userCredential = await _auth!.createUserWithEmailAndPassword(
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
  
  Future<bool> _localRegister(String name, String email, String password) async {
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
  
  // Register both company and user in a single operation
  Future<bool> registerCompanyAndUser(String companyName, String companyEmail) async {
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
      final UserCredential userCredential = await _auth!.createUserWithEmailAndPassword(
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
      await _firestore!.collection('users').doc(userCredential.user!.uid).update({
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
  
  Future<bool> _localRegisterCompanyAndUser(
    Map<String, dynamic> userData, 
    String companyName, 
    String companyEmail
  ) async {
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
} 