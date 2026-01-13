import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:gradeflow/models/user.dart';

class AuthService extends ChangeNotifier {
  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users';
  User? _currentUser;
  bool _isLoading = false;
  bool _initialized = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || _isLoading) return;
    _isLoading = true;
    // Do not notify here to avoid setState/markNeedsBuild during build
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson != null) {
        _currentUser = User.fromJson(json.decode(userJson) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Failed to load current user: $e');
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      
      if (usersJson != null) {
        final List<dynamic> usersList = json.decode(usersJson) as List;
        final userMap = usersList.firstWhere(
          (u) => (u as Map<String, dynamic>)['email'] == email,
          orElse: () => null,
        );
        
        if (userMap != null) {
          _currentUser = User.fromJson(userMap as Map<String, dynamic>);
          await prefs.setString(_currentUserKey, json.encode(_currentUser!.toJson()));
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Login failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String fullName, String? schoolName) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      List<Map<String, dynamic>> usersList = [];
      
      if (usersJson != null) {
        usersList = (json.decode(usersJson) as List).cast<Map<String, dynamic>>();
        
        if (usersList.any((u) => u['email'] == email)) {
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }
      
      final now = DateTime.now();
      final newUser = User(
        userId: const Uuid().v4(),
        email: email,
        fullName: fullName,
        schoolName: schoolName,
        createdAt: now,
        updatedAt: now,
      );
      
      usersList.add(newUser.toJson());
      await prefs.setString(_usersKey, json.encode(usersList));
      
      _currentUser = newUser;
      await prefs.setString(_currentUserKey, json.encode(_currentUser!.toJson()));
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      _currentUser = null;
    } catch (e) {
      debugPrint('Logout failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCurrentUser(User updated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Update current user cache
      _currentUser = updated;
      await prefs.setString(_currentUserKey, json.encode(updated.toJson()));

      // Update the users list entry
      final usersJson = prefs.getString(_usersKey);
      if (usersJson != null) {
        final List<dynamic> list = json.decode(usersJson) as List<dynamic>;
        final idx = list.indexWhere((u) => (u as Map<String, dynamic>)['userId'] == updated.userId);
        if (idx != -1) {
          list[idx] = updated.toJson();
          await prefs.setString(_usersKey, json.encode(list));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update current user: $e');
    }
  }

  Future<void> seedDemoUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      
      if (usersJson == null) {
        final demoUser = User(
          userId: 'demo-teacher-1',
          email: 'teacher@demo.com',
          fullName: 'Demo Teacher',
          schoolName: 'Riverside High School',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await prefs.setString(_usersKey, json.encode([demoUser.toJson()]));
        debugPrint('Demo user seeded successfully');
      }
    } catch (e) {
      debugPrint('Failed to seed demo user: $e');
    }
  }
}
