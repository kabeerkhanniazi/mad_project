# Use cases

Actor in every case: a signed-in **user**, unless stated. Screen numbers match [project.md](project.md).

## Summary

| ID | Use case | Screens |
|---|---|---|
| UC-01 | Create an account | S01 |
| UC-02 | Sign in, sign out, reset password | S01, S12 |
| UC-03 | Log a live workout | S02/S03, S04 |
| UC-04 | Log a past workout | S02/S03, S04 |
| UC-05 | Find and add an exercise | S04, S05, S06 |
| UC-06 | Edit or delete a workout | S03, S04 |
| UC-07 | Create or edit a habit | S07, S08 |
| UC-08 | Complete a habit and keep a streak | S07 |
| UC-09 | Turn on step tracking | S09 |
| UC-10 | Continue after denying activity permission | S09, S02 |
| UC-11 | Set a daily step goal | S09 |
| UC-12 | Receive goal notifications | S08, S09, S12 |
| UC-13 | Check progress | S02, S10 |
| UC-14 | Review a weekly summary | S11 |
| UC-15 | Change preferences | S12 |
| UC-16 | Delete account and data | S12 |
| UC-17 | Use the app offline | all |

## UC-01 Create an account
- **Actor:** visitor
- **Goal:** get a private account
- **Main flow**
  1. The visitor opens the app and sees Account access with the health disclaimer.
  2. They choose Create account and enter a display name, email, password and password confirmation.
  3. The app validates the fields and creates the account in Firebase Authentication.
  4. The app creates the profile with default targets and opens Home.
- **Alternatives**
  - Invalid email, short password or mismatched confirmation: the field shows the problem and nothing is sent.
  - Email already in use or no connection: the form stays filled and shows an error that can be retried.

## UC-02 Sign in, sign out, reset password
- **Main flow**
  1. The user enters email and password and taps Sign in.
  2. The app opens Home.
- **Alternatives**
  - Wrong credentials: an error appears and the form stays filled.
  - Forgot password: a dialog takes the email and Firebase sends a reset link.
  - Sign out from Settings returns to Account access.

## UC-03 Log a live workout
- **Trigger:** Start workout on Home or Workout history
- **Main flow**
  1. The app opens Workout log in live mode and starts the timer.
  2. The user names the workout and adds exercises (UC-05).
  3. For each set they enter reps and optional weight and tick it done.
  4. They can pause and resume the timer.
  5. They tap Finish and save. The app stores the workout and returns to Workout history with a confirmation.
- **Alternatives**
  - Timed activity: the user picks the timed type, and the elapsed time is the result.
  - Nothing completed: the app explains that a set must be ticked, or a duration recorded, before saving.
  - Leaving the screen: the draft is kept. Reopening offers to continue or discard it.
  - Save fails: the input stays on screen and can be saved again without creating a duplicate.

## UC-04 Log a past workout
- **Main flow**
  1. The user taps Log a past workout.
  2. They enter the date, start time and duration, then the exercises and sets.
  3. They save, and the workout appears in history on its own date.
- **Alternatives**
  - A future date is not offered.

## UC-05 Find and add an exercise
- **Main flow**
  1. From Workout log the user taps Add exercise.
  2. Exercise catalogue loads exercises from the wger API.
  3. The user searches by name or filters by category and equipment.
  4. They tap an exercise to read its detail: image, muscles, equipment, description and licence.
  5. They tap Add to workout and return to Workout log with the exercise added.
- **Alternatives**
  - API unreachable: cached results are shown if there are any, with Retry.
  - No results: the screen says so and offers a manual exercise.
  - Manual exercise: the user types a name and adds it without the API.
  - No image: a placeholder is shown.

## UC-06 Edit or delete a workout
- **Main flow**
  1. The user taps a workout in history.
  2. Workout log opens with the saved values.
  3. They change values and save, or tap Delete and confirm.
  4. The weekly target, charts and summaries reflect the change.

