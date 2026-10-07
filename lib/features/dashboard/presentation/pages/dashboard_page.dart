import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_demo_app/core/widgets/app_widgets.dart';
import 'package:flutter_demo_app/data/repositories/local_reading_store.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.store,
    this.displayName,
    this.photoUrl,
    this.avatarBytes,
    required this.onStartReading,
    required this.onOpenLibrary,
  });

  final LocalReadingStore store;
  final String? displayName;
  final String? photoUrl;
  final Uint8List? avatarBytes;
  final VoidCallback onStartReading;
  final VoidCallback onOpenLibrary;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = widget.displayName?.trim();
    final greetingName = name == null || name.isEmpty ? 'Reader' : name;
    return AppPage(
      eyebrow: _formatDate(now),
      title: '${_greeting(now.hour)}, $greetingName',
      actions: [
        IconCircleButton(
          icon: Icons.notifications_none_rounded,
          onPressed: _showStreakReminder,
        ),
        const SizedBox(width: 10),
        UserAvatar(
          name: widget.displayName,
          photoUrl: widget.photoUrl,
          imageBytes: widget.avatarBytes,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakCard(
            store: widget.store,
            onStartReading: widget.onStartReading,
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Your reading rhythm',
            action: 'This week',
          ),
          const SizedBox(height: 12),
          _MetricGrid(store: widget.store),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Weekly activity', action: 'Last 7 days'),
          const SizedBox(height: 12),
          _WeeklyChart(store: widget.store),
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Continue reading',
            action: 'View library',
            onTap: widget.onOpenLibrary,
          ),
          const SizedBox(height: 12),
          _ContinueBook(
            store: widget.store,
            onStartReading: widget.onStartReading,
            onOpenLibrary: widget.onOpenLibrary,
          ),
        ],
      ),
    );
  }

  void _showStreakReminder() {
    final readToday = widget.store.readOn(DateTime.now());
    final streak = widget.store.currentStreak;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                readToday
                    ? Icons.check_circle_rounded
                    : Icons.local_fire_department_rounded,
                color: readToday ? ReadingColors.green : ReadingColors.forest,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                readToday ? 'Streak protected' : 'Keep your streak alive',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ReadingColors.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                readToday
                    ? 'You have read today. Your current streak is $streak ${streak == 1 ? 'day' : 'days'}. Nice work!'
                    : streak > 0
                    ? 'You have a $streak ${streak == 1 ? 'day' : 'days'} streak. Read a little today to keep it going.'
                    : 'A few minutes of reading today can start a new streak.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ReadingColors.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  if (!readToday) widget.onStartReading();
                },
                icon: Icon(
                  readToday ? Icons.done_rounded : Icons.menu_book_rounded,
                ),
                label: Text(readToday ? 'Done for today' : 'Start reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good evening';
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.store, required this.onStartReading});

  final LocalReadingStore store;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        const dailyGoalMinutes = 30;
        final streak = store.currentStreak;
        final minutesToday = store.minutesReadOn(DateTime.now());
        final progress = (minutesToday / dailyGoalMinutes).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ReadingColors.forest, Color(0xFF28634F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ReadingColors.forest.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      streak == 0
                          ? 'Start your reading streak today'
                          : 'Keep your $streak-day streak alive',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: ReadingColors.gold,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                streak == 0
                    ? 'Read today to begin a new streak.'
                    : 'A small session today keeps the habit growing.',
                style: const TextStyle(color: Color(0xFFD8E9E0), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: ProgressBar(value: progress, dark: true)),
                  const SizedBox(width: 12),
                  Text(
                    '$minutesToday / $dailyGoalMinutes min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStartReading,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start a reading session'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ReadingColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.store});

  final LocalReadingStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final metrics = [
          ReadingMetric(
            label: 'Reading time',
            value: _formatMinutes(store.totalMinutes),
            caption: store.totalMinutes == 0
                ? 'Start tracking'
                : 'Saved locally',
            icon: Icons.schedule_rounded,
          ),
          ReadingMetric(
            label: 'Pages read',
            value: '${store.totalPages}',
            caption: '${store.totalSessions} sessions',
            icon: Icons.auto_stories_rounded,
          ),
          ReadingMetric(
            label: 'Books finished',
            value: '${store.books.where((book) => book.progress >= 1).length}',
            caption: 'Imported locally',
            icon: Icons.check_circle_outline_rounded,
          ),
          ReadingMetric(
            label: 'Longest streak',
            value: '${store.longestStreak} days',
            caption: 'Personal best',
            icon: Icons.local_fire_department_outlined,
          ),
        ];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }

  String _formatMinutes(int minutes) =>
      minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ReadingMetric metric;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: ReadingColors.green, size: 19),
              const Spacer(),
              Flexible(
                child: Text(
                  metric.caption,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: ReadingColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            metric.value,
            style: const TextStyle(
              color: ReadingColors.forest,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            style: const TextStyle(
              color: ReadingColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.store});

  final LocalReadingStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final today = DateTime.now();
        final firstDay = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 6));
        final dates = List.generate(
          7,
          (index) => firstDay.add(Duration(days: index)),
        );
        final values = dates.map(store.minutesReadOn).toList();
        final maxValue = values.fold<int>(
          0,
          (max, value) => value > max ? value : max,
        );
        // A single short session should remain a short bar instead of
        // consuming the whole chart height when it is the week's only data.
        final scaleMax = maxValue < 30 ? 30 : maxValue;
        const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return AppSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Minutes read',
                    style: TextStyle(
                      color: ReadingColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const _Legend(),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              height: values[i] == 0
                                  ? 6
                                  : 6 +
                                        (values[i] / scaleMax).clamp(0, 1) *
                                            104,
                              width: 20,
                              decoration: BoxDecoration(
                                color: values[i] > 0
                                    ? ReadingColors.forest
                                    : const Color(0xFFB8D9C8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dayLabels[dates[i].weekday - 1],
                              style: TextStyle(
                                color: values[i] > 0
                                    ? ReadingColors.forest
                                    : const Color(0xFF929B95),
                                fontSize: 11,
                                fontWeight: values[i] > 0
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              values[i] == 0 ? '—' : '${values[i]}m',
                              style: const TextStyle(
                                color: ReadingColors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: ReadingColors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'This week',
          style: TextStyle(color: ReadingColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ContinueBook extends StatelessWidget {
  const _ContinueBook({
    required this.store,
    required this.onStartReading,
    required this.onOpenLibrary,
  });

  final LocalReadingStore store;
  final VoidCallback onStartReading;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final book = store.books.isEmpty ? null : store.books.first;
    if (book == null) {
      return AppSurface(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: ReadingColors.paleGreen,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: ReadingColors.green,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Import a PDF to start your reading journey.',
                style: TextStyle(
                  color: ReadingColors.forest,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            IconCircleButton(
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpenLibrary,
              filled: true,
            ),
          ],
        ),
      );
    }
    return AppSurface(
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${book.author}  ·  ${book.progressLabel} complete',
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ProgressBar(value: book.progress),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconCircleButton(
            icon: Icons.arrow_forward_rounded,
            onPressed: onStartReading,
            filled: true,
          ),
        ],
      ),
    );
  }
}
