# Diagrams

All diagrams are Mermaid and render on GitHub.

## System diagram

```mermaid
flowchart LR
  user([User])

  subgraph phone[Phone]
    subgraph app[Flutter app]
      ui[Features<br/>screens and controllers]
      prov[Riverpod providers]
      dom[Domain<br/>models, streaks, summary, step tracker]
      repo[Repositories]
      wger[WgerApi]
      steps[StepController]
      notif[NotificationService]
      local[(SharedPreferences<br/>draft, step state, API cache)]
    end
    sensor[[Step counter or accelerometer]]
    osn[[System notifications]]
    perm[[Permission dialogs]]
  end

  subgraph firebase[Firebase]
    auth[Authentication]
    fs[(Cloud Firestore<br/>users/uid/...)]
  end

  wgerapi[(wger REST API<br/>wger.de/api/v2)]

  user --> ui
  ui --> prov --> repo
  prov --> dom
  prov --> wger
  prov --> steps
  prov --> notif
  repo --> auth
  repo <--> fs
  wger --> wgerapi
  wger --> local
  steps --> sensor
  steps --> perm
  steps --> local
  steps --> repo
  notif --> osn
  notif --> perm
```

## Navigation flow

```mermaid
flowchart TD
  S01[S01 Account access] -->|signed in| shell

  subgraph shell[App shell: bottom tabs]
    S02[S02 Home]
    S03[S03 Workout history]
    S07[S07 Habits]
    S10[S10 Progress]
  end

  S02 -->|Start / Log past| S04[S04 Workout log]
  S03 -->|Start / Log past / tap item| S04
  S04 -->|Add exercise| S05[S05 Exercise catalogue]
  S05 -->|tap exercise| S06[S06 Exercise detail]
  S06 -->|Add to workout| S04
  S04 -->|Finish and save| S03

  S02 -->|steps card| S09[S09 Steps and daily goal]
  S02 -->|habits card| S07
  S07 -->|Add / Edit| S08[S08 Habit editor]
  S08 -->|Save| S07

  S02 -->|View weekly summary| S11[S11 Weekly summary]
  S10 -->|Open weekly summary| S11

  shell -->|Settings icon| S12[S12 Settings and profile]
  S12 -->|Sign out| S01
```

## Domain model

```mermaid
classDiagram
  class UserProfile {
    String uid
    String displayName
    int weeklyWorkoutTarget
    int stepGoal
    bool stepTrackingEnabled
    bool dailyReminderEnabled
    int dailyReminderMinutes
  }
  class Workout {
    String id
    String title
    WorkoutType type
    String date
    DateTime startedAt
    int durationSeconds
    bool pendingSync
    isComplete() bool
  }
  class WorkoutExercise {
    int exerciseId
    String name
    String category
  }
  class ExerciseSet {
    int reps
    double weightKg
    bool done
  }
  class Habit {
    String id
    String name
    Set~int~ weekdays
    bool reminderEnabled
    int reminderMinutes
    String startDate
    String archivedDate
    isScheduledOn(date) bool
  }
  class HabitCompletion {
    String habitId
    String date
  }
  class StepDay {
    String date
    int steps
    int goal
    StepSource source
    DateTime trackedFrom
    goalMet() bool
  }
  class Exercise {
    int id
    String name
    String category
    List~String~ muscles
    List~String~ equipment
    String description
    String imageUrl
    String license
    String author
  }
  class WeeklySummary {
    String weekStart
    int workouts
    int workoutTarget
    int minutes
    int steps
    int trackedDays
    int goalMetDays
    int habitsDone
    int habitsDue
  }

  UserProfile "1" --> "*" Workout : logs
  UserProfile "1" --> "*" Habit : keeps
  UserProfile "1" --> "*" StepDay : records
  Workout "1" *-- "*" WorkoutExercise
  WorkoutExercise "1" *-- "*" ExerciseSet
  WorkoutExercise ..> Exercise : chosen from wger
  Habit "1" --> "*" HabitCompletion : ticked on
  WeeklySummary ..> Workout : calculated from
  WeeklySummary ..> StepDay : calculated from
  WeeklySummary ..> HabitCompletion : calculated from
```

