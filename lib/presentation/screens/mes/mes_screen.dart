import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../mes_tablet/screens/login_screen.dart' as mes_login;
import '../../../mes_tablet/screens/item_selection_screen.dart' as mes_items;
import '../../../mes_tablet/screens/timer_screen.dart' as mes_timer;

class MESScreen extends StatelessWidget {
  const MESScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // Check if this is on a mobile or tablet device
    final bool isMobile = MediaQuery.of(context).size.width <= 1024;

    // If on mobile/tablet, directly show the MES login screen
    if (isMobile) {
      return const MESTabletApp();
    }

    // Otherwise show a launcher screen for desktop
    return AppScaffold(
      title: 'MES - Manufacturing Execution System',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.factory_outlined,
              size: 80,
              color: AppColors.primaryRed,
            ),
            const SizedBox(height: 24),
            const Text(
              'Manufacturing Execution System',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Production management and machine tracking',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.launch),
              label: const Text('Launch MES Application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                // Launch the MES tablet app
                if (kDebugMode) {
                  print(
                      'Launching MES application for ${authService.userName}');
                }
                _launchMESApplication(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _launchMESApplication(BuildContext context) {
    // Show dialog with instructions and option to launch the MES app
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryRed),
              const SizedBox(width: 12),
              const Text('MES Application'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The MES Tablet Application is being launched.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'This application runs separately from the SOP Management System. '
                'It provides functionality for production tracking, machine monitoring, '
                'and other manufacturing operations.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();

                // Launch the MES tablet app in a new window/view
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MESTabletApp(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }
}

// Wrapper for MES Tablet App
class MESTabletApp extends StatelessWidget {
  const MESTabletApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up the theme similar to the MES tablet app
    return Theme(
      data: ThemeData(
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
      ),
      child: Scaffold(
        body: const mes_login.LoginScreen(),
        // Add a back button if we're not on a mobile device
        floatingActionButton: MediaQuery.of(context).size.width > 1024
            ? FloatingActionButton(
                onPressed: () => Navigator.of(context).pop(),
                backgroundColor: const Color(0xFFEB281E),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}
