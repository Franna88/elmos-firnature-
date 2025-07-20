import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/services/mes_service.dart';
import '../data/services/auth_service.dart';
import '../core/theme/app_theme.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MESService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Elmos MES Tablet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme.copyWith(
          // Tablet-specific customizations while maintaining consistency
          appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
          // Override scaffold background for tablet landscape use
          scaffoldBackgroundColor: AppColors.backgroundWhite,
        ),
        home: const LoginScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/item_selection': (context) => const ItemSelectionScreen(),
          '/timer': (context) => const TimerScreen(),
        },
      ),
    );
  }
}
