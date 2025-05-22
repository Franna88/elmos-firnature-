import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/mes_service.dart';
import '../../widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../mes_tablet/screens/login_screen.dart' as mes_login;
import '../../../mes_tablet/screens/item_selection_screen.dart' as mes_items;
import '../../../mes_tablet/screens/timer_screen.dart' as mes_timer;
import '../../../mes_tablet/models/user.dart' as mes_model;

class MESScreen extends StatelessWidget {
  const MESScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // Check if this is on a mobile or tablet device
    final bool isMobile = MediaQuery.of(context).size.width <= 1200;

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
      ),
      // Define all the required routes
      routes: {
        '/login': (context) => const mes_login.LoginScreen(),
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
              // Add a back button if we're not on a mobile device
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  // Check if we're in the mobile view (width <= 1200)
                  if (MediaQuery.of(context).size.width <= 1200) {
                    // Navigate to mobile selection screen
                    Navigator.of(context).pop();
                    if (context.mounted) {
                      GoRouter.of(context).go('/mobile/selection');
                    }
                  } else {
                    // Just pop back to previous screen on desktop
                    Navigator.of(context).pop();
                  }
                },
                backgroundColor: const Color(0xFFEB281E),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
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
      // Create a user object from current auth data to pass to item selection screen
      final user = mes_model.User(
        id: authService.userId ?? 'unknown',
        name: authService.userName ?? 'User',
        role: authService.userRole ?? 'operator',
        email: authService.userEmail,
      );

      // Skip login and go directly to item selection
      return mes_items.ItemSelectionScreen(initialUser: user);
    } else {
      // If not logged in (rare case), show login screen
      return const mes_login.LoginScreen();
    }
  }

  // Debug widget to show screen dimensions
  Widget _buildDimensionsOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Text(
        'Screen: ${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)}',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
