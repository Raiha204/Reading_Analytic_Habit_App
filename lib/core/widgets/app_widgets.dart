import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:flutter_demo_app/domain/models/reading_models.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 700 ? 56.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              style: const TextStyle(
                                color: ReadingColors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: ReadingColors.forest,
                                fontSize: 31,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? ReadingColors.forest : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: filled ? Colors.white : ReadingColors.forest,
          ),
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.large = false,
    this.photoUrl,
    this.name,
    this.imageBytes,
  });

  final bool large;
  final String? photoUrl;
  final String? name;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final size = large ? 68.0 : 44.0;
    final trimmedName = name?.trim() ?? '';
    final initial = trimmedName.isEmpty ? 'R' : trimmedName[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFDCEEE5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: imageBytes != null
          ? ClipOval(
              child: Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(initial, large),
              ),
            )
          : photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: const Color(0xFF28634F),
                  fontSize: large ? 24 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(initial, large),
              ),
            ),
    );
  }

  Widget _initial(String initial, bool large) => Center(
    child: Text(
      initial,
      style: TextStyle(
        color: const Color(0xFF28634F),
        fontSize: large ? 24 : 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({
    super.key,
    this.message = 'Getting your reading space ready…',
  });

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8F5),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/readwise_logo.png', width: 76, height: 76),
          const SizedBox(height: 18),
          const Text(
            'READWISE',
            style: TextStyle(
              color: ReadingColors.forest,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: ReadingColors.green,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: ReadingColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 62,
    this.height = 82,
  });

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: book.coverColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: book.coverBytes == null
          ? Center(
              child: Text(
                book.title.replaceAll(' ', '\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.memory(
                book.coverBytes!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    book.title.replaceAll(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.action,
    this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ReadingColors.forest,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              action,
              style: const TextStyle(
                color: ReadingColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.dark = false});

  final double value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 7,
        backgroundColor: dark
            ? const Color(0xFF4E7565)
            : const Color(0xFFE7EEE9),
        valueColor: AlwaysStoppedAnimation(
          dark ? ReadingColors.gold : ReadingColors.green,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: Color(0xFF9BA9A0),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: ReadingColors.forest,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: ReadingColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 8,
            backgroundColor: const Color(0xFF4E7565),
            valueColor: const AlwaysStoppedAnimation(ReadingColors.gold),
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
