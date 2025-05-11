import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../mes_tablet/tablet_mes_main.dart' as mes_app;

class MESScreen extends StatelessWidget {
  const MESScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

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
    // Use the tablet MES app but with a way to navigate back
    return Scaffold(
      appBar: AppBar(
        title: const Text('MES Tablet Application'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const MESTabletContent(),
    );
  }
}

// This embeds the MES tablet app content
class MESTabletContent extends StatelessWidget {
  const MESTabletContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Create the MES app but without MaterialApp wrapper
    return Builder(
      builder: (context) {
        // Force landscape orientation for the tablet app
        return OrientationBuilder(
          builder: (context, orientation) {
            // Launch the MES tablet application
            return const mes_app.MyApp();
          },
        );
      },
    );
  }
}
