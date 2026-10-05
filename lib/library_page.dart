import 'package:flutter/material.dart';

import 'app_widgets.dart';
import 'local_reading_store.dart';
import 'reading_models.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.store,
    required this.onOpenBook,
    required this.onImportPdf,
  });

  final LocalReadingStore store;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback onImportPdf;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _searchController = TextEditingController();
  String _filter = 'All books';
  String _sort = 'Recently added';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final allBooks = widget.store.books;
        final books = allBooks
            .where((book) => book.matches(_searchController.text, _filter))
            .toList();
        books.sort((first, second) {
          switch (_sort) {
            case 'Title A–Z':
              return first.title.toLowerCase().compareTo(
                second.title.toLowerCase(),
              );
            case 'Progress':
              return second.progress.compareTo(first.progress);
            default:
              return (second.createdAt ?? DateTime(0)).compareTo(
                first.createdAt ?? DateTime(0),
              );
          }
        });
        return AppPage(
          eyebrow: 'Your collection',
          title: 'Library',
          actions: [
            IconCircleButton(
              icon: Icons.upload_file_rounded,
              onPressed: widget.onImportPdf,
            ),
            const SizedBox(width: 10),
            IconCircleButton(
              icon: Icons.tune_rounded,
              onPressed: _showSortOptions,
            ),
          ],
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search your books',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 14),
              _FilterChips(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${books.length} books',
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (books.isEmpty)
                _EmptyLibrary(
                  onImportPdf: widget.onImportPdf,
                  hasSearch:
                      _searchController.text.isNotEmpty ||
                      _filter != 'All books',
                )
              else
                for (final book in books)
                  _BookListTile(book: book, onOpenBook: widget.onOpenBook),
            ],
          ),
        );
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  Future<void> _showSortOptions() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sort books')),
            for (final option in ['Recently added', 'Title A–Z', 'Progress'])
              ListTile(
                title: Text(option),
                trailing: _sort == option ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImportPdf, required this.hasSearch});

  final VoidCallback onImportPdf;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: ReadingColors.paleGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 32,
              color: ReadingColors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No books match your search' : 'Your library is empty',
            style: const TextStyle(
              color: ReadingColors.forest,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            hasSearch
                ? 'Try another title or clear the filters.'
                : 'Import a PDF and your reading collection will appear here.',
            style: const TextStyle(
              color: ReadingColors.textMuted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onImportPdf,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import a PDF'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = ['All books', 'In progress', 'Completed', 'New'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.book, required this.onOpenBook});

  final Book book;
  final ValueChanged<Book> onOpenBook;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            BookCover(book: book),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: ReadingColors.forest,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: const TextStyle(
                      color: ReadingColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: ProgressBar(value: book.progress)),
                      const SizedBox(width: 9),
                      Text(
                        book.progressLabel,
                        style: const TextStyle(
                          color: ReadingColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () => onOpenBook(book),
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: ReadingColors.forest,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
