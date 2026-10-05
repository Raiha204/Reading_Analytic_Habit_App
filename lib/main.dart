import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_page.dart';
import 'app_widgets.dart';
import 'auth_page.dart';
import 'auth_service.dart';
import 'cloudinary_service.dart';
import 'dashboard_page.dart';
import 'goals_page.dart';
import 'library_page.dart';
import 'local_notification_service.dart';
import 'local_reading_store.dart';
import 'profile_page.dart';
import 'reader_page.dart';
import 'reading_models.dart';

void main() => runApp(const ReadingHabitAnalyticsApp());

class ReadingHabitAnalyticsApp extends StatelessWidget {
  const ReadingHabitAnalyticsApp({
    super.key,
    this.requireAuthentication = true,
  });

  final bool requireAuthentication;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Readwise',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: ReadingColors.green,
          brightness: Brightness.light,
          primary: ReadingColors.forest,
          secondary: ReadingColors.green,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: requireAuthentication ? const AuthGate() : const ReadingHomePage(),
    );
  }
}

class ReadingHomePage extends StatefulWidget {
  const ReadingHomePage({super.key, this.user});

  final User? user;

  @override
  State<ReadingHomePage> createState() => _ReadingHomePageState();
}

class _ReadingHomePageState extends State<ReadingHomePage> {
  int _selectedIndex = 0;
  bool _isReading = false;
  bool _storeLoaded = false;
  Book? _activeBook;
  late final LocalReadingStore _store;
  final LocalNotificationService _notifications = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    _store = LocalReadingStore(userId: widget.user?.uid);
    _bootstrapLocalServices();
  }

  Future<void> _bootstrapLocalServices() async {
    try {
      await _store.load();
      if (mounted) {
        setState(() {
          _storeLoaded = true;
          if (_activeBook == null && _store.books.isNotEmpty) {
            _activeBook = _preferredBook;
          }
        });
      }
    } catch (error) {
      debugPrint('Reading library failed to load: $error');
      if (mounted) setState(() => _storeLoaded = true);
    }
    try {
      await _notifications.initialize();
    } catch (error) {
      debugPrint('Notifications could not initialize: $error');
    }
  }

  Book? get _preferredBook {
    for (final book in _store.books) {
      if (book.status == 'In progress') return book;
    }
    return _store.books.isEmpty ? null : _store.books.first;
  }

  static const destinations = [
    NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
    NavigationDestination(
      icon: Icon(Icons.menu_book_rounded),
      label: 'Library',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_stories_rounded),
      label: 'Read',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_rounded),
      label: 'Analytics',
    ),
    NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'Goals'),
    NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_storeLoaded) {
      return const AppLoadingScreen(message: 'Loading your library…');
    }
    return Scaffold(
      body: SafeArea(child: _buildCurrentPage()),
      bottomNavigationBar: _selectedIndex == 2 && _isReading
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectPage,
              backgroundColor: Colors.white,
              elevation: 8,
              height: 72,
              indicatorColor: const Color(0xFFDCEEE5),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: destinations,
            ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _importPdf,
              backgroundColor: ReadingColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload PDF'),
            )
          : null,
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 1:
        return LibraryPage(
          store: _store,
          onOpenBook: _openBook,
          onImportPdf: _importPdf,
        );
      case 2:
        return ReaderPage(
          store: _store,
          book: _activeBook,
          isReading: _isReading,
          onStartReading: _startReading,
          onOpenBook: _openBook,
          onImportPdf: _importPdf,
          onEndReading: _endReading,
          onAchievement: _handleAchievement,
        );
      case 3:
        return AnalyticsPage(store: _store);
      case 4:
        return GoalsPage(store: _store);
      case 5:
        return ProfilePage(
          store: _store,
          user: widget.user,
          onSignOut: widget.user == null
              ? null
              : () {
                  _signOut();
                },
        );
      default:
        return DashboardPage(
          store: _store,
          displayName: widget.user?.displayName,
          onStartReading: _startReading,
          onOpenLibrary: () => _selectPage(1),
        );
    }
  }

  void _startReading() {
    if (_store.books.isEmpty) {
      setState(() => _selectedIndex = 1);
      _showSnack('Import a PDF before starting a reading session.');
      return;
    }
    setState(() {
      _activeBook ??= _preferredBook;
      _isReading = true;
      _selectedIndex = 2;
    });
  }

  void _openBook(Book book) {
    setState(() {
      _activeBook = book;
      _isReading = true;
      _selectedIndex = 2;
    });
  }

  Future<void> _importPdf() async {
    try {
      final book = await _store.importPdf();
      if (book == null || !mounted) return;
      _openBook(book);
      if (CloudinaryService.isConfigured) {
        _showSnack(
          'PDF imported locally. Cloud upload is available from the sync service.',
        );
      } else {
        _showSnack('PDF imported. Your reader is ready.');
      }
    } catch (error) {
      _showSnack('Could not import PDF: $error');
    }
  }

  void _endReading() {
    setState(() => _isReading = false);
    final session = _store.sessions.isEmpty ? null : _store.sessions.first;
    final message = session == null
        ? 'Reading session ended.'
        : 'Session saved: ${session.durationLabel} · ${session.pagesRead} pages';
    _showSnack(message);
    _notifications.show(id: 100, title: 'Reading session saved', body: message);
  }

  void _handleAchievement(String title) {
    _notifications.show(
      id: title.hashCode,
      title: 'Achievement unlocked',
      body: title,
    );
  }

  void _selectPage(int index) {
    setState(() {
      if (index == 2) _activeBook ??= _preferredBook;
      _selectedIndex = index;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }
}
