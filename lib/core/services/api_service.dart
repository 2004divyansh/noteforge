import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._internal();
  // Singleton pattern
  static final ApiService instance = ApiService._internal();

  String _token = '';
  Map<String, dynamic>? _currentUser;

  // Default URL depends on platform (Android emulator uses 10.0.2.2, desktop uses localhost)
  late String _baseUrl = _getDefaultBaseUrl();

  static String _getDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    } catch (_) {}
    return 'http://localhost:5000';
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  bool get isAuthenticated => _token.isNotEmpty && _currentUser != null;
  String get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(
        const Duration(seconds: 4),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 && data['success'] == true) {
        _token = data['token'] as String;
        _currentUser = data['user'] as Map<String, dynamic>;
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to backend server: $e'};
    }
  }

  /// Log in an existing user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        _token = data['token'] as String;
        _currentUser = data['user'] as Map<String, dynamic>;
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to backend server: $e'};
    }
  }

  /// Log out
  void logout() {
    _token = '';
    _currentUser = null;
  }

  /// Push local SQLite data to backend database
  Future<Map<String, dynamic>> pushSync({
    required List<Map<String, dynamic>> folders,
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> noteTags,
  }) async {
    if (!isAuthenticated) {
      return {'success': false, 'error': 'Authentication required to sync.'};
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/sync/push'),
        headers: _headers(),
        body: jsonEncode({
          'folders': folders,
          'tags': tags,
          'notes': notes,
          'noteTags': noteTags,
        }),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {'success': false, 'error': 'Sync push failed: $e'};
    }
  }

  /// Pull all data from backend database
  Future<Map<String, dynamic>> pullSync() async {
    if (!isAuthenticated) {
      return {'success': false, 'error': 'Authentication required to sync.'};
    }

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/sync/pull'),
        headers: _headers(),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {'success': false, 'error': 'Sync pull failed: $e'};
    }
  }
}
