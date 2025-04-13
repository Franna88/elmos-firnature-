import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileRedirectScreen extends StatelessWidget {
  const MobileRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Automatically redirect to mobile SOPs screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/mobile/sops');
    });

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading mobile view...'),
          ],
        ),
      ),
    );
  }
}
