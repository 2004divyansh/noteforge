import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noteforge/core/database/database.dart';
import 'package:noteforge/core/services/api_service.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isInitialized = false,
    this.userName,
    this.userEmail,
    required this.serverUrl,
    this.isServerOnline = false,
    this.isSyncing = false,
    this.lastSyncTime,
    this.statusMessage,
  });

  final bool isAuthenticated;
  final bool isInitialized;
  final String? userName;
  final String? userEmail;
  final String serverUrl;
  final bool isServerOnline;
  final bool isSyncing;
  final String? lastSyncTime;
  final String? statusMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isInitialized,
    String? userName,
    String? userEmail,
    String? serverUrl,
    bool? isServerOnline,
    bool? isSyncing,
    String? lastSyncTime,
    String? statusMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isInitialized: isInitialized ?? this.isInitialized,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      serverUrl: serverUrl ?? this.serverUrl,
      isServerOnline: isServerOnline ?? this.isServerOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(AuthState(
          serverUrl: ApiService.instance.baseUrl,
        )) {
    _initSession();
  }

  final ApiService _api = ApiService.instance;
  Timer? _autoSyncTimer;
  AppDatabase? _db;

  Future<void> _initSession() async {
    await _api.init();
    if (_api.isAuthenticated && _api.currentUser != null) {
      state = state.copyWith(
        isAuthenticated: true,
        isInitialized: true,
        userName: _api.currentUser!['name'] as String?,
        userEmail: _api.currentUser!['email'] as String?,
        serverUrl: _api.baseUrl,
        isServerOnline: true,
        statusMessage: 'Cloud sync active.',
      );
      _startAutoSync();
    } else {
      state = state.copyWith(isInitialized: true);
    }
    checkServerHealth();
  }

  void setDatabase(AppDatabase db) {
    _db = db;
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    // Silent periodic background sync every 60 seconds
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (state.isAuthenticated && _db != null && !state.isSyncing) {
        syncWithBackend(_db!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> checkServerHealth() async {
    final online = await _api.checkHealth();
    state = state.copyWith(isServerOnline: online);
  }

  void updateServerUrl(String newUrl) {
    _api.baseUrl = newUrl;
    state = state.copyWith(serverUrl: _api.baseUrl);
    checkServerHealth();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(statusMessage: 'Creating account...');
    final result = await _api.register(name: name, email: email, password: password);

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>;
      state = state.copyWith(
        isAuthenticated: true,
        userName: user['name'] as String?,
        userEmail: user['email'] as String?,
        isServerOnline: true,
        statusMessage: 'Account created successfully!',
      );
      _startAutoSync();
      return true;
    } else {
      state = state.copyWith(
        statusMessage: result['error']?.toString() ?? 'Registration failed',
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(statusMessage: 'Signing in...');
    final result = await _api.login(email: email, password: password);

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>;
      state = state.copyWith(
        isAuthenticated: true,
        userName: user['name'] as String?,
        userEmail: user['email'] as String?,
        isServerOnline: true,
        statusMessage: 'Signed in successfully.',
      );
      _startAutoSync();
      return true;
    } else {
      state = state.copyWith(
        statusMessage: result['error']?.toString() ?? 'Invalid email or password.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    _autoSyncTimer?.cancel();
    await _api.logout();

    // Clear local notes, folders, and tags so they disappear on logout
    if (_db != null) {
      try {
        await _db!.delete(_db!.noteTags).go();
        await _db!.delete(_db!.notes).go();
        await _db!.delete(_db!.folders).go();
        await _db!.delete(_db!.tags).go();
      } catch (e) {
        debugPrint('Error clearing local database on logout: $e');
      }
    }

    state = state.copyWith(
      isAuthenticated: false,
      isSyncing: false,
      userName: null,
      userEmail: null,
      lastSyncTime: null,
      statusMessage: 'Logged out.',
    );
  }

  /// Two-way sync with the backend database
  Future<bool> syncWithBackend(AppDatabase db, {bool silent = false}) async {
    if (!state.isAuthenticated) {
      if (!silent) {
        state = state.copyWith(statusMessage: 'Please sign in to sync notes.');
      }
      return false;
    }

    if (state.isSyncing) {
      return false;
    }

    state = state.copyWith(
      isSyncing: true,
      statusMessage: silent ? state.statusMessage : 'Syncing notes...',
    );

    try {
      // 1. Gather all local notes, folders, and tags from Drift
      final localFolders = await db.foldersDao.getAllFolders();
      final localTags = await db.tagsDao.getAllTags();
      final localNotes = await (db.select(db.notes)).get();

      final foldersPayload = localFolders.map((f) => {
        'id': f.id,
        'name': f.name,
        'color': f.color,
        'parentId': f.parentId,
        'createdAt': f.createdAt.toIso8601String(),
        'updatedAt': f.createdAt.toIso8601String(),
      }).toList();

      final tagsPayload = localTags.map((t) => {
        'id': t.id,
        'name': t.name,
        'color': t.color,
      }).toList();

      final notesPayload = localNotes.map((n) => {
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'plainText': n.plainText,
        'folderId': n.folderId,
        'isPinned': n.isPinned ? 1 : 0,
        'isArchived': n.isArchived ? 1 : 0,
        'isTrashed': n.isTrashed ? 1 : 0,
        'trashedAt': n.trashedAt?.toIso8601String(),
        'createdAt': n.createdAt.toIso8601String(),
        'updatedAt': n.updatedAt.toIso8601String(),
      }).toList();

      // Push local state to backend
      final pushResult = await _api.pushSync(
        folders: foldersPayload,
        tags: tagsPayload,
        notes: notesPayload,
        noteTags: [],
      );

      if (pushResult['success'] != true) {
        state = state.copyWith(
          statusMessage: pushResult['error']?.toString() ?? 'Sync push failed',
        );
        return false;
      }

      // 2. Pull remote changes from backend
      final pullResult = await _api.pullSync();
      if (pullResult['success'] == true && pullResult['data'] != null) {
        final data = pullResult['data'] as Map<String, dynamic>;
        final remoteNotes = data['notes'] as List<dynamic>? ?? [];
        final remoteFolders = data['folders'] as List<dynamic>? ?? [];
        final remoteTags = data['tags'] as List<dynamic>? ?? [];

        // Insert/merge remote folders
        for (final f in remoteFolders) {
          final fMap = f as Map<String, dynamic>;
          final companion = FoldersCompanion(
            id: Value(fMap['id'] as String),
            name: Value(fMap['name'] as String),
            color: Value(fMap['color'] as int? ?? 0xFF6750A4),
            parentId: Value(fMap['parent_id'] as String?),
            sortOrder: Value(fMap['sort_order'] as int? ?? 0),
            createdAt: Value(
              DateTime.tryParse(fMap['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
          await db.into(db.folders).insertOnConflictUpdate(companion);
        }

        // Insert/merge remote tags
        for (final t in remoteTags) {
          final tMap = t as Map<String, dynamic>;
          final companion = TagsCompanion(
            id: Value(tMap['id'] as String),
            name: Value(tMap['name'] as String),
            color: Value(tMap['color'] as int? ?? 0xFFEF5350),
            createdAt: Value(
              DateTime.tryParse(tMap['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
          await db.into(db.tags).insertOnConflictUpdate(companion);
        }

        // Insert/merge remote notes
        for (final n in remoteNotes) {
          final nMap = n as Map<String, dynamic>;
          final companion = NotesCompanion(
            id: Value(nMap['id'] as String),
            title: Value(nMap['title'] as String? ?? 'Untitled'),
            content: Value(nMap['content'] as String? ?? ''),
            plainText: Value(nMap['plain_text'] as String? ?? ''),
            folderId: Value(nMap['folder_id'] as String?),
            isPinned: Value(nMap['is_pinned'] == 1),
            isArchived: Value(nMap['is_archived'] == 1),
            isTrashed: Value(nMap['is_trashed'] == 1),
            trashedAt: Value(
              nMap['trashed_at'] != null
                  ? DateTime.tryParse(nMap['trashed_at'].toString())
                  : null,
            ),
            createdAt: Value(
              DateTime.tryParse(nMap['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(nMap['updated_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
          await db.into(db.notes).insertOnConflictUpdate(companion);
        }
      }

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      state = state.copyWith(
        lastSyncTime: timeStr,
        statusMessage: 'Synced at $timeStr',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        statusMessage: 'Sync error: $e',
      );
      return false;
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  final notifier = AuthNotifier();
  notifier.setDatabase(db);
  return notifier;
});
