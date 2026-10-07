import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_demo_app/data/repositories/local_reading_store.dart';
import 'package:flutter_demo_app/data/services/auth_service.dart';
import 'package:flutter_demo_app/data/services/cloudinary_service.dart';
import 'package:flutter_demo_app/data/repositories/profile_preferences.dart';
import 'package:flutter_demo_app/data/services/local_notification_service.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';

class ReadingHomeViewModel extends ChangeNotifier {
  ReadingHomeViewModel({
    String? userId,
    LocalReadingStore? store,
    LocalNotificationService? notifications,
  }) : store = store ?? LocalReadingStore(userId: userId),
       _ownsStore = store == null,
       _notifications = notifications ?? LocalNotificationService();

  final LocalReadingStore store;
  final bool _ownsStore;
  final LocalNotificationService _notifications;

  int selectedIndex = 0;
  bool isReading = false;
  bool storeLoaded = false;
  Book? activeBook;
  Uint8List? avatarBytes;
  String? profileName;

  Book? get preferredBook {
    for (final book in store.books) {
      if (book.status == 'In progress') return book;
    }
    return store.books.isEmpty ? null : store.books.first;
  }

  Future<void> initialize() async {
    try {
      await store.load();
      activeBook ??= preferredBook;
    } catch (error) {
      debugPrint('Reading library failed to load: $error');
    }
    if (store.userId != null) {
      try {
        profileName = await ProfilePreferences.instance.loadProfileUsername(
          store.userId!,
        );
        avatarBytes = await ProfilePreferences.instance.loadAvatar(
          store.userId!,
        );
      } catch (error) {
        debugPrint('Profile picture failed to load: $error');
      }
    }
    try {
      await _notifications.initialize();
      await _notifications.scheduleStreakReminder(
        alreadyReadToday: store.readOn(DateTime.now()),
      );
    } catch (error) {
      debugPrint('Notifications could not initialize: $error');
    } finally {
      storeLoaded = true;
      notifyListeners();
    }
  }

  String? startReading() {
    if (store.books.isEmpty) {
      selectedIndex = 1;
      notifyListeners();
      return 'Import a PDF before starting a reading session.';
    }
    activeBook ??= preferredBook;
    isReading = true;
    selectedIndex = 2;
    notifyListeners();
    return null;
  }

  void openBook(Book book) {
    activeBook = book;
    isReading = true;
    selectedIndex = 2;
    notifyListeners();
  }

  Future<String?> importPdf() async {
    try {
      final book = await store.importPdf();
      if (book == null) return null;
      openBook(book);
      return CloudinaryService.isConfigured
          ? 'Book added successfully. It is ready to read and sync.'
          : 'Book added successfully. It is ready to read.';
    } catch (error) {
      return 'Could not import PDF: $error';
    }
  }

  String endReading() {
    isReading = false;
    notifyListeners();
    final session = store.sessions.isEmpty ? null : store.sessions.first;
    if (store.readOn(DateTime.now())) {
      unawaited(_notifications.cancelStreakReminder());
    }
    final message = session == null
        ? 'Reading session ended.'
        : 'Session saved: ${session.durationLabel} · ${session.pagesRead} pages';
    _notifications.show(id: 100, title: 'Reading session saved', body: message);
    return message;
  }

  void handleAchievement(String title) {
    _notifications.show(
      id: title.hashCode,
      title: 'Achievement unlocked',
      body: title,
    );
  }

  void updateAvatar(Uint8List bytes) {
    avatarBytes = bytes;
    notifyListeners();
  }

  void selectPage(int index) {
    if (index == 2) {
      activeBook ??= preferredBook;
      isReading = activeBook != null;
    }
    selectedIndex = index;
    notifyListeners();
  }

  Future<void> signOut() => AuthService().signOut();

  @override
  void dispose() {
    if (_ownsStore) store.dispose();
    super.dispose();
  }
}