## Class diagram

The classes that carry behaviour, by layer.

```mermaid
classDiagram
  direction TB

  class AuthRepository {
    <<interface>>
    authState() Stream~AuthUser~
    signIn(email, password)
    signUp(email, password) AuthUser
    sendPasswordReset(email)
    signOut()
    reauthenticate(password)
    deleteUser()
  }
  class ProfileRepository {
    <<interface>>
    watchProfile(uid) Stream~UserProfile~
    saveProfile(profile)
    deleteAllData(uid)
  }
  class WorkoutRepository {
    <<interface>>
    watchWorkouts(uid) Stream~List~Workout~~
    newId(uid) String
    saveWorkout(uid, workout)
    deleteWorkout(uid, id)
  }
  class HabitRepository {
    <<interface>>
    watchHabits(uid) Stream~List~Habit~~
    watchCompletions(uid) Stream~List~HabitCompletion~~
    saveHabit(uid, habit)
    setCompleted(uid, habitId, date, done)
  }
  class StepRepository {
    <<interface>>
    watchDays(uid) Stream~List~StepDay~~
    saveDay(uid, day)
  }

  class FirebaseAuthRepository
  class FirestoreStore {
    all records under users/uid
  }
  class MemoryBackend {
    in-memory, for demo mode and tests
  }

  AuthRepository <|.. FirebaseAuthRepository
  ProfileRepository <|.. FirestoreStore
  WorkoutRepository <|.. FirestoreStore
  HabitRepository <|.. FirestoreStore
  StepRepository <|.. FirestoreStore
  AuthRepository <|.. MemoryBackend
  ProfileRepository <|.. MemoryBackend
  WorkoutRepository <|.. MemoryBackend
  HabitRepository <|.. MemoryBackend
  StepRepository <|.. MemoryBackend

  class WgerApi {
    fetchExercises(query, offset) ExercisePage
    fetchCategories() List
    fetchEquipment() List
    parseExercise(json) Exercise
    htmlToText(html) String
  }
  class LocalStore {
    loadDraft(uid) WorkoutDraft
    saveDraft(uid, draft)
    loadStepState(uid) StepState
    saveStepState(uid, state)
    cacheGet(key) / cachePut(key, value)
    clearUser(uid)
  }
  class StepPlatform {
    <<interface>>
    checkPermission() PermissionResult
    requestPermission() PermissionResult
    stepCounts() Stream~int~
    accelerometer() Stream~AccelSample~
    openSettings()
  }
  class StepTracker {
    <<pure Dart>>
    applyRaw(state, rawCount, now) StepState
    addSteps(state, count, now) StepState
  }
  class StepDetector {
    <<pure Dart>>
    addSample(x, y, z, time) bool
  }
  class StepController {
    <<Notifier>>
    state StepView
    enable()
    disable()
    refresh()
    flush()
  }
  class NotificationService {
    <<interface>>
    requestPermission() bool
    scheduleDailyReminder(minutes)
    cancelDailyReminder()
    syncHabitReminder(habit)
    cancelHabitReminder(habitId)
    showGoalReached(steps, goal)
    cancelAll()
  }
  class WorkoutLogController {
    <<Notifier>>
    open(mode, workoutId)
    setMode(mode) setType(type)
    addExercise(exercise)
    updateSet(exercise, set, value)
    pause() resume()
    save() String
    discard() delete()
  }
  class CatalogueController {
    <<Notifier>>
    search(query)
    loadMore()
    retry()
  }

  StepController --> StepPlatform
  StepController --> StepTracker
  StepController --> StepDetector
  StepController --> StepRepository
  StepController --> LocalStore
  StepController --> NotificationService
  CatalogueController --> WgerApi
  WgerApi --> LocalStore
  WorkoutLogController --> WorkoutRepository
  WorkoutLogController --> LocalStore
```

## Sequence: sign in

