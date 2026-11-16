import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_config.dart';
import 'core/router.dart';

class FitHabitApp extends ConsumerWidget {
  const FitHabitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1F6F5C),
            brightness: brightness,
          ),
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          cardTheme: const CardThemeData(margin: EdgeInsets.only(bottom: 12)),
        );

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
