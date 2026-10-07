import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open Readwise'),
      windows: WindowsInitializationSettings(
        appName: 'Readwise',
        appUserModelId: 'com.example.readwise',
        guid: '8d8b7cf0-7ca8-4e9b-a3e6-2ae4e8c0d0b1',
      ),
    );

    try {
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (_) {
      // Widget tests and unsupported platforms do not register native plugins.
      _initialized = false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reading_habit',
        'Reading habit',
        channelDescription: 'Reading sessions, goals, and achievements',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> scheduleStreakReminder({required bool alreadyReadToday}) async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (alreadyReadToday) {
      await cancelStreakReminder();
      return;
    }
    await _plugin.periodicallyShow(
      id: 701,
      title: 'Keep your reading streak alive',
      body: 'Read for a few minutes today to keep your habit growing.',
      repeatInterval: RepeatInterval.daily,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_streak_reminders',
          'Reading streak reminders',
          channelDescription: 'Daily reminders to keep your reading streak.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelStreakReminder() async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _plugin.cancel(id: 701);
  }
}
