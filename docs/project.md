# Project: Fitness and Habit Tracker

A Flutter app for Android and iOS that helps a person log workouts, reach a daily step goal, keep habits going and review their week.

| | |
|---|---|
| Course brief | Workout logs, step goals, progress charts and weekly summaries |
| Core loop | Log a workout, check progress, keep a streak |
| REST API | wger exercise database (`https://wger.de/api/v2/`) |
| Hardware | Step sensor, and notifications for daily goals |
| Constraint | Short health disclaimer, no medical claims, graceful handling of a denied activity permission |
| Stack | Flutter, Dart, Riverpod, go_router, Firebase Authentication, Cloud Firestore |
| Team | One developer, about 15 hours a week, 20 USD total budget |
| Dates | Wireframes 16 November 2026, V1 submission 31 December 2026 |
| Identifiers | Firebase project `fitness-and-habit-tracker`, app ID `com.kabeerkhanniazi.fithabit` |
| Test devices | Redmi A5, Samsung Galaxy A06 (Android), iPhone 14 (iOS, needs a Mac to build) |

## V1 scope

V1 is the course brief and nothing else. It has twelve screens, numbered as in the wireframes.

| # | Screen | Purpose | Uses |
|---|---|---|---|
| S01 | Account access | Sign in or create an account to keep records private | Firebase Authentication |
| S02 | Home | See today's activity and choose the next action | Firestore, step sensor |
| S03 | Workout history | Find past sessions and start or log a workout | Firestore |
| S04 | Workout log | Record a live session, or enter and edit a past one | Firestore |
| S05 | Exercise catalogue | Search the wger API and pick an exercise | wger REST API |
| S06 | Exercise detail | Read about an exercise before adding it | wger REST API |
| S07 | Habits | Tick off scheduled habits and see each streak | Firestore |
| S08 | Habit editor | Create a custom habit or start from a template | Firestore, notifications |
| S09 | Steps and daily goal | See recorded steps and set a daily target | Step sensor, Firestore |
| S10 | Progress | Compare steps, workouts and habit completion | Firestore |
| S11 | Weekly summary | Review a week's totals against the previous week | Firestore |
| S12 | Settings and profile | Manage targets, reminders, permissions and the account | Firestore, notifications |

## Behaviour rules

These rules were agreed during planning and the code follows them.

**Workouts**
- A workout is either a strength session (exercises with sets) or a timed activity (a duration).
- A strength session counts as completed when at least one set is marked done. A timed activity counts when its duration is above zero.
- Weight is optional, so bodyweight exercises are valid.
- Each workout gets its ID when the draft is created, so saving twice never creates two sessions.
- A draft survives leaving the screen and closing the app.

**Habits**
- A habit repeats on chosen weekdays and takes one tick per scheduled day.
- A missed scheduled day ends that habit's streak. Unscheduled days are neutral.
- Today does not break a streak until it is over.
- Archiving a habit hides it and keeps its past completions.

**Steps**
- The daily total is what the phone recorded while tracking was available. The screen says when recording started that day.
- A day with no recording is shown as "not tracked", never as zero steps.
- The step streak counts consecutive days on which the goal was reached. Today stays pending until the goal is reached or the day ends.
- Each day keeps the goal that applied on that day, so changing the goal does not rewrite history.
- Permission denied, sensor missing and notifications denied are three separate conditions. None of them blocks workouts or habits.

**Weeks and summaries**
- A week runs Monday to Sunday in the phone's timezone.
- The weekly workout target defaults to three sessions and can be changed.
- Summaries are calculated from saved records. There is no AI in V1.
- With no earlier week to compare against, the summary says "Comparison not available yet".

**Health and privacy**
- The disclaimer reads: "For fitness tracking and motivation only. This app does not provide medical advice."
- It appears on Account access and on Settings.
- The app shows no calorie estimates, body scores or health claims.
- Each person can read and write only their own records.
- Deleting the account removes its cloud records and local data.

## Roadmap after V1

These ideas are the owner's vision for later versions. None of them is in V1 code. Each needs its open decisions settled before work starts.

### V2: training companion

An avatar that starts with the user on day one and develops as they train.

- The user builds the avatar's look with appearance controls and optional measurements.
- Logged activity earns experience, development stages, animations and cosmetic rewards.
- Progress is kept after a quiet period. The avatar never deteriorates.

Open decisions:
- 2D or 3D, and how stylised
- Which physical features can be customised
- Whether physique change shows game progress, user-reported change, or both as separate things
- Whether the companion can chat, and if so which AI provider and who pays for it

Guardrail: height, weight and workout logs cannot show what someone's body looks like. The avatar's growth is a game mechanic and the app must say so.

### V3: leaderboard and social area

- An opt-in weekly leaderboard that rewards consistency and effort.
- A social space where users' avatars meet, share work ethic and form friendships or rivalries.

Open decisions:
- How "effort" is scored fairly across walking, running and lifting
- Whether manually entered activity earns points
- Whether avatars act only on user actions, on milestones, or autonomously
- What a public profile shows, and blocking and reporting

Guardrail: a public leaderboard needs server-side score validation, which means a paid Firebase plan or another backend.

### How V1 prepares for this

V1 stores workouts, habit completions and daily steps as dated records per user. Companion experience and leaderboard scores can be calculated from those same records later, so V2 needs no data migration.
