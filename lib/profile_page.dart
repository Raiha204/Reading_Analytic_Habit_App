import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_widgets.dart';
import 'local_reading_store.dart';
import 'reading_models.dart';
import 'profile_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.store,
    this.user,
    this.onSignOut,
  });

  final LocalReadingStore store;
  final User? user;
  final VoidCallback? onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _avatarBytes;
  bool _avatarLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    setState(() => _avatarLoading = true);
    final bytes = await ProfilePreferences.instance.loadAvatar(uid);
    if (mounted) {
      setState(() {
        _avatarBytes = bytes;
        _avatarLoading = false;
      });
    }
  }

  Future<void> _chooseAvatar() async {
    final uid = widget.user?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to set a profile picture.')),
      );
      return;
    }
    try {
      final bytes = await ProfilePreferences.instance.pickAvatarBytes();
      if (bytes == null) return;
      await ProfilePreferences.instance.saveAvatar(uid, bytes);
      if (mounted) {
        setState(() => _avatarBytes = bytes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile picture: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final user = widget.user;
        final achievements = [
          Achievement(
            symbol: '1',
            title: 'First session',
            description: 'Finish your first reading session.',
            progress: store.totalSessions,
            target: 1,
            unlocked: store.hasAchievement('First session'),
          ),
          Achievement(
            symbol: '📚',
            title: 'First book',
            description: 'Complete your first book.',
            progress: store.completedBookCount,
            target: 1,
            unlocked: store.hasAchievement('First book'),
          ),
          Achievement(
            symbol: '7',
            title: '7-day streak',
            description: 'Read on seven consecutive days.',
            progress: store.longestStreak,
            target: 7,
            unlocked: store.hasAchievement('7-day streak'),
          ),
          Achievement(
            symbol: '100',
            title: '100 pages',
            description: 'Read 100 pages across your sessions.',
            progress: store.totalPages,
            target: 100,
            unlocked: store.hasAchievement('100 pages'),
          ),
          Achievement(
            symbol: '30',
            title: '30-day streak',
            description: 'Keep a reading streak for 30 days.',
            progress: store.longestStreak,
            target: 30,
            unlocked: store.hasAchievement('30-day streak'),
          ),
          Achievement(
            symbol: '★',
            title: 'Bookworm',
            description: 'Complete five books.',
            progress: store.completedBookCount,
            target: 5,
            unlocked: store.hasAchievement('Bookworm'),
          ),
          Achievement(
            symbol: '10',
            title: '10 sessions',
            description: 'Finish ten reading sessions.',
            progress: store.totalSessions,
            target: 10,
            unlocked: store.hasAchievement('10 sessions'),
          ),
          Achievement(
            symbol: '100',
            title: '100 sessions',
            description: 'Finish 100 reading sessions.',
            progress: store.totalSessions,
            target: 100,
            unlocked: store.hasAchievement('100 sessions'),
          ),
          Achievement(
            symbol: '1K',
            title: '1,000 pages',
            description: 'Read 1,000 pages across your sessions.',
            progress: store.totalPages,
            target: 1000,
            unlocked: store.hasAchievement('1000 pages'),
          ),
        ];
        final shelfAchievements = achievements.take(6).toList();
        return AppPage(
          eyebrow: 'Your reading identity',
          title: 'Profile',
          actions: [
            if (widget.onSignOut != null)
              IconCircleButton(
                icon: Icons.logout_rounded,
                onPressed: widget.onSignOut!,
              ),
            const SizedBox(width: 8),
            IconCircleButton(
              icon: Icons.info_outline_rounded,
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Readwise',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset(
                  'assets/images/readwise_logo.png',
                  width: 48,
                  height: 48,
                ),
                children: const [
                  Text(
                    'Build a consistent reading habit with your library, goals, and reading insights.',
                  ),
                ],
              ),
            ),
          ],
          child: Column(
            children: [
              AppSurface(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(
                          large: true,
                          photoUrl: user?.photoURL,
                          name: user?.displayName ?? user?.email,
                          imageBytes: _avatarBytes,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: ReadingColors.forest,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _avatarLoading ? null : _chooseAvatar,
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName?.isNotEmpty == true
                                ? user!.displayName!
                                : 'Reader',
                            style: const TextStyle(
                              color: ReadingColors.forest,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Building a better reading life',
                            style: TextStyle(color: ReadingColors.textMuted),
                          ),
                          SizedBox(height: 12),
                          Text(
                            user?.email ?? 'No email available',
                            style: const TextStyle(
                              color: ReadingColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurface(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProfileStat(
                      value:
                          '${store.books.where((book) => book.progress >= 1).length}',
                      label: 'books finished',
                    ),
                    _ProfileStat(
                      value: _formatMinutes(store.totalMinutes),
                      label: 'reading time',
                    ),
                    _ProfileStat(
                      value: '${store.longestStreak}',
                      label: 'best streak',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Achievement shelf',
                      style: TextStyle(
                        color: ReadingColors.forest,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAchievements(context, achievements),
                    icon: const Icon(Icons.emoji_events_outlined, size: 17),
                    label: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${achievements.where((item) => item.unlocked).length} of ${achievements.length} earned',
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  for (final achievement in shelfAchievements)
                    _AchievementTile(achievement: achievement),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMinutes(int minutes) =>
      minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';

  void _showAchievements(BuildContext context, List<Achievement> achievements) {
    var filter = 'All';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = achievements.where((item) {
            if (filter == 'Earned') return item.unlocked;
            if (filter == 'Locked') return !item.unlocked;
            return true;
          }).toList();
          return FractionallySizedBox(
            heightFactor: .84,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F8F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Achievements',
                              style: TextStyle(
                                color: ReadingColors.forest,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final option in ['All', 'Earned', 'Locked'])
                            ChoiceChip(
                              label: Text(option),
                              selected: filter == option,
                              onSelected: (_) =>
                                  setSheetState(() => filter = option),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text(
                                'No achievements in this filter yet.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, index) =>
                                  _AchievementListTile(
                                    achievement: visible[index],
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ReadingColors.forest,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: ReadingColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final ratio = achievement.target <= 0
        ? 1.0
        : (achievement.progress / achievement.target).clamp(0.0, 1.0);
    return AppSurface(
      color: achievement.unlocked
          ? const Color(0xFFFFF4D9)
          : const Color(0xFFF0F3F1),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: achievement.unlocked
                  ? const Color(0xFFFFE5A6)
                  : const Color(0xFFE1E7E3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: achievement.unlocked
                ? Text(
                    achievement.symbol,
                    style: const TextStyle(
                      color: Color(0xFF72500B),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF83918A),
                    size: 21,
                  ),
          ),
          const SizedBox(height: 9),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: achievement.unlocked
                  ? const Color(0xFF493710)
                  : ReadingColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!achievement.unlocked) ...[
            const SizedBox(height: 5),
            SizedBox(
              width: 54,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: const Color(0xFFE0E7E2),
                color: const Color(0xFF91B5A5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementListTile extends StatelessWidget {
  const _AchievementListTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final ratio = achievement.target <= 0
        ? 1.0
        : (achievement.progress / achievement.target).clamp(0.0, 1.0);
    return AppSurface(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: achievement.unlocked
                  ? const Color(0xFFFFE5A6)
                  : const Color(0xFFE8EEEA),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: achievement.unlocked
                ? Text(
                    achievement.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF72500B),
                    ),
                  )
                : const Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: ReadingColors.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    color: ReadingColors.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE7EEE9),
                    color: achievement.unlocked
                        ? ReadingColors.green
                        : const Color(0xFF9CBCAF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.unlocked
                      ? 'Earned'
                      : '${achievement.progress} / ${achievement.target}',
                  style: const TextStyle(
                    color: ReadingColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (achievement.unlocked)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle_rounded,
                color: ReadingColors.green,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
