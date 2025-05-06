import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/item_selection_screen.dart';
import 'screens/timer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]); // Lock to landscape mode for tablets
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elmos MES Tablet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEB281E), // Elmos Red
          primary: const Color(0xFFEB281E), // Elmos Red
          secondary: const Color(0xFF2C2C2C), // Dark Gray
          onSecondary: const Color(0xFFFFFFFF), // White
          background: const Color(0xFFFFFFFF), // White
          surface: const Color(0xFFFFFFFF), // White
          onPrimary: const Color(0xFFFFFFFF), // White text on primary
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEB281E), // Elmos Red
          foregroundColor: Color(0xFFFFFFFF), // White text
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEB281E), // Elmos Red
            foregroundColor: const Color(0xFFFFFFFF), // White text
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFFFFFFF), // White
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Light gray background
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Color(0xFF2C2C2C), // Dark Gray
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF2C2C2C), // Dark Gray
          ),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/item_selection': (context) => const ItemSelectionScreen(),
        '/timer': (context) => const TimerScreen(),
      },
    );
  }
}

