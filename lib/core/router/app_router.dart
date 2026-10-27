import 'package:flutter/material.dart';
import 'package:noteforge/features/home/screens/home_screen.dart';
import 'package:noteforge/features/editor/screens/editor_screen.dart';
import 'package:noteforge/features/folders/screens/folder_management_screen.dart';
import 'package:noteforge/features/tags/screens/tag_management_screen.dart';
import 'package:noteforge/features/settings/screens/settings_screen.dart';
import 'package:noteforge/features/search/screens/search_screen.dart';
import 'package:noteforge/features/trash/screens/trash_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String editor = '/editor';
  static const String folders = '/folders';
  static const String tags = '/tags';
  static const String settings = '/settings';
  static const String search = '/search';
  static const String trash = '/trash';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case editor:
        final noteId = routeSettings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => EditorScreen(noteId: noteId),
        );
      case folders:
        return MaterialPageRoute(builder: (_) => const FolderManagementScreen());
      case tags:
        return MaterialPageRoute(builder: (_) => const TagManagementScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case trash:
        return MaterialPageRoute(builder: (_) => const TrashScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
