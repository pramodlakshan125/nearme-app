import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'services/app_notification_service.dart';
import 'services/local_profile_store.dart';
import 'views/profile/profile_input_screen.dart';
import 'views/radar/radar_discovery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = LocalProfileStore(preferences);
  final notifications = AppNotificationService();
  await notifications.initialize();
  final profile = store.readProfile();
  runApp(
    ProviderScope(
      overrides: [
        localProfileStoreProvider.overrideWithValue(store),
        appNotificationServiceProvider.overrideWithValue(notifications),
        initialProfileProvider.overrideWithValue(profile),
      ],
      child: const NearMeApp(),
    ),
  );
}

class NearMeApp extends ConsumerWidget {
  const NearMeApp({super.key});

  static const _background = Color(0xFF050708);
  static const _surface = Color(0xFF111719);
  static const _accent = Color(0xFF36BFC2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserModelProvider);
    return MaterialApp(
      title: 'NearMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          onPrimary: Color(0xFF041011),
          secondary: _accent,
          onSecondary: Color(0xFF041011),
          surface: _surface,
          onSurface: Color(0xFFF2F5F5),
          error: Color(0xFFE57373),
          onError: Color(0xFF1A0505),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Color(0xFFF2F5F5),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFFF2F5F5),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: _surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF222B2D)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF303A3C)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF303A3C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE57373)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16777B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF263234),
            disabledForegroundColor: Colors.white38,
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16777B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF263234),
            disabledForegroundColor: Colors.white38,
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8DDADC),
            side: const BorderSide(color: Color(0xFF37676A)),
            minimumSize: const Size(48, 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8DDADC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF20292B),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF222B2D),
          thickness: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _accent
                : const Color(0xFF8A9495),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _accent.withValues(alpha: 0.28)
                : const Color(0xFF303A3C),
          ),
        ),
        useMaterial3: true,
      ),
      home: profile == null
          ? const ProfileInputScreen()
          : const RadarDiscoveryScreen(),
    );
  }
}
