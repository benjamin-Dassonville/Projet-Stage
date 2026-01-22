import 'package:flutter/material.dart';

import 'auth/auth_state.dart';
import 'app_state.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthState();
  await auth.init();
  authState = auth;

  runApp(App(auth: auth));
}

class App extends StatelessWidget {
  final AuthState auth;
  const App({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0));

    return MaterialApp.router(
      title: 'EPI Control',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
        ),

        // ✅ Flutter stable expects CardThemeData for ThemeData.cardTheme.
        cardTheme: CardThemeData(
          elevation: 0.5,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.35),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      routerConfig: buildRouter(auth),
    );
  }
}