/// Local notifications: the daily reminder, habit reminders and the
/// "step goal reached" message. Nothing is sent from a server.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';

abstract interface class NotificationService {
  Future<void> init();

  /// Asks the system for permission. Returns false when refused.
  Future<bool> requestPermission();

  Future<void> scheduleDailyReminder(int minutesOfDay);
  Future<void> cancelDailyReminder();

  /// Schedules [habit]'s reminder on each of its weekdays, replacing any
  /// earlier schedule. Cancels it when the habit has no reminder.
  Future<void> syncHabitReminder(Habit habit);
  Future<void> cancelHabitReminder(String habitId);

  Future<void> showGoalReached(int steps, int goal);
  Future<void> cancelAll();
}

/// Notification IDs. Fixed IDs let a new schedule replace the old one.
abstract final class NotificationIds {
  static const dailyReminder = 1;
  static const goalReached = 2;

  /// One ID per habit per weekday.
  static int habit(String habitId, int weekday) =>
      1000 + stableHash(habitId) * 8 + weekday;

  /// FNV-1a, limited to 20 bits. `String.hashCode` is not guaranteed to stay
  /// the same between app versions, and these IDs must.
  static int stableHash(String s) {
    var h = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0xFFFFF;
  }
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'goals',
      'Goals and reminders',
      channelDescription: 'Daily goal reminders and goal-reached messages',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: reminders fall back to UTC rather than failing.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested later, when the user turns a reminder on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  /// The next time the clock shows [minutesOfDay], optionally on [weekday].
  tz.TZDateTime _next(int minutesOfDay, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        minutesOfDay ~/ 60, minutesOfDay % 60);
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  @override
  Future<void> scheduleDailyReminder(int minutesOfDay) async {
    await init();
    await _plugin.zonedSchedule(
      id: NotificationIds.dailyReminder,
      title: 'Daily goals',
      body: 'Check your steps and habits for today.',
      scheduledDate: _next(minutesOfDay),
      notificationDetails: _details,
      // Inexact alarms need no special Android permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(id: NotificationIds.dailyReminder);
  }

  @override
  Future<void> syncHabitReminder(Habit habit) async {
    await init();
    await cancelHabitReminder(habit.id);
    if (!habit.reminderEnabled || habit.archived) return;
    for (final weekday in habit.weekdays) {
      await _plugin.zonedSchedule(
        id: NotificationIds.habit(habit.id, weekday),
        title: habit.name,
        body: 'Scheduled for today. Tick it off when you are done.',
        scheduledDate: _next(habit.reminderMinutes, weekday: weekday),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  @override
  Future<void> cancelHabitReminder(String habitId) async {
    await init();
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: NotificationIds.habit(habitId, weekday));
    }
  }

  @override
  Future<void> showGoalReached(int steps, int goal) async {
    await init();
    await _plugin.show(
      id: NotificationIds.goalReached,
      title: 'Step goal reached',
      body: 'You reached your goal of $goal steps today.',
      notificationDetails: _details,
    );
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}

/// Used on the web, in demo mode and in tests, where the phone's
/// notification system is not available. Records calls for assertions.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = false});

  bool permissionGranted;
  final log = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleDailyReminder(int minutesOfDay) async =>
      log.add('daily:$minutesOfDay');

  @override
  Future<void> cancelDailyReminder() async => log.add('daily:cancel');

  @override
  Future<void> syncHabitReminder(Habit habit) async =>
      log.add('habit:${habit.id}:${habit.reminderEnabled}');

  @override
  Future<void> cancelHabitReminder(String habitId) async =>
      log.add('habit:$habitId:cancel');

  @override
  Future<void> showGoalReached(int steps, int goal) async =>
      log.add('goal:$steps/$goal');

  @override
  Future<void> cancelAll() async => log.add('cancelAll');
}
