import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_demo_app/core/widgets/app_widgets.dart';
import 'package:flutter_demo_app/data/repositories/local_reading_store.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';

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
                    onEdit: store.goals.any((item) => item.id == goal.id)
                        ? () => _showAddGoalDialog(
                            context,
                            existing: store.goals.firstWhere(
                              (item) => item.id == goal.id,
                            ),
                          )
                        : null,
                    onRemove: store.goals.any((item) => item.id == goal.id)
                        ? () => _confirmRemoveGoal(context, store, goal)
                        : null,
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

  Future<void> _showAddGoalDialog(
    BuildContext context, {
    ReadingGoalDefinition? existing,
  }) async {
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _GoalEditorDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await store.addGoal(
          metric: result['metric']! as String,
          title: result['title']! as String,
          target: result['target']! as int,
        );
      } else {
        await store.updateGoal(
          id: existing.id,
          metric: result['metric']! as String,
          title: result['title']! as String,
          target: result['target']! as int,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Goal added successfully.'
                : 'Goal updated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save goal: $error')));
    }
  }

  Future<void> _confirmRemoveGoal(
    BuildContext context,
    LocalReadingStore store,
    _GoalSnapshot goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove goal?'),
        content: Text('“${goal.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && goal.id != null) {
      await store.removeGoal(goal.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal removed successfully.')),
      );
    }
  }
}

class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({this.existing});

  final ReadingGoalDefinition? existing;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late String _metric;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _targetController = TextEditingController(
      text: '${widget.existing?.target ?? 20}',
    );
    _metric = widget.existing?.metric ?? 'pagesPerDay';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.existing == null ? 'Add a reading goal' : 'Edit goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _metric,
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
              if (value == null) return;
              setState(() {
                _metric = value;
                _validationMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target'),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? 'Add goal' : 'Save changes'),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    final target = int.tryParse(_targetController.text.trim());
    if (title.isEmpty || target == null || target <= 0) {
      setState(() {
        _validationMessage = title.isEmpty
            ? 'Enter a name for this goal.'
            : 'Enter a target greater than zero.';
      });
      return;
    }
    Navigator.pop(context, {
      'metric': _metric,
      'title': title,
      'target': target,
    });
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
  const _GoalRow({required this.goal, this.onEdit, this.onRemove});

  final _GoalSnapshot goal;
  final VoidCallback? onEdit;
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
                          onSelected: (action) {
                            if (action == 'edit') onEdit?.call();
                            if (action == 'remove') onRemove?.call();
                          },
                          itemBuilder: (_) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit goal'),
                              ),
                            if (onRemove != null)
                              const PopupMenuItem(
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
