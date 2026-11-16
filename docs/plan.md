# Plan

Dates: wireframes 16 November 2026, V1 submission 31 December 2026.

## Where V1 stands

All twelve screens are built and the code is checked in three ways: the analyzer reports no issues, the automated tests pass, and the Android APK builds. Screens were also run in a browser in demo mode.

| Area | Built | Checked by tests | Checked on a phone |
|---|---|---|---|
| S01 Account access: sign in, create account, reset password | Yes | Yes (demo backend) | Not yet |
| S02 Home: loading, empty, error, with data | Yes | Yes | Not yet |
| S03, S04 Workouts: live, past, edit, delete, draft | Yes | Yes | Not yet |
| S05, S06 wger catalogue: search, filters, detail, offline cache, manual exercise | Yes | Yes, plus the live API | Not yet |
| S07, S08 Habits: schedule, tick, streak, templates, archive | Yes | Yes | Not yet |
| S09 Steps: goal, streak, permission states, accelerometer fallback | Yes | Yes (fake sensor) | Not yet |
| S10, S11 Progress chart and weekly summary | Yes | Yes | Not yet |
| S12 Settings: targets, reminder, sign out, delete account | Yes | Yes | Not yet |
| Notifications: daily reminder, habit reminders, goal reached | Yes | Scheduling logic only | Not yet |
| Firebase Authentication and Firestore | Yes | No | Not yet |
| iOS | Configured | No | Not yet, needs a Mac |

"Not yet" in the last column is the remaining work. Nothing that needs a real phone, a real Firebase project or a Mac could be checked from the build environment.

## What is left, in order

### 1. Connect Firebase (about 15 minutes)

Follow "Connect Firebase" in the [README](../README.md). Until this is done the app runs in demo mode.

Then check in the Firebase console that:
- a new account appears under Authentication
- a workout appears under Firestore at `users/{uid}/workouts`

### 2. Test on the Android phones

Install the APK from GitHub Actions on the Redmi A5 and the Galaxy A06 and go through the checklist below. Note the phone model and Android version with each result.

### 3. Fix what the phones reveal

Sensor behaviour differs between phones. Expect to adjust at least the accelerometer threshold in `lib/domain/step_detector.dart` if a phone has no step-counter sensor.

### 4. iOS, if a Mac becomes available

Open `ios/Runner.xcworkspace` in Xcode, set a development team, add `GoogleService-Info.plist`, and run on the iPhone 14. Step permission on iOS is handled by the system the first time steps are read.

### 5. Submission

Record a short demo, check the README and export the diagrams if the course wants them on paper.

## Schedule to the deadline

| Week | Hours | Work |
|---|---|---|
| 16 to 22 Nov | 15 | Wireframe review. Connect Firebase. First install on both Android phones. Read through `lib/domain/` and `lib/providers.dart` until every line can be explained. |
| 23 to 29 Nov | 15 | Phone checklist: accounts, workouts, habits. Read `lib/data/` alongside the Firebase lessons. |
| 30 Nov to 6 Dec | 15 | Phone checklist: steps and permissions on both phones. Tune the step detector. |
| 7 to 13 Dec | 15 | Phone checklist: notifications and offline behaviour. |
| 14 to 20 Dec | 15 | Fix findings. Second full pass of the checklist. |
| 21 to 27 Dec | 15 | iOS if possible. Demo recording. |
| 28 to 31 Dec | 8 | Final regression and submission. |

## Phone test checklist

### Accounts
- [ ] Create an account. It appears in the Firebase console.
- [ ] Sign out and sign in again. Records are still there.
- [ ] Wrong password shows an error and keeps the email.
- [ ] Forgot password sends an email.
- [ ] Install on the second phone, sign in, and see the same records.
- [ ] A second account cannot see the first account's records.

### Workouts and wger
- [ ] Start a live workout, add an exercise from the catalogue, tick a set, save.
- [ ] The timer keeps the right time after the app is closed and reopened.
- [ ] Log a past workout on an earlier date. It appears on that date.
- [ ] Edit and delete a workout. The weekly target and charts follow.
- [ ] Search, category and equipment filters return sensible results.
- [ ] Exercise detail shows an image where wger has one, and the licence.
- [ ] In flight mode the catalogue shows saved results or an error with Retry, and a manual exercise can be added.

### Habits
- [ ] Create a custom habit and one from a template.
- [ ] Tick and untick. The streak changes.
- [ ] Go back a day with the arrow and tick yesterday. The streak follows.
- [ ] A habit set for Mon/Wed/Fri keeps its streak across a Tuesday.
- [ ] Archive a habit. It leaves the list and last week's summary still counts it.

### Steps and permission
- [ ] Enable step tracking and allow the permission. Walk 50 steps. The count is close.
- [ ] Note which message Steps shows: phone sensor or counted by the app.
- [ ] Close the app, walk, reopen. On a phone with a step sensor the steps are added.
- [ ] Deny the permission. Steps shows "Step tracking is off"; Home changes only the steps card; workouts and habits work.
- [ ] Deny twice so Android stops asking. The button becomes Open settings. Allow it there, return, and tracking starts.
- [ ] Revoke the permission in system settings while the app is closed. The app opens without crashing and shows tracking as off.
- [ ] Restart the phone during the day. Today's total is kept.
- [ ] Leave the app overnight. Yesterday's total is kept and today starts again.
- [ ] Set a low goal and pass it. One "Step goal reached" notification appears.

### Notifications
- [ ] Turn on the daily reminder for two minutes ahead and allow notifications. It arrives. The timing is approximate by design.
- [ ] Deny notification permission. The switch turns off with an explanation and preferences still save.
- [ ] A habit reminder arrives on a scheduled day.
- [ ] Reminders still arrive after restarting the phone.

### Offline
- [ ] In flight mode, log a workout and tick a habit. Both appear at once; the workout shows "Pending sync".
- [ ] Turn the connection back on. "Pending sync" disappears and the records are in the Firebase console.

### Summary and settings
- [ ] Weekly summary matches the records for that week.
- [ ] The first week shows "Comparison not available yet".
- [ ] Change the weekly target. Home and Workouts show it.
- [ ] Delete account with a wrong password does nothing. With the right password the account and its Firestore records are gone.

## Known limits of V1

- **Steps are counted only around app use.** There is no background service. On a phone with a step-counter sensor, steps taken while the app is closed are added on reopening, as long as the app was opened earlier that day. Steps before the first opening of a day are not counted.
- **Accelerometer fallback is approximate** and works only while the app is open.
- **Reminder times are approximate.** Android may deliver them some minutes late, in exchange for needing no extra permission.
- **Goal-reached notification needs the app to be tracking** at the moment the goal is passed.
- **One timezone.** Days follow the phone's timezone; travelling across timezones can shift a late-night entry to the next day.
- **iOS is untested.**

## After V1

The companion avatar (V2) and the leaderboard and social area (V3) are described in [project.md](project.md). They start only after the V1 submission, and each needs its open decisions settled first.
