import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _token;
  String? _userName;
  String? _email;
  String? _userId;
  String? _phone;
  String? _userRole;

  // Getters
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userName => _userName;
  String? get email => _email;
  String? get userId => _userId;
  String? get phone => _phone;
  String? get userRole => _userRole;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AuthProvider() {
    _loadSavedUserData();
  }

  // ==================== LOAD SAVED DATA ====================
  Future<void> _loadSavedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _token = prefs.getString('token');
      _userName = prefs.getString('userName');
      _email = prefs.getString('email');
      _userId = prefs.getString('userId');
      _phone = prefs.getString('phone');
      _userRole = prefs.getString('userRole');

      if (_token != null) {
        print('🔄 [AuthProvider] ✅ User data LOADED from SharedPreferences');
        print('👤 Name: $_userName');
        print('📧 Email: $_email');
        print('📱 Phone: $_phone');
        print('🆔 User ID: $_userId');
        print('🔑 Role ID: $_userRole');
      } else {
        print('🔄 [AuthProvider] No saved user data found');
      }
    } catch (e) {
      print('❌ [AuthProvider] Error loading user data: $e');
    } finally {
      notifyListeners();
    }
  }

  // ==================== SAVE USER DATA ====================
  Future<void> _saveUserData() async {
    if (_token == null || _userId == null) {
      print('⚠️ [AuthProvider] Cannot save: Missing token or userId');
      print('Token: $_token');
      print('UserId: $_userId');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await Future.wait([
        prefs.setString('token', _token!),
        prefs.setString('userId', _userId!),
        prefs.setString('userName', _userName ?? ''),
        prefs.setString('email', _email ?? ''),
        prefs.setString('phone', _phone ?? ''),
        prefs.setString('userRole', _userRole ?? '0'),
      ]);

      print('💾 [AuthProvider] ✅ User data SAVED successfully');
      print('   User ID: $_userId');
      print('   User Name: $_userName');
      
      // Verify save
      final verifyPrefs = await SharedPreferences.getInstance();
      final savedId = verifyPrefs.getString('userId');
      print('✅ Verification - User ID in SharedPreferences: "$savedId"');
    } catch (e) {
      print('❌ [AuthProvider] Error saving user data: $e');
    }
  }

  // ==================== SIGNUP ====================
  Future<void> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    print('📝 [AuthProvider] Signup started for: $fullName');

    try {
      final url = Uri.parse('http://142.54.168.26:5050/api/auth/register');
      print('🌐 [AuthProvider] Calling Signup API: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "full_name": fullName,
          "email": email,
          "phone": phone,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        final user = data['user'];
        
        // FIX: Use '_id' instead of 'id'
        _token = data['token'];
        _userId = user['_id']?.toString(); // Changed from 'id' to '_id'
        _userName = user['full_name'];
        _email = user['email'];
        _phone = user['phone'];
        _userRole = user['role_id']?.toString() ?? '0';

        print('✅ [AuthProvider] User data extracted:');
        print('   ID: $_userId');
        print('   Name: $_userName');
        print('   Email: $_email');

        await _saveUserData();
        print('🎉 [AuthProvider] SIGNUP SUCCESSFUL!');
      } else {
        print('❌ [AuthProvider] Signup Failed: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('🚨 [AuthProvider] Signup Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== LOGIN WITH EMAIL ====================
  Future<void> loginWithEmail(String email, String password) async {
    print('📧 [AuthProvider] Login attempt with Email: $email');
    await _performLogin({"email": email}, password);
  }

  // ==================== LOGIN WITH PHONE ====================
  Future<void> loginWithPhone(String phone, String password) async {
    print('📱 [AuthProvider] Login attempt with Phone: $phone');
    await _performLogin({"phone": phone}, password);
  }

  // ==================== COMMON LOGIN LOGIC ====================
  Future<void> _performLogin(Map<String, String> credentials, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('http://142.54.168.26:5050/api/auth/login');
      print('🌐 [AuthProvider] Calling Login API: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({...credentials, "password": password}),
      );

      await _handleLoginResponse(response);
    } catch (e) {
      print('🚨 [AuthProvider] Login Exception: $e');
      _token = null;
      _userId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== HANDLE LOGIN RESPONSE ====================
  Future<void> _handleLoginResponse(http.Response response) async {
    try {
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        
        // FIX: Directly use '_id' from the response
        _token = data['token'];
        _userId = user['_id']?.toString(); // Changed from 'id' to '_id'
        _userName = user['full_name'];
        _email = user['email'];
        _phone = user['phone'];
        _userRole = user['role_id']?.toString() ?? '0';

        print('✅ [AuthProvider] User data extracted from response:');
        print('   🆔 User ID: $_userId');
        print('   👤 Name: $_userName');
        print('   📧 Email: $_email');
        print('   📱 Phone: $_phone');
        print('   🔑 Role ID: $_userRole');
        print('   🔐 Token received: ${_token != null ? "Yes (${_token!.length} chars)" : "No"}');

        await _saveUserData();
        
        print('🎉 [AuthProvider] LOGIN SUCCESSFUL!');
        print('👤 Name: $_userName');
        print('🆔 Final User ID: $_userId');
      } else {
        print('❌ [AuthProvider] Login Failed: ${data['message'] ?? 'Invalid credentials'}');
        _token = null;
        _userId = null;
      }
    } catch (e) {
      print('❌ [AuthProvider] Error parsing login response: $e');
      print('   Response body: ${response.body}');
      _token = null;
      _userId = null;
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _token = null;
      _userName = null;
      _email = null;
      _userId = null;
      _phone = null;
      _userRole = null;

      notifyListeners();
      print('🔓 [AuthProvider] User logged out successfully. All data cleared.');
    } catch (e) {
      print('❌ [AuthProvider] Logout error: $e');
    }
  }
}