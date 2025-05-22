import 'package:flutter/material.dart';
import 'design_system/design_system.dart';
import 'sample_page.dart';
import 'screens/screens.dart';

/// Entry point for the UI upgrade demo
void main() {
  runApp(const UIUpgradeApp());
}

/// The main application widget for the UI upgrade demo
class UIUpgradeApp extends StatelessWidget {
  const UIUpgradeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elmos Furniture - UI Upgrade',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/password-reset': (context) => const PasswordResetScreen(),
        '/dashboard': (context) => const SamplePage(),
        '/profile': (context) => const UserProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/users': (context) => const UserListScreen(),
        '/sop-list': (context) => const SOPListScreen(),
        '/sop-viewer': (context) => const SOPViewerScreen(sopId: 'SOP-001'),
        '/sop-categories': (context) => const SOPCategoryManagementScreen(),
      },
      initialRoute: '/', // Start with login screen
    );
  }
}