## UC-07 Create or edit a habit
- **Main flow**
  1. The user taps Add habit, or Edit on a habit.
  2. They type a name, or pick a fitness template that fills the fields.
  3. They choose the weekdays and optionally a reminder time.
  4. They save and return to Habits.
- **Alternatives**
  - No weekday selected, or empty name: the app asks for it.
  - Notification permission denied: the habit is saved without a reminder and the screen explains why.
  - Archive (edit only): the habit leaves the list and its history is kept.

## UC-08 Complete a habit and keep a streak
- **Main flow**
  1. Habits shows the habits scheduled for the selected day.
  2. The user ticks a habit. The completion is stored for that habit and date.
  3. The streak beside the habit updates.
- **Alternatives**
  - Unticking removes the completion and the streak is recalculated.
  - The date arrows show earlier days, where completions can also be corrected.
  - A missed scheduled day resets that habit's streak. Unscheduled days do not.

## UC-09 Turn on step tracking
- **Main flow**
  1. On Steps and daily goal the user taps Enable step tracking.
  2. The app explains why it needs activity access and the system dialog appears.
  3. The user allows it. The app starts reading the step sensor and shows today's count against the goal.
- **Alternatives**
  - No step-counter sensor: the app counts with the accelerometer while it is open and labels the count accordingly.
  - No usable sensor at all: the screen says "Step counting is unavailable on this device".

## UC-10 Continue after denying activity permission
- **Main flow**
  1. The user denies the system dialog.
  2. Steps shows "Step tracking is off" with Enable and Continue without tracking.
  3. Home shows the same message on the steps card only. Workouts, habits, progress and summaries keep working.
- **Alternatives**
  - Permanently denied: the button opens the system settings page. On return the app rechecks access.
  - The app does not prompt again by itself.

## UC-11 Set a daily step goal
- **Main flow**
  1. The user enters a goal between 1,000 and 100,000 and taps Save goal.
  2. The goal applies from today. Earlier days keep the goal they had.

## UC-12 Receive goal notifications
- **Main flow**
  1. In Settings the user turns on the daily reminder and picks a time.
  2. The app asks for notification permission the first time.
  3. Each day at that time the phone shows a reminder to check the day's goals.
  4. When the step count reaches the goal while the app is tracking, a "goal reached" notification appears once that day.
  5. Habits with a reminder notify at their time on their scheduled weekdays.
- **Alternatives**
  - Permission denied: the switches turn off, the reason is shown, and tracking continues.

## UC-13 Check progress
- **Main flow**
  1. Home shows today's steps, habits done and workouts this week.
  2. Progress shows a step chart for the week or month, workout count and minutes, and habit completion.
- **Alternatives**
  - Days without step recording appear as gaps in the chart.
  - No records yet: each section invites a first entry.

## UC-14 Review a weekly summary
- **Main flow**
  1. The user opens Weekly summary from Home or Progress.
  2. It shows the last completed week: workouts against target, minutes, steps recorded, days the goal was met, and habits done out of those due.
  3. A comparison with the week before is shown in words.
  4. Arrows move to other weeks.
- **Alternatives**
  - No earlier week: "Comparison not available yet".

## UC-15 Change preferences
- **Main flow**
  1. Settings opens from any root tab.
  2. The user edits display name, weekly workout target and the daily reminder, then saves.

## UC-16 Delete account and data
- **Main flow**
  1. The user taps Delete account and data in Settings.
  2. A dialog explains what is removed and asks for the password.
  3. The app deletes the user's Firestore records, local data and the account, then returns to Account access.
- **Alternatives**
  - Wrong password: nothing is deleted.

## UC-17 Use the app offline
- **Main flow**
  1. Without a connection the app shows records from the local Firestore cache.
  2. New and changed records are saved locally and marked "Pending sync".
  3. When the connection returns, Firestore sends them and the mark disappears.
- **Alternatives**
  - The exercise catalogue needs the network unless a matching search was cached. A manual exercise is always available.
