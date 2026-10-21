import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'views/auth/auth_screen.dart';
import 'views/profile/profile_input_screen.dart';
import 'views/radar/radar_discovery_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  runApp(const ProviderScope(child: NearMeApp()));
}

class NearMeApp extends ConsumerWidget {
  const NearMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'NearMe - Proximity Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF0F2027),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const AuthScreen();
          }

          // Check if user has filled out their profile in Firestore
          final userModelAsync = ref.watch(currentUserModelProvider);
          return userModelAsync.when(
            data: (userModel) {
              if (userModel == null) {
                return const ProfileInputScreen();
              }
              final privateProfileAsync =
                  ref.watch(currentPrivateProfileProvider);
              return privateProfileAsync.when(
                data: (privateProfile) {
                  if (privateProfile == null ||
                      privateProfile.facebookUrl.isEmpty) {
                    return const ProfileInputScreen();
                  }
                  return const RadarDiscoveryScreen();
                },
                loading: () => const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                ),
                error: (err, stack) => Scaffold(
                  body: Center(
                    child: Text('Error loading private profile: $err'),
                  ),
                ),
              );
            },
            loading: () => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
            error: (err, stack) => Scaffold(
              body: Center(
                child: Text('Error loading profile: $err'),
              ),
            ),
          );
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('Authentication Error: $err'),
          ),
        ),
      ),
    );
  }
}
