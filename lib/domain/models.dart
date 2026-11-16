/// Plain data classes shared by every layer. No Flutter or Firebase imports.
library;

import '../core/dates.dart';

// ---------------------------------------------------------------- profile

class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName = '',
    this.weeklyWorkoutTarget = 3,
    this.stepGoal = 8000,
    this.stepTrackingEnabled = false,
    this.dailyReminderEnabled = false,
    this.dailyReminderMinutes = 19 * 60,
  });

  final String uid;
  final String displayName;
  final int weeklyWorkoutTarget;
  final int stepGoal;
  final bool stepTrackingEnabled;
  final bool dailyReminderEnabled;

  /// Minutes after midnight, e.g. 19:00 is 1140.
  final int dailyReminderMinutes;

  UserProfile copyWith({
    String? displayName,
    int? weeklyWorkoutTarget,
    int? stepGoal,
    bool? stepTrackingEnabled,
    bool? dailyReminderEnabled,
    int? dailyReminderMinutes,
  }) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        weeklyWorkoutTarget: weeklyWorkoutTarget ?? this.weeklyWorkoutTarget,
        stepGoal: stepGoal ?? this.stepGoal,
        stepTrackingEnabled: stepTrackingEnabled ?? this.stepTrackingEnabled,
        dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
        dailyReminderMinutes: dailyReminderMinutes ?? this.dailyReminderMinutes,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'weeklyWorkoutTarget': weeklyWorkoutTarget,
        'stepGoal': stepGoal,
        'stepTrackingEnabled': stepTrackingEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
        'dailyReminderMinutes': dailyReminderMinutes,
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) =>
      UserProfile(
        uid: uid,
        displayName: m['displayName'] as String? ?? '',
        weeklyWorkoutTarget: (m['weeklyWorkoutTarget'] as num?)?.toInt() ?? 3,
        stepGoal: (m['stepGoal'] as num?)?.toInt() ?? 8000,
        stepTrackingEnabled: m['stepTrackingEnabled'] as bool? ?? false,
        dailyReminderEnabled: m['dailyReminderEnabled'] as bool? ?? false,
        dailyReminderMinutes:
            (m['dailyReminderMinutes'] as num?)?.toInt() ?? 19 * 60,
      );
}

// ---------------------------------------------------------------- workouts

enum WorkoutType { strength, timed }

class ExerciseSet {
  const ExerciseSet({this.reps = 0, this.weightKg, this.done = false});

  final int reps;

  /// Null for bodyweight exercises.
  final double? weightKg;
  final bool done;

  ExerciseSet copyWith({int? reps, double? weightKg, bool? done}) =>
      ExerciseSet(
        reps: reps ?? this.reps,
        weightKg: weightKg ?? this.weightKg,
        done: done ?? this.done,
      );

  ExerciseSet withWeight(double? kg) =>
      ExerciseSet(reps: reps, weightKg: kg, done: done);

  Map<String, dynamic> toMap() =>
      {'reps': reps, 'weightKg': weightKg, 'done': done};

  factory ExerciseSet.fromMap(Map<String, dynamic> m) => ExerciseSet(
        reps: (m['reps'] as num?)?.toInt() ?? 0,
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        done: m['done'] as bool? ?? false,
      );
}

class WorkoutExercise {
  const WorkoutExercise({
    this.exerciseId,
    required this.name,
    this.category = '',
    this.sets = const [ExerciseSet()],
  });

  /// The wger exercise ID, or null for an exercise typed in by hand.
  final int? exerciseId;
  final String name;
  final String category;
  final List<ExerciseSet> sets;

