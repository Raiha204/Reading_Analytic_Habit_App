import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ReadingColors {
  static const forest = Color(0xFF173D30);
  static const green = Color(0xFF4A957B);
  static const paleGreen = Color(0xFFE9F3ED);
  static const textMuted = Color(0xFF758079);
  static const gold = Color(0xFFE7B86B);
}

class Book {
  const Book({
    this.id = '',
    required this.title,
    required this.author,
    required this.progress,
    required this.coverColor,
    required this.status,
    this.filePath,
    this.fileBytes,
    this.coverBytes,
    this.totalPages = 0,
    this.currentPage = 1,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String author;
  final double progress;
  final Color coverColor;
  final String status;
  final String? filePath;
  final Uint8List? fileBytes;
  final Uint8List? coverBytes;
  final int totalPages;
  final int currentPage;
  final DateTime? createdAt;
  final DateTime? completedAt;

  String get progressLabel => '${(progress * 100).round()}%';
  bool get isImported => filePath != null || fileBytes != null;
  bool get hasPdfSource => fileBytes != null || filePath != null;

  Book copyWith({
    double? progress,
    int? currentPage,
    int? totalPages,
    Uint8List? fileBytes,
    Uint8List? coverBytes,
    String? status,
    DateTime? completedAt,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      progress: progress ?? this.progress,
      coverColor: coverColor,
      status: status ?? this.status,
      filePath: filePath,
      fileBytes: fileBytes ?? this.fileBytes,
      coverBytes: coverBytes ?? this.coverBytes,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson({
    bool includeFileBytes = true,
    bool includeCoverBytes = true,
  }) => {
    'id': id,
    'title': title,
    'author': author,
    'progress': progress,
    'coverColor': coverColor.toARGB32(),
    'status': status,
    'filePath': filePath,
    'fileBytes': !includeFileBytes || fileBytes == null
        ? null
        : base64Encode(fileBytes!),
    'coverBytes':
        !includeCoverBytes || coverBytes == null || coverBytes!.length > 300000
        ? null
        : base64Encode(coverBytes!),
    'totalPages': totalPages,
    'currentPage': currentPage,
    'createdAt': createdAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Imported PDF',
      author: json['author'] as String? ?? 'Imported PDF',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      coverColor: Color((json['coverColor'] as num?)?.toInt() ?? 0xFF567C9B),
      status: json['status'] as String? ?? 'New',
      filePath: json['filePath'] as String?,
      fileBytes: _decodeBytes(json['fileBytes'] as String?),
      coverBytes: _decodeBytes(json['coverBytes'] as String?),
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }

  static Uint8List? _decodeBytes(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  bool matches(String query, String filter) {
    final matchesQuery = title.toLowerCase().contains(query.toLowerCase());
    final matchesFilter = filter == 'All books' || status == filter;
    return matchesQuery && matchesFilter;
  }
}

class ReadingSessionRecord {
  const ReadingSessionRecord({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.startedAt,
    required this.endedAt,
    required this.startPage,
    required this.endPage,
    this.durationSeconds,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime startedAt;
  final DateTime endedAt;
  final int startPage;
  final int endPage;
  final int? durationSeconds;

  int get elapsedSeconds =>
      durationSeconds ??
      endedAt.difference(startedAt).inSeconds.clamp(0, 24 * 60 * 60);
  int get durationMinutes => (elapsedSeconds / 60).ceil().clamp(1, 24 * 60);
  String get durationLabel {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

  int get pagesRead => (endPage - startPage).clamp(0, 100000);

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'bookTitle': bookTitle,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'startPage': startPage,
    'endPage': endPage,
    'durationSeconds': durationSeconds,
  };

  factory ReadingSessionRecord.fromJson(Map<String, dynamic> json) {
    return ReadingSessionRecord(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? 'Reading session',
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt:
          DateTime.tryParse(json['endedAt'] as String? ?? '') ?? DateTime.now(),
      startPage: (json['startPage'] as num?)?.toInt() ?? 1,
      endPage: (json['endPage'] as num?)?.toInt() ?? 1,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }
}

class ReadingBookmark {
  const ReadingBookmark({
    required this.id,
    required this.bookId,
    required this.page,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int page;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'page': page,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReadingBookmark.fromJson(Map<String, dynamic> json) =>
      ReadingBookmark(
        id: json['id'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        page: (json['page'] as num?)?.toInt() ?? 1,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class ReadingNote {
  const ReadingNote({
    required this.id,
    required this.bookId,
    required this.page,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int page;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'page': page,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReadingNote.fromJson(Map<String, dynamic> json) => ReadingNote(
    id: json['id'] as String? ?? '',
    bookId: json['bookId'] as String? ?? '',
    page: (json['page'] as num?)?.toInt() ?? 1,
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class ReadingHighlight {
  const ReadingHighlight({
    required this.id,
    required this.bookId,
    required this.page,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int page;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'page': page,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReadingHighlight.fromJson(Map<String, dynamic> json) =>
      ReadingHighlight(
        id: json['id'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        page: (json['page'] as num?)?.toInt() ?? 1,
        text: json['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class ReadingMetric {
  const ReadingMetric({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

class ReadingGoalDefinition {
  const ReadingGoalDefinition({
    required this.id,
    required this.metric,
    required this.title,
    required this.target,
    required this.createdAt,
  });

  final String id;
  final String metric;
  final String title;
  final int target;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'metric': metric,
    'title': title,
    'target': target,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReadingGoalDefinition.fromJson(Map<String, dynamic> json) {
    return ReadingGoalDefinition(
      id: json['id'] as String? ?? '',
      metric: json['metric'] as String? ?? 'pagesPerDay',
      title: json['title'] as String? ?? 'Reading goal',
      target: (json['target'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ReadingGoal {
  const ReadingGoal({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;
}

class Achievement {
  const Achievement({
    required this.symbol,
    required this.title,
    required this.unlocked,
    this.description = '',
    this.progress = 0,
    this.target = 1,
  });

  final String symbol;
  final String title;
  final bool unlocked;
  final String description;
  final int progress;
  final int target;
}