```mermaid
sequenceDiagram
  actor U as User
  participant S as S01 Account access
  participant A as AuthRepository
  participant F as Firebase Authentication
  participant R as Router

  U->>S: email, password, Sign in
  S->>S: validate fields
  S->>A: signIn(email, password)
  A->>F: signInWithEmailAndPassword
  alt success
    F-->>A: user
    A-->>R: authState emits the user
    R->>R: redirect /auth to /home
  else failure
    F-->>A: error code
    A-->>S: AuthFailure(message)
    S-->>U: error shown, form kept
  end
```

## Sequence: log a workout with a wger exercise

```mermaid
sequenceDiagram
  actor U as User
  participant L as S04 Workout log
  participant C as WorkoutLogController
  participant X as S05/S06 Exercises
  participant W as WgerApi
  participant API as wger REST API
  participant D as LocalStore
  participant R as WorkoutRepository
  participant FS as Firestore

  U->>L: Start workout
  L->>C: open(mode: live)
  C->>R: newId(uid)
  C->>D: saveDraft
  U->>L: Add exercise
  L->>X: push /exercises
  X->>W: fetchExercises(query)
  W->>API: GET exerciseinfo/?name__search=...&language__code=en
  alt network ok
    API-->>W: JSON page
    W->>D: cache page
  else network fails
    W->>D: read cached page
  end
  W-->>X: exercises
  U->>X: open detail, Add to workout
  X-->>L: pop(exercise)
  L->>C: addExercise(exercise)
  C->>D: saveDraft
  U->>L: enter reps, weight, tick done
  U->>L: Finish and save
  L->>C: save()
  C->>C: check workout is complete
  C->>R: saveWorkout(uid, workout)
  R->>FS: set users/uid/workouts/id
  Note over R,FS: same ID on retry, so no duplicate
  C->>D: clear draft
  L-->>U: back to S03 with confirmation
```

## Sequence: step tracking and a denied permission

```mermaid
sequenceDiagram
  actor U as User
  participant P as S09 Steps
  participant SS as StepController
  participant OS as System permission
  participant SN as Step sensor (StepPlatform)
  participant T as StepTracker
  participant R as StepRepository
  participant N as NotificationService

  U->>P: Enable step tracking
  P->>SS: enable()
  SS->>OS: request activity recognition
  alt denied
    OS-->>SS: denied
    SS-->>P: status = denied
    P-->>U: "Step tracking is off", Enable, Continue without tracking
    Note over P: workouts and habits stay usable
  else granted
    OS-->>SS: granted
    SS->>SN: subscribe
    alt no step-counter sensor
      SN-->>SS: error
      SS->>SS: switch to accelerometer and StepDetector
    end
    loop each reading
      SN-->>SS: raw count
      SS->>T: applyRaw(state, raw, now)
      T-->>SS: new state with today's steps
      SS->>R: saveDay(uid, StepDay), batched
      opt goal reached for the first time today
        SS->>N: showGoalReached
      end
      SS-->>P: status = tracking, steps
    end
  end
```

## Sequence: tick a habit and update its streak

```mermaid
sequenceDiagram
  actor U as User
  participant H as S07 Habits
  participant R as HabitRepository
  participant FS as Firestore
  participant PR as Riverpod providers
  participant D as streaks.dart

  U->>H: tick "Stretch" for today
  H->>R: setCompleted(uid, habitId, date, true)
  R->>FS: set completions/habitId_date
  FS-->>PR: completions snapshot (local, pending sync)
  PR->>D: habitStreak(habit, completions, today)
  D-->>PR: streak length
  PR-->>H: rebuild with new streak
```

## Sequence: weekly summary

```mermaid
sequenceDiagram
  actor U as User
  participant S as S11 Weekly summary
  participant PR as Riverpod providers
  participant FS as Firestore cache
  participant D as weekly_summary.dart

  U->>S: open, or change week
  S->>PR: watch summary(weekStart)
  PR->>FS: workouts, habits, completions, step days
  FS-->>PR: records
  PR->>D: buildWeeklySummary(week) and (week - 1)
  D-->>PR: totals for both weeks
  PR->>D: compare(current, previous)
  D-->>PR: comparison sentences
  PR-->>S: summary
  S-->>U: cards and comparison, or "Comparison not available yet"
```
