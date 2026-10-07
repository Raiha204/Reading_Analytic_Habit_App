import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:flutter_demo_app/data/repositories/local_reading_store.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.store,
    required this.book,
    required this.isReading,
    required this.onStartReading,
    required this.onOpenBook,
    required this.onImportPdf,
    required this.onEndReading,
    required this.onAchievement,
  });

  final LocalReadingStore store;
  final Book? book;
  final bool isReading;
  final VoidCallback onStartReading;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback onImportPdf;
  final VoidCallback onEndReading;
  final ValueChanged<String> onAchievement;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  DateTime? _sessionStartedAt;
  Timer? _elapsedTimer;
  int _sessionStartPage = 1;
  String _selectedText = '';
  String? _pdfLoadError;
  Future<Uint8List>? _pdfBytesFuture;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _highlightModeEnabled = false;
  bool _readerChromeVisible = true;

  Book? get _book => widget.book;
  String get _bookId => _book?.id.isNotEmpty == true
      ? _book!.id
      : 'demo-${_book?.title ?? 'reader'}';
  bool get _hasPdf =>
      _book?.fileBytes != null ||
      (!kIsWeb &&
          _book?.filePath != null &&
          File(_book!.filePath!).existsSync());

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book?.currentPage ?? 1;
    _sessionStartPage = _currentPage;
    _preparePdfSource();
    if (widget.isReading) _startSession();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isReading && widget.isReading) _startSession();
    if (oldWidget.book?.id != widget.book?.id) {
      _readerChromeVisible = true;
      _currentPage = widget.book?.currentPage ?? 1;
      _sessionStartPage = _currentPage;
      _totalPages = widget.book?.totalPages ?? 0;
      _selectedText = '';
      _pdfLoadError = null;
      _preparePdfSource();
    }
  }

  void _preparePdfSource() {
    final book = widget.book;
    if (book?.fileBytes != null) {
      _pdfBytesFuture = Future.value(book!.fileBytes);
    } else if (!kIsWeb && book?.filePath != null) {
      _pdfBytesFuture = File(book!.filePath!).readAsBytes();
    } else {
      _pdfBytesFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD8D4CD),
      child: Column(
        children: [
          if (_readerChromeVisible) ...[_buildHeader(), _buildToolbar()],
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _readerChromeVisible ? null : _showReaderChrome,
              onDoubleTap: _readerChromeVisible
                  ? _hideReaderChrome
                  : _showReaderChrome,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _hasPdf
                      ? _buildPdfViewer()
                      : _ReaderSurface(
                          books: widget.store.books,
                          onOpenBook: widget.onOpenBook,
                          onImportPdf: widget.onImportPdf,
                        ),
                ],
              ),
            ),
          ),
          if (widget.isReading && _readerChromeVisible) _buildSessionBar(),
        ],
      ),
    );
  }

  void _hideReaderChrome() {
    if (!_readerChromeVisible || !mounted) return;
    setState(() => _readerChromeVisible = false);
  }

  void _showReaderChrome() {
    if (_readerChromeVisible || !mounted) return;
    setState(() => _readerChromeVisible = true);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.isReading ? _finishSession : null,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF3A403E),
            ),
          ),
          Expanded(
            child: Text(
              _book?.title ?? 'Ready to read?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3A403E),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_totalPages > 0)
            Text(
              '$_currentPage / $_totalPages',
              style: const TextStyle(
                color: Color(0xFF656A67),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          IconButton(
            tooltip: 'Hide reading controls',
            onPressed: _hideReaderChrome,
            icon: const Icon(
              Icons.visibility_off_rounded,
              color: Color(0xFF3A403E),
            ),
          ),
          IconButton(
            onPressed: _showReaderOptions,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF3A403E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ReaderAction(
            icon: _isCurrentPageBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_add_outlined,
            label: _isCurrentPageBookmarked ? 'Bookmarked' : 'Bookmark',
            onPressed: _saveBookmark,
          ),
          _ReaderAction(
            icon: Icons.note_add_outlined,
            label: 'Note',
            onPressed: _addNote,
          ),
          _ReaderAction(
            icon: _highlightModeEnabled
                ? Icons.highlight_rounded
                : Icons.highlight_alt_outlined,
            label: _highlightModeEnabled ? 'Select text' : 'Highlight',
            onPressed: _enableHighlight,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.swipe_vertical_rounded,
              color: Color(0xFF777A77),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final pdfBytesFuture = _pdfBytesFuture;
    if (pdfBytesFuture == null) {
      return const _ReaderError(message: 'No PDF source is available.');
    }
    if (_pdfLoadError != null) return _ReaderError(message: _pdfLoadError!);
    return FutureBuilder<Uint8List>(
      future: pdfBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF168CC4)),
          );
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const _ReaderError(
            message:
                'This PDF could not be read. Try importing the file again.',
          );
        }
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF168CC4),
              primary: const Color(0xFF168CC4),
            ),
          ),
          child: SfPdfViewer.memory(
            snapshot.data!,
            controller: _pdfController,
            pageSpacing: 10,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            canShowPaginationDialog: false,
            scrollDirection: PdfScrollDirection.vertical,
            pageLayoutMode: PdfPageLayoutMode.continuous,
            interactionMode: PdfInteractionMode.selection,
            onDocumentLoaded: _handleDocumentLoaded,
            onDocumentLoadFailed: (details) {
              if (mounted) {
                setState(
                  () => _pdfLoadError =
                      '${details.error}: ${details.description}',
                );
              }
            },
            onPageChanged: _handlePageChanged,
            onTextSelectionChanged: _handleTextSelectionChanged,
            onAnnotationAdded: (_) => _handleAnnotationAdded(),
            onAnnotationRemoved: (_) => _savePdf(),
          ),
        );
      },
    );
  }

  void _handleDocumentLoaded(PdfDocumentLoadedDetails details) {
    _totalPages = details.document.pages.count;
    if ((_book?.currentPage ?? 1) > 1) {
      _pdfController.jumpToPage(_book!.currentPage);
    }
    if (mounted) setState(() {});
  }

  void _handlePageChanged(PdfPageChangedDetails details) {
    _currentPage = details.newPageNumber;
    widget.store.updateProgress(_bookId, _currentPage, _totalPages);
    if (mounted) setState(() {});
  }

  void _handleTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    _selectedText = details.selectedText ?? '';
  }

  Future<void> _handleAnnotationAdded() async {
    final selectedText = _selectedText.trim();
    if (selectedText.isNotEmpty) {
      await widget.store.addHighlight(
        bookId: _bookId,
        page: _currentPage,
        text: selectedText,
      );
      _selectedText = '';
      if (mounted) {
        setState(() {
          _highlightModeEnabled = false;
        });
      }
      _showSnack('Highlight saved on page $_currentPage');
    } else if (mounted) {
      _showSnack('Select text before applying a highlight');
    }
    await _savePdf();
  }

  Widget _buildSessionBar() {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: ReadingColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _sessionStartedAt == null
                      ? 'Session ready'
                      : '${_formatDuration(DateTime.now().difference(_sessionStartedAt!))} elapsed',
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSession() {
    if (_sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      _sessionStartPage = _currentPage;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _finishSession() async {
    final book = _book;
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      widget.onEndReading();
      return;
    }
    final hadFirstSession = widget.store.hasAchievement('First session');
    final endedAt = DateTime.now();
    _sessionStartedAt = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    if (book != null) {
      await widget.store.addSession(
        book: book,
        startedAt: startedAt,
        endedAt: endedAt,
        startPage: _sessionStartPage,
        endPage: _currentPage,
      );
      if (!hadFirstSession) widget.onAchievement('First reading session');
    }
    widget.onEndReading();
  }

  Future<void> _saveBookmark() async {
    final added = await widget.store.toggleBookmark(_bookId, _currentPage);
    if (mounted) setState(() {});
    _showSnack(
      added ? 'Bookmark saved on page $_currentPage' : 'Bookmark removed',
    );
  }

  Future<void> _showReaderOptions() async {
    final book = _book;
    if (book == null) {
      _showSnack('Open a book to view its bookmarks and notes.');
      return;
    }
    final bookmarks = widget.store.bookmarksFor(_bookId);
    final notes = widget.store.notesFor(_bookId);
    final targetPage = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Bookmarks and notes')),
            if (bookmarks.isEmpty && notes.isEmpty)
              const ListTile(title: Text('No bookmarks or notes yet.')),
            for (final bookmark in bookmarks)
              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded),
                title: Text('Bookmark · page ${bookmark.page}'),
                onTap: () => Navigator.pop(context, bookmark.page),
              ),
            for (final note in notes)
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text('Note · page ${note.page}'),
                subtitle: Text(
                  note.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, note.page),
              ),
          ],
        ),
      ),
    );
    if (targetPage != null && _hasPdf && mounted) {
      _pdfController.jumpToPage(targetPage);
    }
  }

  Future<void> _addNote() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _NoteEditorDialog(page: _currentPage),
    );
    if (text != null && text.trim().isNotEmpty) {
      await widget.store.addNote(
        bookId: _bookId,
        page: _currentPage,
        text: text,
      );
      if (mounted) setState(() {});
      _showSnack('Note saved on page $_currentPage');
    }
  }

  void _enableHighlight() {
    if (!_hasPdf) {
      _showSnack('Import a PDF to highlight text');
      return;
    }
    _pdfController.annotationMode = PdfAnnotationMode.highlight;
    if (mounted) {
      setState(() {
        _highlightModeEnabled = true;
      });
    }
    _showSnack('Select text in the PDF to highlight it');
  }

  Future<void> _savePdf() async {
    if (!_hasPdf) return;
    final bytes = await _pdfController.saveDocument();
    if (!kIsWeb && _book!.filePath != null) {
      await File(_book!.filePath!).writeAsBytes(bytes, flush: true);
    } else {
      await widget.store.updatePdfBytes(_bookId, Uint8List.fromList(bytes));
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

  bool get _isCurrentPageBookmarked => widget.store
      .bookmarksFor(_bookId)
      .any((bookmark) => bookmark.page == _currentPage);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.page});

  final int page;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Note for page ${widget.page}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Write a thought about this page...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save note'),
        ),
      ],
    );
  }
}

