import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mainproj/theme_notifier.dart';
import 'LandingPage.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'forgot_password.dart'; // Forgot password page
import 'firebase_options.dart'; // Firebase configuration
import 'package:provider/provider.dart'; // State management
import 'package:shared_preferences/shared_preferences.dart'; // Persistent storage
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'admin.dart'; // Admin dashboard

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone package
  tz.initializeTimeZones();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print('Firebase Initialized');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  // Initialize Local Notifications
  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: androidInitializationSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Wrap the app with a ChangeNotifierProvider for the global theme.
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const HabitTrackerApp(),
    ),
  );
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Consumer to get global theme values and apply them app-wide.
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Habit Tracker',
          theme: ThemeData.light(), // Light theme
          darkTheme: ThemeData.dark(), // Dark theme
          themeMode: themeProvider.ThemeNotifier(), // Use the selected theme mode
          // Central authentication handler
          home: const AuthHandler(),
          routes: {
            '/landing': (context) => const LandingPage(),
            '/signup': (context) => const SignupPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomeScreen(userEmail: '', userName: ''),
            '/forgotPassword': (context) => const ForgotPasswordPage(),
            '/admin': (context) => const AdminDashboard(), // Admin route
          },
        );
      },
    );
  }
}

// AuthHandler Widget
class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.data == null) {
          return const LandingPage(); // User not logged in
        }

        return FutureBuilder<Widget>(
          future: _checkUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${roleSnapshot.error}')),
              );
            }

            return roleSnapshot.data!;
          },
        );
      },
    );
  }

  // Check user role and navigate to the appropriate page
  Future<Widget> _checkUserRole(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      String role = userDoc['role'] ?? 'user'; // Default to 'user' role

      if (role == 'admin') {
        return const AdminDashboard();
      } else {
        return const HomeScreen(userEmail: '', userName: '');
      }
    } else {
      return const LandingPage();
    }
  }
}
