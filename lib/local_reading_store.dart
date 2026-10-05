import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reading_models.dart';
import 'pdf_thumbnail_service.dart';
import 'pdf_document_storage.dart';

class LocalReadingStore extends ChangeNotifier {
  LocalReadingStore({this.userId});

  final String? userId;

  static const _booksKey = 'reading_books';
  static const _sessionsKey = 'reading_sessions';
  static const _bookmarksKey = 'reading_bookmarks';
  static const _notesKey = 'reading_notes';
  static const _highlightsKey = 'reading_highlights';
  static const _goalsKey = 'reading_goals';
  static const _goalAchievementsKey = 'reading_goal_achievements';

  SharedPreferencesAsync? _preferences;
  Future<void>? _loadFuture;
  final List<Book> _books = [];
  final List<ReadingSessionRecord> _sessions = [];
  final List<ReadingBookmark> _bookmarks = [];
  final List<ReadingNote> _notes = [];
  final List<ReadingHighlight> _highlights = [];
  final List<ReadingGoalDefinition> _goals = [];
  final List<Map<String, dynamic>> _goalAchievements = [];

  List<Book> get books => List.unmodifiable(_books);
  List<ReadingSessionRecord> get sessions => List.unmodifiable(_sessions);
  List<ReadingBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<ReadingNote> get notes => List.unmodifiable(_notes);
  List<ReadingHighlight> get highlights => List.unmodifiable(_highlights);
  List<ReadingGoalDefinition> get goals => List.unmodifiable(_goals);
  List<Map<String, dynamic>> get goalAchievements =>
      List.unmodifiable(_goalAchievements);
  int get totalMinutes =>
      _sessions.fold(0, (total, session) => total + session.durationMinutes);
  int get totalPages =>
      _sessions.fold(0, (total, session) => total + session.pagesRead);
  int get totalSessions => _sessions.length;
  int get completedBookCount =>
      _books.where((book) => book.progress >= 1).length;
  int get currentStreak => _calculateStreak();
  int get longestStreak => _calculateLongestStreak();

  bool hasGoalAchievement(String goalId, String periodKey) =>
      _goalAchievements.any(
        (item) => item['goalId'] == goalId && item['periodKey'] == periodKey,
      );

  int minutesReadOn(DateTime date) {
    final day = _dateOnly(date);
    return _sessions
        .where((session) => _dateOnly(session.startedAt) == day)
        .fold(0, (total, session) => total + session.durationMinutes);
  }

  int pagesReadOn(DateTime date) {
    final day = _dateOnly(date);
    return _sessions
        .where((session) => _dateOnly(session.startedAt) == day)
        .fold(0, (total, session) => total + session.pagesRead);
  }

  int minutesReadInMonth(DateTime date) => _sessions
      .where((session) => _isSameMonth(session.startedAt, date))
      .fold(0, (total, session) => total + session.durationMinutes);

  int finishedBooksInMonth(DateTime date) => _books.where((book) {
    if (book.status != 'Completed') return false;
    final completedAt = book.completedAt ?? book.createdAt;
    return completedAt != null && _isSameMonth(completedAt, date);
  }).length;

