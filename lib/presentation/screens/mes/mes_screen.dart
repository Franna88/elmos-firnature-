import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/mes_service.dart';
import '../../widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../mes_tablet/screens/login_screen.dart' as mes_login;
import '../../../mes_tablet/screens/item_selection_screen.dart' as mes_items;
import '../../../mes_tablet/screens/timer_screen.dart' as mes_timer;
import '../../../mes_tablet/models/user.dart' as mes_model;
import '../../../mes_tablet/screens/process_selection_screen.dart'
    as mes_process;

class MESScreen extends StatelessWidget {
  const MESScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // Check if this is on a mobile or tablet device
    final bool isMobile = _isMobileDevice(context);

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
              color: AppColors.primaryBlue,
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
                backgroundColor: AppColors.primaryBlue,
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
              Icon(Icons.info_outline, color: AppColors.primaryBlue),
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
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to safely detect mobile device
  bool _isMobileDevice(BuildContext context) {
    try {
      final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery == null) {
        return false; // Fallback to desktop
      }
      return mediaQuery.size.width <= 1200;
    } catch (e) {
      debugPrint('Warning: Could not access MediaQuery in MES screen: $e');
      return false; // Fallback to desktop
    }
  }
}

// Wrapper for MES Tablet App
class MESTabletApp extends StatelessWidget {
  const MESTabletApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access services from parent context
    final authService = Provider.of<AuthService>(context);

    // We need to use MaterialApp to provide proper route navigation within the MES tablet
    return MaterialApp(
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
        scaffoldBackgroundColor: AppColors.backgroundWhite,
      ),
      // Define all the required routes
      routes: {
        '/login': (context) => const mes_login.LoginScreen(),
        '/process_selection': (context) =>
            const mes_process.ProcessSelectionScreen(),
        '/item_selection': (context) => const mes_items.ItemSelectionScreen(),
        '/timer': (context) => const mes_timer.TimerScreen(),
      },
      // Create the main screen with embedded providers
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authService),
          ChangeNotifierProvider(create: (_) => MESService()),
        ],
        child: Builder(
          builder: (context) {
            // Scaffold with back button
            return Scaffold(
              body: _buildMainContent(context, authService),
              // Add debug overlay that shows screen dimensions
              bottomSheet: kDebugMode ? _buildDimensionsOverlay(context) : null,
            );
          },
        ),
      ),
    );
  }

  // Separate method to build the main content
  Widget _buildMainContent(BuildContext context, AuthService authService) {
    // Check if user is already logged in
    if (authService.isLoggedIn) {
      // Create a user object from current auth data to pass to process selection screen
      final user = mes_model.User(
        id: authService.userId ?? 'unknown',
        name: authService.userName ?? 'User',
        role: authService.userRole ?? 'operator',
        email: authService.userEmail,
      );

      // Skip login and go to process selection (new flow: Process → Items → Timer)
      return mes_process.ProcessSelectionScreen(initialUser: user);
    } else {
      // If not logged in (rare case), show login screen
      return const mes_login.LoginScreen();
    }
  }

  // Debug widget to show screen dimensions
  Widget _buildDimensionsOverlay(BuildContext context) {
    try {
      final size = MediaQuery.maybeOf(context)?.size ?? const Size(0, 0);
      return Container(
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Text(
          'Screen: ${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    } catch (e) {
      // Return empty container if MediaQuery access fails
      return const SizedBox.shrink();
    }
  }
}
