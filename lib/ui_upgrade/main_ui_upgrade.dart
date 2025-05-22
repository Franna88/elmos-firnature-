import 'package:flutter/material.dart';
import 'design_system/design_system.dart';
import 'sample_page.dart';
import 'screens/sop_list_screen.dart';
import 'screens/sop_viewer_screen.dart';

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
        '/': (context) => const SamplePage(),
        '/sop-list': (context) => const SOPListScreen(),
        '/sop-viewer': (context) => const SOPViewerScreen(sopId: 'SOP-001'),
      },
      initialRoute: '/sop-viewer', // Change to see different screens
    );
  }
}
