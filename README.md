# NoteForge 📝

A student-oriented, cross-platform note-taking app built with Flutter.

## Features

### Core Editor
- Rich text editing (bold, italic, headings, lists, checkboxes, links)
- Code blocks with syntax highlighting
- Image attachments

### Organization
- Folders / Notebooks with color coding
- Tags with color coding
- Pin, archive, and trash with restore
- Full-text search

### UI/UX
- Dark and light themes (Material 3)
- Responsive layout (mobile vs desktop)
- Grid and list view modes

### Data & Export
- SQLite local storage (fully offline)
- Export to Markdown, TXT, PDF
- Import from Markdown / TXT
- Full data backup and restore

### Security
- Biometric / PIN app lock

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI |
| Riverpod | State management |
| Drift (SQLite) | Local database |
| flutter_quill | Rich text editor |
| Material 3 | Design system |

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd noteforge

# Install dependencies
flutter pub get

# Generate database code
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Build for platforms

```bash
# Windows
flutter build windows

# Android
flutter build apk

# iOS
flutter build ios

# macOS
flutter build macos

# Linux
flutter build linux
```

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── app.dart                   # MaterialApp configuration
├── core/
│   ├── constants/             # App colors, constants
│   ├── database/              # Drift database, tables, DAOs
│   ├── router/                # App routing
│   └── theme/                 # Theme configuration
└── features/
    ├── editor/                # Note editor screen & widgets
    ├── export/                # Export/import services
    ├── folders/               # Folder management
    ├── home/                  # Home screen, grid/list views
    ├── notes/                 # Note providers
    ├── search/                # Search screen
    ├── settings/              # Settings screen & providers
    ├── tags/                  # Tag management
    └── trash/                 # Trash screen
```

## License

MIT License
