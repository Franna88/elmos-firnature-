import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';
import 'package:provider/provider.dart';

class DeepLinkHandler {
  static Future<void> handleInitialLink(BuildContext context, String? initialLink) async {
    if (initialLink != null) {
      await _handleLink(context, initialLink);
    }
  }
  
  static Future<void> handleLink(BuildContext context, String link) async {
    await _handleLink(context, link);
  }
  
  static Future<void> _handleLink(BuildContext context, String link) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Check if this is a sign-in link
    if (authService.isSignInWithEmailLink(link)) {
      await _handleSignInLink(context, authService, link);
    }
    
    // Add other deep link handling as needed
  }
  
  static Future<void> _handleSignInLink(
    BuildContext context, 
    AuthService authService, 
    String link
  ) async {
    // Get the email from cache
    String? email = await authService.getCachedEmailForSignIn();
    
    // If no email found, we need to ask the user for it
    if (email == null) {
      email = await _promptForEmail(context);
      if (email == null) {
        // User cancelled, do nothing
        return;
      }
    }
    
    try {
      // Show loading indicator
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Signing in...'),
          duration: Duration(seconds: 10),
        ),
      );
      
      // Sign in
      final success = await authService.signInWithEmailLink(email, link);
      
      // Dismiss loading indicator
      scaffoldMessenger.hideCurrentSnackBar();
      
      if (success) {
        // Clear the cached email
        await authService.clearCachedEmailForSignIn();
        
        // Show success message
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Successfully signed in!')),
        );
      } else {
        // Show error message
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to sign in with email link.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  static Future<String?> _promptForEmail(BuildContext context) async {
    String? email;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To complete sign-in, please enter the email address you used to request the sign-in link.'
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  email = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                email = null;
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CONTINUE'),
            ),
          ],
        );
      },
    );
    
    return email;
  }
} 