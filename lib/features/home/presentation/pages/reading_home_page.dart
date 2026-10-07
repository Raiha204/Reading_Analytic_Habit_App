import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_demo_app/core/widgets/app_widgets.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';
import 'package:flutter_demo_app/features/analytics/presentation/pages/analytics_page.dart';
import 'package:flutter_demo_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter_demo_app/features/goals/presentation/pages/goals_page.dart';
import 'package:flutter_demo_app/features/home/presentation/view_models/reading_home_view_model.dart';
import 'package:flutter_demo_app/features/library/presentation/pages/library_page.dart';
import 'package:flutter_demo_app/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter_demo_app/features/reader/presentation/pages/reader_page.dart';

class ReadingHomePage extends StatefulWidget {
  const ReadingHomePage({super.key, this.user});

  final User? user;

  @override
  State<ReadingHomePage> createState() => _ReadingHomePageState();
}

class _ReadingHomePageState extends State<ReadingHomePage> {
  late final ReadingHomeViewModel _viewModel;

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
  void initState() {
    super.initState();
    _viewModel = ReadingHomeViewModel(userId: widget.user?.uid)..initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (!_viewModel.storeLoaded) {
          return const AppLoadingScreen(message: 'Loading your library…');
        }
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _viewModel.selectedIndex,
              children: [
                for (var index = 0; index < destinations.length; index++)
                  _buildPage(index),
              ],
            ),
          ),
          bottomNavigationBar:
              _viewModel.selectedIndex == 2 && _viewModel.isReading
              ? null
              : NavigationBar(
                  selectedIndex: _viewModel.selectedIndex,
                  onDestinationSelected: _viewModel.selectPage,
                  backgroundColor: Colors.white,
                  elevation: 8,
                  height: 72,
                  indicatorColor: const Color(0xFFDCEEE5),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: destinations,
                ),
          floatingActionButton: _viewModel.selectedIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: _importPdf,
                  backgroundColor: ReadingColors.forest,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload PDF'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 1:
        return LibraryPage(
          store: _viewModel.store,
          onOpenBook: _openBook,
          onImportPdf: _importPdf,
        );
      case 2:
        return ReaderPage(
          store: _viewModel.store,
          book: _viewModel.activeBook,
          isReading: _viewModel.isReading,
          onStartReading: _startReading,
          onOpenBook: _openBook,
          onImportPdf: _importPdf,
          onEndReading: _endReading,
          onAchievement: _viewModel.handleAchievement,
        );
      case 3:
        return AnalyticsPage(store: _viewModel.store);
      case 4:
        return GoalsPage(store: _viewModel.store);
      case 5:
        return ProfilePage(
          store: _viewModel.store,
          user: widget.user,
          onSignOut: widget.user == null ? null : _viewModel.signOut,
          onAvatarChanged: _viewModel.updateAvatar,
        );
      default:
        return DashboardPage(
          store: _viewModel.store,
          displayName: _viewModel.profileName ?? widget.user?.displayName,
          photoUrl: widget.user?.photoURL,
          avatarBytes: _viewModel.avatarBytes,
          onStartReading: _startReading,
          onOpenLibrary: () => _viewModel.selectPage(1),
        );
    }
  }

  void _startReading() {
    final message = _viewModel.startReading();
    if (message != null) _showSnack(message);
  }

  void _openBook(Book book) => _viewModel.openBook(book);

  Future<void> _importPdf() async {
    final message = await _viewModel.importPdf();
    if (!mounted || message == null) return;
    _showSnack(message);
  }

  void _endReading() => _showSnack(_viewModel.endReading());

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