  WorkoutExercise copyWith({List<ExerciseSet>? sets}) => WorkoutExercise(
        exerciseId: exerciseId,
        name: name,
        category: category,
        sets: sets ?? this.sets,
      );

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'category': category,
        'sets': [for (final s in sets) s.toMap()],
      };

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
        exerciseId: (m['exerciseId'] as num?)?.toInt(),
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? '',
        sets: [
          for (final s in (m['sets'] as List? ?? const []))
            ExerciseSet.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

class Workout {
  const Workout({
    required this.id,
    this.title = '',
    this.type = WorkoutType.strength,
    required this.date,
    required this.startedAt,
    this.durationSeconds = 0,
    this.exercises = const [],
    this.pendingSync = false,
  });

  /// Created together with the draft, so saving twice writes one document.
  final String id;
  final String title;
  final WorkoutType type;

  /// Date key of the day the workout belongs to.
  final String date;
  final DateTime startedAt;
  final int durationSeconds;
  final List<WorkoutExercise> exercises;

  /// True while the record waits to reach the server. Not stored.
  final bool pendingSync;

  int get minutes => (durationSeconds / 60).round();

  int get doneSets =>
      exercises.fold(0, (n, e) => n + e.sets.where((s) => s.done).length);

  /// A strength session needs one completed set; a timed activity needs a
  /// duration above zero.
  bool get isComplete =>
      type == WorkoutType.timed ? durationSeconds > 0 : doneSets > 0;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return type == WorkoutType.timed ? 'Timed activity' : 'Workout';
  }

  Workout copyWith({
    String? title,
    WorkoutType? type,
    String? date,
    DateTime? startedAt,
    int? durationSeconds,
    List<WorkoutExercise>? exercises,
    bool? pendingSync,
  }) =>
      Workout(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        date: date ?? this.date,
        startedAt: startedAt ?? this.startedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        exercises: exercises ?? this.exercises,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.name,
        'date': date,
        'startedAt': startedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'exercises': [for (final e in exercises) e.toMap()],
      };

  factory Workout.fromMap(String id, Map<String, dynamic> m,
      {bool pendingSync = false}) {
    final started = DateTime.tryParse(m['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Workout(
      id: id,
      title: m['title'] as String? ?? '',
      type: m['type'] == 'timed' ? WorkoutType.timed : WorkoutType.strength,
      date: m['date'] as String? ?? dateKey(started),
      startedAt: started,
      durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
      exercises: [
        for (final e in (m['exercises'] as List? ?? const []))
          WorkoutExercise.fromMap(Map<String, dynamic>.from(e as Map)),
      ],
      pendingSync: pendingSync,
    );
  }
}

// ---------------------------------------------------------------- habits

class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.reminderEnabled = false,
    this.reminderMinutes = 19 * 60,
    required this.startDate,
    this.archivedDate,
  });

  final String id;
  final String name;

  /// 1 = Monday ... 7 = Sunday.
  final Set<int> weekdays;
  final bool reminderEnabled;
  final int reminderMinutes;

  /// First day the habit can be due.
  final String startDate;

  /// Day the habit was archived, or null while active. Earlier days keep
  /// their history.
  final String? archivedDate;

  bool get archived => archivedDate != null;

  bool isScheduledOn(String date) {
    if (date.compareTo(startDate) < 0) return false;
    if (archivedDate != null && date.compareTo(archivedDate!) >= 0) {
      return false;
    }
    return weekdays.contains(weekdayOf(date));
  }

  String get scheduleLabel {
    if (weekdays.length == 7) return 'Every day';
    final sorted = weekdays.toList()..sort();
    return sorted.map((d) => weekdayShort[d - 1]).join(' / ');
  }

  Habit copyWith({
    String? name,
    Set<int>? weekdays,
    bool? reminderEnabled,
    int? reminderMinutes,
    String? archivedDate,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        weekdays: weekdays ?? this.weekdays,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        startDate: startDate,
        archivedDate: archivedDate ?? this.archivedDate,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'weekdays': weekdays.toList()..sort(),
        'reminderEnabled': reminderEnabled,
        'reminderMinutes': reminderMinutes,
        'startDate': startDate,
        'archivedDate': archivedDate,
      };

  factory Habit.fromMap(String id, Map<String, dynamic> m) => Habit(
        id: id,
        name: m['name'] as String? ?? '',
        weekdays: {
          for (final d in (m['weekdays'] as List? ?? const []))
            (d as num).toInt(),
        },
        reminderEnabled: m['reminderEnabled'] as bool? ?? false,
        reminderMinutes: (m['reminderMinutes'] as num?)?.toInt() ?? 19 * 60,
        startDate: m['startDate'] as String? ?? '1970-01-01',
        archivedDate: m['archivedDate'] as String?,
      );
}

