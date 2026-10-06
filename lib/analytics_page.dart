import 'package:flutter/material.dart';

import 'app_widgets.dart';
import 'local_reading_store.dart';
import 'reading_models.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.store});

  final LocalReadingStore store;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _range = 'Last 7 days';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final rangeDays = switch (_range) {
          'Last 7 days' => 7,
          'Last 30 days' => 30,
          _ => null,
        };
        final rangeStart = rangeDays == null
            ? null
            : todayOnly.subtract(Duration(days: rangeDays - 1));
        final sessions = _range == 'All time'
            ? store.sessions
            : store.sessions
                  .where((session) => !session.startedAt.isBefore(rangeStart!))
                  .toList();
        final totalMinutes = sessions.fold<int>(
          0,
          (total, session) => total + session.durationMinutes,
        );
        final totalPages = sessions.fold<int>(
          0,
          (total, session) => total + session.pagesRead,
        );
        final averageMinutes = sessions.isEmpty
            ? 0
            : (totalMinutes / sessions.length).round();
        final readingDays = sessions
            .map((session) => _dateKey(session.startedAt.toLocal()))
            .toSet()
            .length;
        final completedBooks = store.books.where((book) {
          if (book.status != 'Completed') return false;
          final completedAt = book.completedAt ?? book.createdAt;
          return completedAt != null &&
              (rangeStart == null || !completedAt.isBefore(rangeStart));
        }).length;
        final timeOfDay = _mostActiveTime(sessions);
        final bestDay = _mostActiveDay(sessions);
        final comparisonDays = rangeDays ?? 30;
        final trend = _comparePeriods(store.sessions, todayOnly, comparisonDays);
        final chartValues = _buildChartValues(sessions, today);
        return AppPage(
          eyebrow: 'Your patterns',
          title: 'Analytics',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore your reading',
                style: TextStyle(
                  color: ReadingColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in [
                    'Last 7 days',
                    'Last 30 days',
                    'All time',
                  ])
                    ChoiceChip(
                      label: Text(option),
                      selected: _range == option,
                      onSelected: (_) => setState(() => _range = option),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              AppSurface(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL READING TIME',
                                style: TextStyle(
                                  color: ReadingColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatMinutes(totalMinutes),
                                style: const TextStyle(
                                  color: ReadingColors.forest,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.insights_rounded,
                          color: ReadingColors.green,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _range == 'All time'
                          ? 'Across all saved reading sessions'
                          : '$_range · ${_formatDateRange(rangeStart!, todayOnly)}',
                      style: TextStyle(
                        color: ReadingColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TrendPill(
                      text: _trendLabel(trend, comparisonDays),
                      improved: trend.$1 >= trend.$2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: chartValues.isEmpty
                          ? const _EmptyChart()
                          : CustomPaint(
                              painter: _LineChartPainter(chartValues),
                            ),
                    ),
                    const SizedBox(height: 6),
                    _ChartDateLabels(
                      first: sessions.isEmpty
                          ? null
                          : _formatShortDate(
                              _range == 'All time'
                                  ? sessions
                                      .map((item) => item.startedAt)
                                      .reduce((a, b) => a.isBefore(b) ? a : b)
                                  : rangeStart!,
                            ),
                      last: _formatShortDate(todayOnly),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _AnalyticsMiniCard(
                    label: 'Sessions',
                    value: '${sessions.length}',
                    icon: Icons.play_circle_outline_rounded,
                  ),
                  _AnalyticsMiniCard(
                    label: 'Pages read',
                    value: '$totalPages',
                    icon: Icons.auto_stories_rounded,
                  ),
                  _AnalyticsMiniCard(
                    label: 'Avg. session',
                    value: '$averageMinutes min',
                    icon: Icons.timelapse_rounded,
                  ),
                  _AnalyticsMiniCard(
                    label: 'Books completed',
                    value: '$completedBooks',
                    icon: Icons.task_alt_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeading(
                title: 'What your data says',
                action: 'Based on your sessions',
              ),
              const SizedBox(height: 12),
              _InsightRow(
                icon: Icons.schedule_rounded,
                title: 'Most active time',
                value: timeOfDay ?? 'Not enough data yet',
                detail: timeOfDay == null
                    ? 'Complete a session to see when you read most.'
                    : 'Calculated from the start times of ${sessions.length} saved sessions.',
              ),
              _InsightRow(
                icon: Icons.auto_stories_rounded,
                title: 'Average pace',
                value: sessions.isEmpty
                    ? 'No pages yet'
                    : '${(totalPages / sessions.length).toStringAsFixed(1)} pages / session',
                detail: 'Total pages read divided by completed sessions.',
              ),
              _InsightRow(
                icon: Icons.local_fire_department_outlined,
                title: 'Reading consistency',
                value: '$readingDays ${readingDays == 1 ? 'day' : 'days'} active',
                detail: bestDay == null
                    ? 'Your busiest weekday will appear after you log more sessions.'
                    : 'You read most on $bestDay in this period.',
              ),
              _InsightRow(
                icon: Icons.local_fire_department_outlined,
                title: 'Current streak',
                value: '${store.currentStreak} ${store.currentStreak == 1 ? 'day' : 'days'}',
                detail: 'Consecutive calendar days, based on saved sessions.',
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMinutes(int minutes) =>
      minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  String? _mostActiveTime(List<ReadingSessionRecord> sessions) {
    if (sessions.isEmpty) return null;
    const periods = ['Early morning', 'Morning', 'Afternoon', 'Evening', 'Night'];
    final totals = List<int>.filled(periods.length, 0);
    for (final session in sessions) {
      final hour = session.startedAt.toLocal().hour;
      final index = hour < 5
          ? 0
          : hour < 12
          ? 1
          : hour < 17
          ? 2
          : hour < 22
          ? 3
          : 4;
      totals[index] += session.durationMinutes;
    }
    var best = 0;
    for (var i = 1; i < totals.length; i++) {
      if (totals[i] > totals[best]) best = i;
    }
    return totals[best] == 0 ? null : periods[best];
  }

  String? _mostActiveDay(List<ReadingSessionRecord> sessions) {
    if (sessions.isEmpty) return null;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final totals = List<int>.filled(7, 0);
    for (final session in sessions) {
      totals[session.startedAt.toLocal().weekday - 1] += session.durationMinutes;
    }
    var best = 0;
    for (var i = 1; i < totals.length; i++) {
      if (totals[i] > totals[best]) best = i;
    }
    return days[best];
  }

  (int, int) _comparePeriods(
    List<ReadingSessionRecord> sessions,
    DateTime today,
    int days,
  ) {
    final end = today.add(const Duration(days: 1));
    final recentStart = end.subtract(Duration(days: days));
    final previousStart = recentStart.subtract(Duration(days: days));
    int minutesBetween(DateTime start, DateTime finish) => sessions
        .where((session) {
          final time = session.startedAt.toLocal();
          return !time.isBefore(start) && time.isBefore(finish);
        })
        .fold(0, (total, session) => total + session.durationMinutes);
    return (
      minutesBetween(recentStart, end),
      minutesBetween(previousStart, recentStart),
    );
  }

  String _trendLabel((int, int) trend, int days) {
    final current = trend.$1;
    final previous = trend.$2;
    if (previous == 0) {
      return current == 0
          ? 'No reading activity in the last $days days'
          : 'Reading started in the last $days days';
    }
    final difference = current - previous;
    final percent = (difference.abs() * 100 / previous).round();
    if (difference == 0) return 'Same reading time as the previous $days days';
    return '${difference > 0 ? '↑' : '↓'} $percent% vs previous $days days';
  }

  String _formatDateRange(DateTime start, DateTime end) =>
      '${_formatShortDate(start)} – ${_formatShortDate(end)}';

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  List<double> _buildChartValues(
    List<ReadingSessionRecord> sessions,
    DateTime today,
  ) {
    if (sessions.isEmpty) return const [];
    final todayLocal = DateTime(today.year, today.month, today.day);
    final isAllTime = _range == 'All time';
    final DateTime start;
    final int bucketCount;
    if (_range == 'Last 7 days') {
      start = todayLocal.subtract(const Duration(days: 6));
      bucketCount = 7;
    } else if (_range == 'Last 30 days') {
      start = todayLocal.subtract(const Duration(days: 29));
      bucketCount = 30;
    } else {
      final first = sessions
          .map((item) => item.startedAt.toLocal())
          .reduce((a, b) => a.isBefore(b) ? a : b);
      start = DateTime(first.year, first.month, 1);
      bucketCount =
          (todayLocal.year - start.year) * 12 + todayLocal.month - start.month + 1;
    }

    final values = List<double>.filled(bucketCount.clamp(1, 1200), 0);
    for (final session in sessions) {
      final localStart = session.startedAt.toLocal();
      final int index;
      if (isAllTime) {
        index = (localStart.year - start.year) * 12 +
            localStart.month -
            start.month;
      } else {
        final day = DateTime(localStart.year, localStart.month, localStart.day);
        index = day.difference(start).inDays;
      }
      if (index < 0 || index >= values.length) continue;
      values[index] += session.durationMinutes.toDouble();
    }
    return values;
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.text, required this.improved});

  final String text;
  final bool improved;

  @override
  Widget build(BuildContext context) {
    final color = improved ? const Color(0xFF267653) : const Color(0xFFAD5B4B);
    final background = improved
        ? const Color(0xFFEAF5EE)
        : const Color(0xFFFFF0EC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            improved ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartDateLabels extends StatelessWidget {
  const _ChartDateLabels({required this.first, required this.last});

  final String? first;
  final String last;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          first ?? 'No sessions yet',
          style: const TextStyle(color: ReadingColors.textMuted, fontSize: 10),
        ),
        const Text(
          'Reading minutes',
          style: TextStyle(color: ReadingColors.textMuted, fontSize: 10),
        ),
        Text(
          last,
          style: const TextStyle(color: ReadingColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _AnalyticsMiniCard extends StatelessWidget {
  const _AnalyticsMiniCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: ReadingColors.green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ReadingColors.forest,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: ReadingColors.paleGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ReadingColors.green, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ReadingColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: ReadingColors.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: ReadingColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Your reading trend will appear here',
      style: TextStyle(color: ReadingColors.textMuted, fontSize: 13),
    ),
  );
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EFEB)
      ..strokeWidth = 1;
    const horizontalPadding = 8.0;
    const verticalPadding = 12.0;
    final plotWidth = (size.width - horizontalPadding * 2).clamp(
      0.0,
      double.infinity,
    );
    final plotHeight = size.height - verticalPadding * 2;
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final scaleMax = maxValue == 0 ? 1.0 : maxValue;
    final points = List.generate(values.length, (index) {
      final x = values.length == 1
          ? size.width / 2
          : horizontalPadding + plotWidth * index / (values.length - 1);
      final y = verticalPadding + plotHeight * (1 - values[index] / scaleMax);
      return Offset(x, y);
    });
    for (var i = 0; i < 4; i++) {
      final y = verticalPadding + plotHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (points.length == 1) {
      canvas.drawCircle(
        points.single,
        4,
        Paint()..color = ReadingColors.forest,
      );
      return;
    }
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(points[i].dx, points[i].dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x444A957B), Color(0x084A957B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = ReadingColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dotPaint = Paint()..color = ReadingColors.forest;
    for (var index = 0; index < points.length; index++) {
      if (values[index] > 0) canvas.drawCircle(points[index], 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
