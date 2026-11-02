import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  /// Default production cloud API endpoint.
  /// When deployed to Render, Railway, or custom cloud host, worldwide multi-device sync
  /// connects seamlessly to this public HTTPS URL with zero user configuration.
  static const String defaultCloudUrl = 'https://noteforge-api-z9cr.onrender.com';
  static const String fallbackLocalUrl = 'http://localhost:5000';

  String _token = '';
  Map<String, dynamic>? _currentUser;
  late String _baseUrl = _getDefaultBaseUrl();
  bool _initialized = false;

  static String _getDefaultBaseUrl() {
    // If running in development on emulator/desktop, developers can still connect locally
    // but in release or cloud mode, default to the production cloud endpoint
    if (kIsWeb) return defaultCloudUrl;
    return defaultCloudUrl;
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _saveSession();
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

  Future<File?> _getAuthFile() async {
    try {
      if (kIsWeb) return null;
      final dir = await getApplicationDocumentsDirectory();
      return File(p.join(dir.path, 'noteforge_auth.json'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSession() async {
    try {
      final file = await _getAuthFile();
      if (file == null) return;
      final data = {
        'token': _token,
        'user': _currentUser,
        'baseUrl': _baseUrl,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save auth session: $e');
    }
  }

  /// Initialize and restore existing session from storage
  Future<void> init() async {
    if (_initialized) return;
    try {
      final file = await _getAuthFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _token = data['token'] as String? ?? '';
        _currentUser = data['user'] as Map<String, dynamic>?;
        if (data['baseUrl'] != null && (data['baseUrl'] as String).isNotEmpty) {
          final savedUrl = data['baseUrl'] as String;
          if (savedUrl.contains('noteforge-api.onrender.com')) {
            _baseUrl = defaultCloudUrl;
          } else {
            _baseUrl = savedUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load auth session: $e');
    } finally {
      _initialized = true;
    }
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

  /// Register a new user account
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
        await _saveSession();
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
        await _saveSession();
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to backend server: $e'};
    }
  }

  /// Log out
  Future<void> logout() async {
    _token = '';
    _currentUser = null;
    try {
      final file = await _getAuthFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Push local SQLite data to backend database
  Future<Map<String, dynamic>> pushSync({
    required List<Map<String, dynamic>> folders,
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> noteTags,
    List<String> deletedNoteIds = const [],
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
          'deletedNoteIds': deletedNoteIds,
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
