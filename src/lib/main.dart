import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pages/welcome.dart';
import 'pages/layout.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<GoogleSignInAccount?> currentUser =
    ValueNotifier<GoogleSignInAccount?>(null);

Future<void> initializeUser() async {
  try {
    final googleSignIn = GoogleSignIn();
    final user = googleSignIn.currentUser;
    if (user == null) {
      final silentUser = await googleSignIn.signInSilently();
      currentUser.value = silentUser;
    } else {
      currentUser.value = user;
    }
  } catch (e) {
    currentUser.value = null;
  }
}

Future<void> signOutUser() async {
  try {
    await GoogleSignIn().signOut();
  } catch (_) {
  } finally {
    currentUser.value = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode');
  switch (savedTheme) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
      break;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
      break;
    default:
      themeNotifier.value = ThemeMode.system;
  }
  await initializeUser();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: 'الدليل التعليمي',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontFamily: 'UI',
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'UI',
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: const Color(0xFF1E1E1E),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              selectedItemColor: Colors.teal,
              unselectedItemColor: Colors.grey,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF2C2C2C),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'UI',
              ),
              contentTextStyle: TextStyle(
                color: Colors.white70,
                fontFamily: 'UI',
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(color: Colors.grey),
              labelStyle: const TextStyle(color: Colors.teal),
            ),
          ),
          themeMode: currentTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: currentUser,
      builder: (context, user, _) {
        if (user == null) return const WelcomePage();
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if (data['completedFirstTimeSetup'] == true) {
                return const MainPage();
              }
            }
            return WelcomePage(user: user, forceShowForm: true);
          },
        );
      },
    );
  }
}
