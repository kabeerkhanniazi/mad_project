# Fitness and Habit Tracker

A Flutter app for Android and iOS: log workouts, reach a daily step goal, keep habits going and review your week.

> For fitness tracking and motivation only. This app does not provide medical advice.

| Requirement | Where it lives |
|---|---|
| Workout logs | Live and past logging, edit and delete, drafts that survive closing the app |
| Step goals | Daily goal, step streak, step-counter sensor with an accelerometer fallback |
| Progress charts | Weekly and monthly step chart, workout and habit totals |
| Weekly summaries | Totals per week with a comparison to the week before |
| REST API | Exercise catalogue from [wger](https://wger.de) (`lib/data/wger_api.dart`) |
| Hardware | Step sensor (`lib/services/step_service.dart`), notifications (`lib/services/notification_service.dart`) |
| Health disclaimer | Shown on Account access and on Settings; no calorie or health claims anywhere |
| Denied activity permission | Only the steps card changes; workouts, habits and summaries keep working |

Stack: Flutter 3.50, Riverpod, go_router, Firebase Authentication, Cloud Firestore.

## Documents

| File | Contents |
|---|---|
| [docs/project.md](docs/project.md) | Scope, the twelve screens, behaviour rules, V2 and V3 roadmap |
| [docs/plan.md](docs/plan.md) | What is done, what is left, the phone test checklist |
| [docs/architecture.md](docs/architecture.md) | Layers, folders, data model, how steps and notifications work |
| [docs/usecases.md](docs/usecases.md) | The seventeen use cases |
| [docs/diagrams.md](docs/diagrams.md) | System, navigation, domain, class and sequence diagrams |

## Run it

### In GitHub Codespaces

1. On the repository page choose **Code > Codespaces > Create codespace**.
2. Wait for the setup to finish. It installs Flutter and the Android SDK and takes about ten minutes.
3. Open a new terminal and run the tests:

```bash
flutter test
```

4. Preview the app in the browser:

```bash
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

The browser preview has no step sensor and no phone notifications, so it shows the "unavailable" state for steps. Everything else works.

### On an Android phone

Every push builds an APK with GitHub Actions.

1. Open the repository's **Actions** tab and pick the latest **Build** run.
2. Download **fitness-and-habit-tracker-apk** from the Artifacts section and unzip it.
3. Copy `app-release.apk` to the phone and open it. Allow installing from this source when asked.

To build it yourself in a Codespace:

```bash
flutter build apk --release
```

The file appears at `build/app/outputs/flutter-apk/app-release.apk`.

### On an iPhone

Building for iOS needs a Mac with Xcode; Codespaces cannot do it. The project is configured for iOS (bundle ID, motion usage text) but has not been run on an iPhone.

## Demo mode

Until Firebase is connected the app runs in demo mode. A banner says so, accounts and records live in memory, and everything is lost when the app closes. It is useful for looking around and is what the widget tests use.

To force demo mode after Firebase is connected:

```bash
flutter run --dart-define=DEMO=true
```

## Connect Firebase

This is needed once. It is free on the Spark plan. Registering an app in Firebase needs only the app's ID text; no code has to exist first.

1. Open <https://console.firebase.google.com> and select the project **fitness-and-habit-tracker**.
2. Turn on sign-in:
   1. In the left menu open **Build > Authentication** and press **Get started**.
   2. On the **Sign-in method** tab choose **Email/Password**, switch on **Enable**, press **Save**.
3. Create the database:
   1. In the left menu open **Build > Firestore Database** and press **Create database**.
   2. Pick a location near you, such as `asia-south1 (Mumbai)`. It cannot be changed later.
   3. Choose **Start in production mode** and press **Create**.
   4. Open the **Rules** tab, replace the text with the contents of [`firestore.rules`](firestore.rules), press **Publish**.
4. Register the Android app:
   1. Press the gear icon next to **Project Overview**, then **Project settings**.
   2. Under **Your apps** press the Android icon.
   3. In **Android package name** enter `com.kabeerkhanniazi.fithabit`.
   4. Press **Register app**, then **Download google-services.json**.
   5. Press **Next** until the dialog closes. The remaining steps on that page are not needed.
5. Optional, for iPhone: under **Your apps** press **Add app**, choose iOS, enter the same ID as the bundle ID, and download `GoogleService-Info.plist`.
6. Put the files in the project:
   - `google-services.json` goes in `android/app/`
   - `GoogleService-Info.plist` goes in `ios/Runner/`

   In a Codespace you can drag each file onto its folder in the file list.
7. Generate the configuration and commit it:

```bash
dart run tool/gen_firebase_options.dart
```

```bash
git add android/app/google-services.json lib/firebase_options.dart
```

```bash
git commit -m "Connect Firebase"
```

```bash
git push
```

The demo banner disappears on the next build. The values in these files identify the project and are not passwords; access to data is controlled by `firestore.rules`.

## Tests

```bash
flutter analyze
```

```bash
flutter test
```

The tests cover the streak rules, weekly summary, step counting, the wger client and the main flows of the app on the in-memory backend. Sensors, permission dialogs and notifications can only be checked on a phone; the checklist is in [docs/plan.md](docs/plan.md).

## Credits

Exercise names, descriptions and images come from [wger](https://wger.de) and are licensed [CC-BY-SA](https://creativecommons.org/licenses/by-sa/3.0/). The app shows the licence and author on each exercise.
