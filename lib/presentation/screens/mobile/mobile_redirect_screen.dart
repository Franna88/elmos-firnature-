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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redirecting...',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
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