  int readingDaysInWeek(DateTime date) {
    final day = _dateOnly(date);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return List.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    ).where(readOn).length;
  }

  Future<void> addGoal({
    required String metric,
    required String title,
    required int target,
  }) async {
    _goals.insert(
      0,
      ReadingGoalDefinition(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        metric: metric,
        title: title,
        target: target,
        createdAt: DateTime.now(),
      ),
    );
    await _persistGoals();
    await _syncGoalAchievements();
    notifyListeners();
  }

  Future<void> removeGoal(String goalId) async {
    _goals.removeWhere((goal) => goal.id == goalId);
    await _persistGoals();
    notifyListeners();
  }

  bool readOn(DateTime date) => _sessions.any(
    (session) => _dateOnly(session.startedAt) == _dateOnly(date),
  );

  Future<void> load() => _loadFuture ??= _loadFromStorage();

  Future<void> _loadFromStorage() async {
    await _ensurePreferences();
    _books
      ..clear()
      ..addAll(await _decodeList(_booksKey, Book.fromJson));
    _sessions
      ..clear()
      ..addAll(await _decodeList(_sessionsKey, ReadingSessionRecord.fromJson));
    _bookmarks
      ..clear()
      ..addAll(await _decodeList(_bookmarksKey, ReadingBookmark.fromJson));
    _notes
      ..clear()
      ..addAll(await _decodeList(_notesKey, ReadingNote.fromJson));
    _highlights
      ..clear()
      ..addAll(await _decodeList(_highlightsKey, ReadingHighlight.fromJson));
    _goals
      ..clear()
      ..addAll(await _decodeList(_goalsKey, ReadingGoalDefinition.fromJson));
    _goalAchievements
      ..clear()
      ..addAll(await _decodeList(_goalAchievementsKey, (json) => json));
    if (kIsWeb) {
      for (var index = 0; index < _books.length; index++) {
        final book = _books[index];
        final marker = book.filePath;
        if (marker == null || !marker.startsWith('browser-pdf:')) continue;
        final bytes = await loadBrowserPdf(
          marker.substring('browser-pdf:'.length),
        );
        if (bytes != null) _books[index] = book.copyWith(fileBytes: bytes);
      }
    }
    await _generateMissingCovers();
    await _syncGoalAchievements();
    notifyListeners();
  }

  Future<void> _generateMissingCovers() async {
    var changed = false;
    for (var index = 0; index < _books.length; index++) {
      final book = _books[index];
      if (book.coverBytes != null) continue;
      Uint8List? source = book.fileBytes;
      if (!kIsWeb && source == null && book.filePath != null) {
        try {
          source = await File(book.filePath!).readAsBytes();
        } catch (_) {
          source = null;
        }
      }
      if (source == null) continue;
      final cover = await PdfThumbnailService.renderFirstPage(source);
      if (cover == null) continue;
      _books[index] = book.copyWith(coverBytes: cover);
      changed = true;
    }
    if (changed) await _persistBooks();
  }

  Future<Book?> importPdf() async {
    // Wait for the first disk read before adding a new item, otherwise a fast
    // import can race the initial load and then be overwritten by old data.
    await load();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final safeName = _safeFileName(
      picked.name.isEmpty ? 'book.pdf' : picked.name,
    );
    final title = safeName.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    String? filePath;
    Uint8List? fileBytes;

    if (kIsWeb) {
      fileBytes = picked.bytes;
      if (fileBytes == null) {
        throw StateError('The selected PDF could not be read by the browser.');
      }
      await saveBrowserPdf(id, fileBytes);
      filePath = 'browser-pdf:$id';
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final booksDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}books',
      );
      await booksDirectory.create(recursive: true);
      final destination = File(
        '${booksDirectory.path}${Platform.pathSeparator}${id}_$safeName',
      );
      if (picked.bytes != null) {
        await destination.writeAsBytes(picked.bytes!, flush: true);
      } else if (picked.path != null) {
        await File(picked.path!).copy(destination.path);
      } else {
        throw StateError(
          'The selected PDF could not be saved. Try importing it again.',
        );
      }
      filePath = destination.path;
    }

    final thumbnailSource = kIsWeb
        ? fileBytes
        : await File(filePath).readAsBytes();
    final coverBytes = thumbnailSource == null
        ? null
        : await PdfThumbnailService.renderFirstPage(thumbnailSource);
    final book = Book(
      id: id,
      title: title,
      author: 'Imported PDF',
      progress: 0,
      coverColor: _coverColorFor(id),
      status: 'New',
      filePath: filePath,
      fileBytes: fileBytes,
      coverBytes: coverBytes,
      createdAt: DateTime.now(),
    );
    _books.insert(0, book);
    await _persistBooks();
    await _syncGoalAchievements();
    notifyListeners();
    return book;
  }

  Book? bookById(String id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<void> updateProgress(
    String bookId,
    int currentPage,
    int totalPages,
  ) async {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index == -1) return;
    final progress = totalPages <= 0
        ? 0.0
        : (currentPage / totalPages).clamp(0.0, 1.0);
    _books[index] = _books[index].copyWith(
      progress: progress,
      currentPage: currentPage,
      totalPages: totalPages,
      status: progress >= 1
          ? 'Completed'
          : progress > 0
          ? 'In progress'
          : 'New',
      completedAt: progress >= 1
          ? (_books[index].completedAt ?? DateTime.now())
          : null,
    );
    await _persistBooks();
    await _syncGoalAchievements();
    notifyListeners();
  }

  Future<void> updatePdfBytes(String bookId, Uint8List bytes) async {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index == -1) return;
    final path = _books[index].filePath;
    if (kIsWeb && path != null && path.startsWith('browser-pdf:')) {
      await saveBrowserPdf(path.substring('browser-pdf:'.length), bytes);
    }
    _books[index] = _books[index].copyWith(fileBytes: bytes);
    await _persistBooks();
    notifyListeners();
  }

  Future<void> addSession({
    required Book book,
    required DateTime startedAt,
    required DateTime endedAt,
    required int startPage,
    required int endPage,
  }) async {
    final elapsedSeconds = endedAt.difference(startedAt).inSeconds;
    _sessions.insert(
      0,
      ReadingSessionRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: book.id,
        bookTitle: book.title,
        startedAt: startedAt,
        endedAt: endedAt,
        startPage: startPage,
        endPage: endPage,
        durationSeconds: elapsedSeconds < 0 ? 0 : elapsedSeconds,
      ),
    );
    await _persistSessions();
    await _syncGoalAchievements();
    notifyListeners();
  }

  Future<bool> toggleBookmark(String bookId, int page) async {
    final existingIndex = _bookmarks.indexWhere(
      (bookmark) => bookmark.bookId == bookId && bookmark.page == page,
    );
    if (existingIndex >= 0) {
      _bookmarks.removeAt(existingIndex);
      await _persistBookmarks();
      notifyListeners();
      return false;
    }
    _bookmarks.insert(
      0,
      ReadingBookmark(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: bookId,
        page: page,
        createdAt: DateTime.now(),
      ),
    );
    await _persistBookmarks();
    notifyListeners();
    return true;
  }

  Future<void> addNote({
    required String bookId,
    required int page,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    _notes.insert(
      0,
      ReadingNote(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: bookId,
        page: page,
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await _persistNotes();
    notifyListeners();
  }

  Future<void> addHighlight({
    required String bookId,
    required int page,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    _highlights.insert(
      0,
      ReadingHighlight(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: bookId,
        page: page,
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await _persistHighlights();
    notifyListeners();
  }

  List<ReadingBookmark> bookmarksFor(String bookId) =>
      _bookmarks.where((item) => item.bookId == bookId).toList();
  List<ReadingNote> notesFor(String bookId) =>
      _notes.where((item) => item.bookId == bookId).toList();
  List<ReadingHighlight> highlightsFor(String bookId) =>
      _highlights.where((item) => item.bookId == bookId).toList();

  bool hasAchievement(String achievement) {
    switch (achievement) {
      case 'First session':
        return totalSessions >= 1;
      case '7-day streak':
        return longestStreak >= 7;
      case '100 pages':
        return totalPages >= 100;
      case '10 sessions':
        return totalSessions >= 10;
      case '100 sessions':
        return totalSessions >= 100;
      case 'First book':
        return completedBookCount >= 1;
      case '1000 pages':
        return totalPages >= 1000;
      case '30-day streak':
        return longestStreak >= 30;
      case 'Bookworm':
        return completedBookCount >= 5;
      default:
        return false;
    }
  }

  Future<List<T>> _decodeList<T>(
    String key,
    T Function(Map<String, dynamic>) decoder,
  ) async {
    if (_preferences == null) return [];
    final raw = await _preferences!.getString(_scopedKey(key));
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values.whereType<Map<String, dynamic>>().map(decoder).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistBooks() async {
    // PDF files live in app documents on native and IndexedDB on web. Keep
    // only their stable path/key in SharedPreferences with the book metadata.
    final compactBooks = _books
        .map((item) => item.toJson(includeFileBytes: false))
        .toList();
    try {
      await _write(_booksKey, compactBooks);
    } catch (_) {
      // Recover from an older oversized reading_books entry. Removing only
      // this key frees the quota, then retries with compact metadata.
      try {
        await _preferences?.remove(_scopedKey(_booksKey));
        await _write(_booksKey, compactBooks);
      } catch (error) {
        throw StateError('Could not save the book details: $error');
      }
    }
  }

  Future<void> _persistSessions() =>
      _write(_sessionsKey, _sessions.map((item) => item.toJson()).toList());
  Future<void> _persistBookmarks() =>
      _write(_bookmarksKey, _bookmarks.map((item) => item.toJson()).toList());
  Future<void> _persistNotes() =>
      _write(_notesKey, _notes.map((item) => item.toJson()).toList());
  Future<void> _persistHighlights() =>
      _write(_highlightsKey, _highlights.map((item) => item.toJson()).toList());
  Future<void> _persistGoals() =>
      _write(_goalsKey, _goals.map((item) => item.toJson()).toList());
  Future<void> _persistGoalAchievements() =>
      _write(_goalAchievementsKey, _goalAchievements);

  Future<void> _syncGoalAchievements() async {
    final now = DateTime.now();
    final records =
        <({String id, String title, String period, int value, int target})>[
          (
            id: 'pages_daily',
            title: 'Read 20 pages daily',
            period: _periodKey('pagesPerDay', now),
            value: pagesReadOn(now),
            target: 20,
          ),
          (
            id: 'books_monthly',
            title: 'Finish 2 books this month',
            period: _periodKey('booksPerMonth', now),
            value: finishedBooksInMonth(now),
            target: 2,
          ),
          (
            id: 'days_weekly',
            title: 'Read on 5 days this week',
            period: _periodKey('readingDaysPerWeek', now),
            value: readingDaysInWeek(now),
            target: 5,
          ),
          (
            id: 'monthly_challenge',
            title: '${_monthLabel(now.month)} reading challenge',
            period: _periodKey('booksPerMonth', now),
            value: minutesReadInMonth(now),
            target: 600,
          ),
        ];
    for (final goal in _goals) {
      final value = switch (goal.metric) {
        'minutesPerDay' => minutesReadOn(now),
        'readingDaysPerWeek' => readingDaysInWeek(now),
        'booksPerMonth' => finishedBooksInMonth(now),
        _ => pagesReadOn(now),
      };
      records.add((
        id: goal.id,
        title: goal.title,
        period: _periodKey(goal.metric, now),
        value: value,
        target: goal.target,
      ));
    }
    var changed = false;
    for (final goal in records) {
      if (goal.value < goal.target ||
          hasGoalAchievement(goal.id, goal.period)) {
        continue;
      }
      _goalAchievements.insert(0, {
        'id': '${goal.id}:${goal.period}',
        'goalId': goal.id,
        'title': goal.title,
        'periodKey': goal.period,
        'subtitle': '${goal.value} / ${goal.target} completed',
        'completedAt': now.toIso8601String(),
      });
      changed = true;
    }
    if (changed) await _persistGoalAchievements();
  }

  String _periodKey(String metric, DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    if (metric == 'readingDaysPerWeek') {
      final monday = _dateOnly(date)
          .subtract(Duration(days: date.weekday - DateTime.monday));
      return '${monday.year}-${two(monday.month)}-${two(monday.day)}';
    }
    if (metric == 'booksPerMonth') return '${date.year}-${two(date.month)}';
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _monthLabel(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  Future<void> _write(String key, List<Map<String, dynamic>> value) async {
    await _ensurePreferences();
    await _preferences!.setString(_scopedKey(key), jsonEncode(value));
  }

  String _scopedKey(String key) =>
      userId == null || userId!.isEmpty ? key : '${key}_$userId';

  Future<void> _ensurePreferences() async {
    if (_preferences != null) return;
    _preferences = SharedPreferencesAsync();
  }

  String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Color _coverColorFor(String id) {
    const colors = [
      Color(0xFF314D46),
      Color(0xFFD28A5C),
      Color(0xFF7C6A9B),
      Color(0xFF567C9B),
    ];
    return colors[id.codeUnitAt(0) % colors.length];
  }

  int _calculateStreak() {
    final dates = _readingDates();
    if (dates.isEmpty) return 0;
    var streak = 0;
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (!dates.contains(today) && !dates.contains(yesterday)) return 0;
    var cursor = dates.contains(today) ? today : yesterday;
    while (dates.contains(_dateOnly(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calculateLongestStreak() {
    final dates = _readingDates().toList()..sort();
    if (dates.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    for (var index = 1; index < dates.length; index++) {
      if (dates[index].difference(dates[index - 1]).inDays == 1) {
        current++;
        longest = current > longest ? current : longest;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  Set<DateTime> _readingDates() =>
      _sessions.map((session) => _dateOnly(session.startedAt)).toSet();
  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  bool _isSameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;
}
