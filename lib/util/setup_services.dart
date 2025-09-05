import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Sets up any services or configurations needed for the app to run
void setupServices() {
  debugPrint('Setting up services...');

  // Configure Firestore settings if needed
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Other service configurations can be added here

  debugPrint('Services setup complete.');
}