class HabitCompletion {
  const HabitCompletion({required this.habitId, required this.date});

  final String habitId;
  final String date;

  /// One document per habit per day, so ticking twice cannot duplicate.
  String get id => '${habitId}_$date';

  Map<String, dynamic> toMap() => {'habitId': habitId, 'date': date};

  factory HabitCompletion.fromMap(Map<String, dynamic> m) => HabitCompletion(
        habitId: m['habitId'] as String? ?? '',
        date: m['date'] as String? ?? '',
      );
}

/// Starting points offered in the habit editor.
const fitnessHabitTemplates = <({String name, Set<int> weekdays})>[
  (name: 'Stretch for 10 minutes', weekdays: {1, 2, 3, 4, 5, 6, 7}),
  (name: 'Walk outside', weekdays: {1, 2, 3, 4, 5, 6, 7}),
  (name: 'Drink water with every meal', weekdays: {1, 2, 3, 4, 5, 6, 7}),
  (name: 'Strength session', weekdays: {1, 3, 5}),
  (name: 'Take the stairs', weekdays: {1, 2, 3, 4, 5}),
  (name: 'Be in bed by 23:00', weekdays: {1, 2, 3, 4, 7}),
];

// ---------------------------------------------------------------- steps

enum StepSource { sensor, accelerometer }

class StepDay {
  const StepDay({
    required this.date,
    required this.steps,
    required this.goal,
    this.source = StepSource.sensor,
    this.trackedFrom,
  });

  final String date;
  final int steps;

  /// The goal that applied on this day.
  final int goal;
  final StepSource source;

  /// When recording started on this day.
  final DateTime? trackedFrom;

  bool get goalMet => goal > 0 && steps >= goal;

  Map<String, dynamic> toMap() => {
        'date': date,
        'steps': steps,
        'goal': goal,
        'source': source.name,
        'trackedFrom': trackedFrom?.toIso8601String(),
      };

  factory StepDay.fromMap(Map<String, dynamic> m) => StepDay(
        date: m['date'] as String? ?? '',
        steps: (m['steps'] as num?)?.toInt() ?? 0,
        goal: (m['goal'] as num?)?.toInt() ?? 0,
        source: m['source'] == 'accelerometer'
            ? StepSource.accelerometer
            : StepSource.sensor,
        trackedFrom: DateTime.tryParse(m['trackedFrom'] as String? ?? ''),
      );
}

// ---------------------------------------------------------------- exercises

/// An exercise from the wger catalogue.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.category = '',
    this.muscles = const [],
    this.equipment = const [],
    this.description = '',
    this.imageUrl,
    this.license = '',
    this.licenseUrl = '',
    this.author = '',
  });

  final int id;
  final String name;
  final String category;
  final List<String> muscles;
  final List<String> equipment;

  /// Plain text; HTML from the API is removed before it gets here.
  final String description;
  final String? imageUrl;
  final String license;
  final String licenseUrl;
  final String author;

  String get sourceUrl => 'https://wger.de/en/exercise/$id/view/';

  String get subtitle => [
        if (category.isNotEmpty) category,
        equipment.isEmpty ? 'No equipment listed' : equipment.join(', '),
      ].join(' | ');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'muscles': muscles,
        'equipment': equipment,
        'description': description,
        'imageUrl': imageUrl,
        'license': license,
        'licenseUrl': licenseUrl,
        'author': author,
      };

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? '',
        muscles: List<String>.from(m['muscles'] as List? ?? const []),
        equipment: List<String>.from(m['equipment'] as List? ?? const []),
        description: m['description'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        license: m['license'] as String? ?? '',
        licenseUrl: m['licenseUrl'] as String? ?? '',
        author: m['author'] as String? ?? '',
      );
}
