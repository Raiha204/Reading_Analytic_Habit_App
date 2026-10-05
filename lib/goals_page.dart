import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_widgets.dart';
import 'local_reading_store.dart';
import 'reading_models.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key, required this.store});

  final LocalReadingStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        const monthlyTargetMinutes = 10 * 60;
        final monthlyMinutes = store.minutesReadInMonth(now);
        final monthlyProgress = _progress(monthlyMinutes, monthlyTargetMinutes);
        final goals = [
          _GoalSnapshot(
            id: 'pages_daily',
            periodMetric: 'pagesPerDay',
            title: 'Read 20 pages daily',
            subtitle: '${store.pagesReadOn(now)} / 20 pages today',
            progress: _progress(store.pagesReadOn(now), 20),
            icon: Icons.auto_stories_rounded,
          ),
          _GoalSnapshot(
            id: 'books_monthly',
            periodMetric: 'booksPerMonth',
            title: 'Finish 2 books this month',
            subtitle: '${store.finishedBooksInMonth(now)} / 2 complete',
            progress: _progress(store.finishedBooksInMonth(now), 2),
            icon: Icons.flag_rounded,
          ),
          _GoalSnapshot(
            id: 'days_weekly',
            periodMetric: 'readingDaysPerWeek',
            title: 'Read on 5 days this week',
            subtitle: '${store.readingDaysInWeek(now)} / 5 days',
            progress: _progress(store.readingDaysInWeek(now), 5),
            icon: Icons.calendar_month_rounded,
          ),
          ...store.goals.map(
            (goal) => _snapshotForCustomGoal(goal, store, now),
          ),
        ];
        final activeGoals = goals.where((goal) {
          if (goal.id == null || goal.periodMetric == null) return true;
          return !store.hasGoalAchievement(
            goal.id!,
            _periodKey(goal.periodMetric!, now),
          );
        }).toList();
        final challengeAchieved = store.hasGoalAchievement(
          'monthly_challenge',
          _periodKey('booksPerMonth', now),
        );

        return AppPage(
          eyebrow: 'Build the habit',
          title: 'Goals',
          actions: [
            IconCircleButton(
              icon: Icons.add_rounded,
              onPressed: () => _showAddGoalDialog(context),
              filled: true,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!challengeAchieved) ...[
                _MonthlyChallenge(
                  monthName: _monthName(now.month),
                  completedMinutes: monthlyMinutes,
                  targetMinutes: monthlyTargetMinutes,
                  progress: monthlyProgress,
                ),
                const SizedBox(height: 24),
              ],
              const SectionHeading(title: 'Active goals', action: 'Live'),
              const SizedBox(height: 12),
              if (activeGoals.isEmpty)
                const _GoalsEmptyState()
              else
                for (final goal in activeGoals)
                  _GoalRow(
                    goal: goal,
                    onRemove: goal.id == null
                        ? null
                        : () => store.removeGoal(goal.id!),
                  ),
              const SizedBox(height: 12),
              SectionHeading(
                title: 'Achievement shelf',
                action: '${store.goalAchievements.length} earned',
              ),
              const SizedBox(height: 12),
              if (store.goalAchievements.isEmpty)
                const _GoalsEmptyState(
                  message: 'Completed goals will be saved here automatically.',
                  icon: Icons.emoji_events_outlined,
                )
              else
                for (final achievement in store.goalAchievements)
                  _AchievementCard(achievement: achievement),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddGoalDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '20');
    var metric = 'pagesPerDay';
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a reading goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Goal name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metric,
                decoration: const InputDecoration(labelText: 'Track'),
                items: const [
                  DropdownMenuItem(
                    value: 'pagesPerDay',
                    child: Text('Pages per day'),
                  ),
                  DropdownMenuItem(
                    value: 'minutesPerDay',
                    child: Text('Minutes per day'),
                  ),
                  DropdownMenuItem(
                    value: 'readingDaysPerWeek',
                    child: Text('Reading days per week'),
                  ),
                  DropdownMenuItem(
                    value: 'booksPerMonth',
                    child: Text('Books per month'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => metric = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final target = int.tryParse(targetController.text.trim());
                final title = titleController.text.trim();
                if (title.isEmpty || target == null || target <= 0) return;
                Navigator.pop(dialogContext, {
                  'metric': metric,
                  'title': title,
                  'target': target,
                });
              },
              child: const Text('Add goal'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    targetController.dispose();
    if (result == null) return;
    await store.addGoal(
      metric: result['metric']! as String,
      title: result['title']! as String,
      target: result['target']! as int,
    );
  }
}

class _MonthlyChallenge extends StatelessWidget {
  const _MonthlyChallenge({
    required this.monthName,
    required this.completedMinutes,
    required this.targetMinutes,
    required this.progress,
  });

  final String monthName;
  final int completedMinutes;
  final int targetMinutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(targetMinutes - completedMinutes, 0);
    return AppSurface(
      color: ReadingColors.forest,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName reading challenge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '10 hours of focused reading',
                  style: TextStyle(color: Color(0xFFCFE5D8)),
                ),
                const SizedBox(height: 18),
                ProgressBar(value: progress, dark: true),
                const SizedBox(height: 8),
                Text(
                  '${_formatMinutes(completedMinutes)} completed  ·  ${_formatMinutes(remaining)} left',
                  style: const TextStyle(
                    color: Color(0xFFDCEBE2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ProgressRing(value: progress, label: '${(progress * 100).round()}%'),
        ],
      ),
    );
  }
}

class _GoalSnapshot {
  const _GoalSnapshot({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
    this.periodMetric,
    this.id,
  });

  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;
  final String? periodMetric;
  final String? id;
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, this.onRemove});

  final _GoalSnapshot goal;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(goal.icon, color: ReadingColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: const TextStyle(
                            color: ReadingColors.forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onRemove != null)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (_) => onRemove!(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove goal'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: ProgressBar(value: goal.progress)),
                      const SizedBox(width: 10),
                      Text(
                        goal.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ReadingColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState({
    this.message = 'You completed every goal for this period. Great work!',
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Icon(icon, color: ReadingColors.green, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: ReadingColors.textMuted, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Map<String, dynamic> achievement;

  @override
  Widget build(BuildContext context) {
    final completedAt = DateTime.tryParse(
      achievement['completedAt'] as String? ?? '',
    );
    final dateLabel = completedAt == null
        ? achievement['periodKey'] as String? ?? ''
        : '${_monthName(completedAt.month)} ${completedAt.day}, ${completedAt.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFE0A957),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement['title'] as String? ?? 'Goal achieved',
                    style: const TextStyle(
                      color: ReadingColors.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${achievement['subtitle'] ?? 'Completed'} · $dateLabel',
                    style: const TextStyle(
                      color: ReadingColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: ReadingColors.green),
          ],
        ),
      ),
    );
  }
}

_GoalSnapshot _snapshotForCustomGoal(
  ReadingGoalDefinition goal,
  LocalReadingStore store,
  DateTime now,
) {
  final value = switch (goal.metric) {
    'minutesPerDay' => store.minutesReadOn(now),
    'readingDaysPerWeek' => store.readingDaysInWeek(now),
    'booksPerMonth' => store.finishedBooksInMonth(now),
    _ => store.pagesReadOn(now),
  };
  final unit = switch (goal.metric) {
    'minutesPerDay' => 'minutes today',
    'readingDaysPerWeek' => 'days this week',
    'booksPerMonth' => 'books this month',
    _ => 'pages today',
  };
  return _GoalSnapshot(
    id: goal.id,
    periodMetric: goal.metric,
    title: goal.title,
    subtitle: '$value / ${goal.target} $unit',
    progress: _progress(value, goal.target),
    icon: _iconForMetric(goal.metric),
  );
}

double _progress(int value, int target) =>
    target <= 0 ? 0 : math.min(value / target, 1.0);

String _periodKey(String metric, DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  if (metric == 'readingDaysPerWeek') {
    final monday = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - DateTime.monday));
    return '${monday.year}-${two(monday.month)}-${two(monday.day)}';
  }
  if (metric == 'booksPerMonth') return '${date.year}-${two(date.month)}';
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

IconData _iconForMetric(String metric) => switch (metric) {
  'minutesPerDay' => Icons.schedule_rounded,
  'readingDaysPerWeek' => Icons.calendar_month_rounded,
  'booksPerMonth' => Icons.flag_rounded,
  _ => Icons.auto_stories_rounded,
};

String _monthName(int month) => const [
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

String _formatMinutes(int minutes) =>
    minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';
