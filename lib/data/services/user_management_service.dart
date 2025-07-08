import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class UserManagementService extends ChangeNotifier {
  // Firebase dependencies
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  // Service state
  bool _isLoading = false;
  bool _usingLocalStorage = false;
  List<UserModel> _users = [];

  // Local storage for users (when Firebase is not available)
  Map<String, Map<String, dynamic>> _localUsers = {};

  // Reference to AuthService for integration
  final AuthService _authService;

  // Getters
  bool get isLoading => _isLoading;
  bool get usingLocalStorage => _usingLocalStorage;
  List<UserModel> get users => List.unmodifiable(_users);

  UserManagementService(this._authService) {
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      // Try to initialize Firebase services
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Test Firebase connectivity
      await _firestore!.doc('test/connection').get();

      if (kDebugMode) {
        print('UserManagementService: Using Firebase storage');
      }

      // Initialize with existing users from AuthService local storage
      _initializeFromAuthService();
    } catch (e) {
      if (kDebugMode) {
        print(
            'UserManagementService: Firebase unavailable, using local storage - $e');
      }
      _usingLocalStorage = true;
      _initializeFromAuthService();
    }

    // Load existing users
    await refreshUsers();
  }

  void _initializeFromAuthService() {
    // Get the local users from AuthService for consistency
    final authServiceField = _authService.toString();

    // Initialize with some default users if local storage is being used
    if (_usingLocalStorage) {
      _localUsers = {
        'admin@example.com': {
          'name': 'Admin User',
          'role': 'admin',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        'manager@elmosfurniture.com': {
          'name': 'John Carpenter',
          'role': 'manager',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        'assembly@elmosfurniture.com': {
          'name': 'Mike Wood',
          'role': 'assembly',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        'finishing@elmosfurniture.com': {
          'name': 'Lisa Stain',
          'role': 'finishing',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        'cnc@elmosfurniture.com': {
          'name': 'Robert CNC',
          'role': 'machinery',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        'quality@elmosfurniture.com': {
          'name': 'Sarah Quality',
          'role': 'quality',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
      };
    }
  }

  // Refresh users list
  Future<void> refreshUsers() async {
    _setLoading(true);

    try {
      if (_usingLocalStorage) {
        await _loadUsersFromLocal();
      } else {
        await _loadUsersFromFirestore();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing users: $e');
      }
      // Fallback to local storage if Firebase fails
      if (!_usingLocalStorage) {
        _usingLocalStorage = true;
        await _loadUsersFromLocal();
      }
    }

    _setLoading(false);
  }

  Future<void> _loadUsersFromFirestore() async {
    try {
      final snapshot = await _firestore!.collection('users').get();
      _users =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      // Sort users by name
      _users.sort((a, b) => a.name.compareTo(b.name));

      if (kDebugMode) {
        print('Loaded ${_users.length} users from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users from Firestore: $e');
      }
      rethrow;
    }
  }

  Future<void> _loadUsersFromLocal() async {
    _users = _localUsers.entries
        .map((entry) => UserModel.fromMap(entry.value, entry.key))
        .toList();

    // Sort users by name
    _users.sort((a, b) => a.name.compareTo(b.name));

    if (kDebugMode) {
      print('Loaded ${_users.length} users from local storage');
    }
  }

  // Create new user
  Future<UserCreateResult> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
  }) async {
    _setLoading(true);

    try {
      // Check if user already exists
      if (_users
          .any((user) => user.email.toLowerCase() == email.toLowerCase())) {
        return UserCreateResult(
          success: false,
          message: 'User with this email already exists',
        );
      }

      if (_usingLocalStorage) {
        return await _createUserLocal(name, email, password, role, phoneNumber);
      } else {
        return await _createUserFirebase(
            name, email, password, role, phoneNumber);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user: $e');
      }
      return UserCreateResult(
        success: false,
        message: 'Failed to create user: ${e.toString()}',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCreateResult> _createUserFirebase(String name, String email,
      String password, String role, String? phoneNumber) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return UserCreateResult(
          success: false,
          message: 'Failed to create user account',
        );
      }

      // Update display name
      await user.updateDisplayName(name);

      // Create user document in Firestore
      final userModel = UserModel(
        id: user.uid,
        name: name,
        email: email,
        role: role,
        createdAt: DateTime.now(),
        phoneNumber: phoneNumber,
      );

      await _firestore!
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());

      // Add to local list
      _users.add(userModel);
      _users.sort((a, b) => a.name.compareTo(b.name));

      notifyListeners();

      return UserCreateResult(
        success: true,
        message: 'User created successfully',
        user: userModel,
        credentials: UserCredentials(email: email, password: password),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Firebase user creation error: $e');
      }
      return UserCreateResult(
        success: false,
        message: 'Failed to create user: ${e.toString()}',
      );
    }
  }

  Future<UserCreateResult> _createUserLocal(String name, String email,
      String password, String role, String? phoneNumber) async {
    final userId = email; // Use email as ID for local storage

    final userModel = UserModel(
      id: userId,
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      phoneNumber: phoneNumber,
    );

    // Add to local storage
    _localUsers[email] = userModel.toMap();

    // Add to users list
    _users.add(userModel);
    _users.sort((a, b) => a.name.compareTo(b.name));

    notifyListeners();

    return UserCreateResult(
      success: true,
      message: 'User created successfully (local storage)',
      user: userModel,
      credentials: UserCredentials(email: email, password: password),
    );
  }

  // Update user
  Future<bool> updateUser(UserModel updatedUser) async {
    _setLoading(true);

    try {
      if (_usingLocalStorage) {
        return await _updateUserLocal(updatedUser);
      } else {
        return await _updateUserFirebase(updatedUser);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _updateUserFirebase(UserModel updatedUser) async {
    try {
      final userWithTimestamp = updatedUser.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore!.collection('users').doc(updatedUser.id).update(
            userWithTimestamp.toFirestore(),
          );

      // Update local list
      final index = _users.indexWhere((user) => user.id == updatedUser.id);
      if (index != -1) {
        _users[index] = userWithTimestamp;
        _users.sort((a, b) => a.name.compareTo(b.name));
        notifyListeners();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase user update error: $e');
      }
      return false;
    }
  }

  Future<bool> _updateUserLocal(UserModel updatedUser) async {
    final userWithTimestamp = updatedUser.copyWith(
      updatedAt: DateTime.now(),
    );

    // Update local storage
    _localUsers[updatedUser.email] = userWithTimestamp.toMap();

    // Update users list
    final index = _users.indexWhere((user) => user.id == updatedUser.id);
    if (index != -1) {
      _users[index] = userWithTimestamp;
      _users.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }

    return true;
  }

  // Delete user
  Future<bool> deleteUser(String userId) async {
    _setLoading(true);

    try {
      if (_usingLocalStorage) {
        return await _deleteUserLocal(userId);
      } else {
        return await _deleteUserFirebase(userId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting user: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _deleteUserFirebase(String userId) async {
    try {
      // Note: In a production app, you might want to deactivate instead of delete
      // For now, we'll just mark as inactive in Firestore
      await _firestore!.collection('users').doc(userId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Remove from local list
      _users.removeWhere((user) => user.id == userId);
      notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase user deletion error: $e');
      }
      return false;
    }
  }

  Future<bool> _deleteUserLocal(String userId) async {
    // Find user by ID or email
    final user = _users.firstWhere((user) => user.id == userId);

    // Remove from local storage
    _localUsers.remove(user.email);

    // Remove from users list
    _users.removeWhere((user) => user.id == userId);
    notifyListeners();

    return true;
  }

  // Search users
  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return _users;

    final lowerQuery = query.toLowerCase();
    return _users.where((user) {
      return user.name.toLowerCase().contains(lowerQuery) ||
          user.email.toLowerCase().contains(lowerQuery) ||
          user.role.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Get users by role
  List<UserModel> getUsersByRole(String role) {
    return _users.where((user) => user.role == role).toList();
  }

  // Get active users
  List<UserModel> getActiveUsers() {
    return _users.where((user) => user.isActive).toList();
  }

  // Toggle user active status
  Future<bool> toggleUserStatus(String userId) async {
    final user = _users.firstWhere((user) => user.id == userId);
    final updatedUser = user.copyWith(isActive: !user.isActive);
    return await updateUser(updatedUser);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// Result classes for user operations
class UserCreateResult {
  final bool success;
  final String message;
  final UserModel? user;
  final UserCredentials? credentials;

  UserCreateResult({
    required this.success,
    required this.message,
    this.user,
    this.credentials,
  });
}

class UserCredentials {
  final String email;
  final String password;

  UserCredentials({
    required this.email,
    required this.password,
  });
}