class _ReaderAction extends StatelessWidget {
  const _ReaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ReaderSurface extends StatelessWidget {
  const _ReaderSurface({
    required this.books,
    required this.onOpenBook,
    required this.onImportPdf,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback onImportPdf;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 330),
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7ED),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8E1D2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'READWISE DEMO READER',
              style: TextStyle(
                color: Color(0xFFAD7959),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Choose a book\nto start reading',
              style: TextStyle(
                color: Color(0xFF273C35),
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16),
            Text(
              books.isEmpty
                  ? 'Import a PDF and it will open here with page navigation, notes, bookmarks, and reading-session tracking.'
                  : 'Continue where you left off, or choose another book from your library.',
              style: TextStyle(
                color: Color(0xFF53645D),
                fontSize: 16,
                height: 1.65,
              ),
            ),
            SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImportPdf,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF174637),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
            if (books.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'Your library',
                style: TextStyle(
                  color: Color(0xFF273C35),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              for (final book in books.take(4))
                _ReaderBookChoice(book: book, onTap: () => onOpenBook(book)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReaderBookChoice extends StatelessWidget {
  const _ReaderBookChoice({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF4A957B)),
    title: Text(
      book.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF273C35),
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text('${(book.progress * 100).round()}% complete'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 42,
              color: Color(0xFF777A77),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to display this PDF',
              style: TextStyle(
                color: Color(0xFF3A403E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF656A67), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
