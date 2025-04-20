import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sop_model.dart';
import 'qr_code_service.dart';
import 'dart:convert';

class SOPService extends ChangeNotifier {
  // QR Code Service
  final QRCodeService _qrCodeService = QRCodeService();

  // Firebase services
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAuth? _auth;

  List<SOP> _sops = [];
  List<SOPTemplate> _templates = [];

  // Map to track SOPs with unsaved changes
  final Map<String, SOP> _localChanges = {};

  List<SOP> get sops => List.unmodifiable(_sops);
  List<SOPTemplate> get templates => List.unmodifiable(_templates);

  SOPService() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize Firebase services
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _auth = FirebaseAuth.instance;

      if (kDebugMode) {
        print('Firebase initialization status:');
        print('- Firestore: ${_firestore != null ? "initialized" : "failed"}');
        print('- Storage: ${_storage != null ? "initialized" : "failed"}');
        print('- Auth: ${_auth != null ? "initialized" : "failed"}');
      }

      // Test if Firestore is working by creating test collections if needed
      await _ensureCollectionsExist();

      if (kDebugMode) {
        print('✅ Using Firebase Firestore for SOP data');
      }

      await _loadTemplates();
      await _loadSOPs();

      // Listen for SOP changes
      _listenForSOPChanges();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization error in SOPService: $e');
        print('Firebase connection failed');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      throw Exception('Firebase connection failed: $e');
    }
  }

  Future<void> _ensureCollectionsExist() async {
    try {
      if (kDebugMode) {
        print('Checking Firestore collections...');
      }

      // Check if 'sops' collection exists by trying to get a document
      final sopsSnapshot = await _firestore!.collection('sops').limit(1).get();

      if (kDebugMode) {
        print(
            '- "sops" collection check: ${sopsSnapshot.size} documents found');
      }

      // If collection is empty, create a test document that we'll delete right away
      // This ensures the collection exists in Firestore
      if (sopsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('Creating initial collections in Firestore');
        }

        // Create a temporary document in sops collection with embedded steps
        final docRef = await _firestore!.collection('sops').add({
          'title': 'Test SOP',
          'createdAt': Timestamp.now(),
          'isTestDocument': true,
          'steps': [
            {
              'id': 'test_step_1',
              'title': 'Test Step',
              'instruction': 'Test instruction',
              'createdAt': Timestamp.now(),
            }
          ]
        });

        if (kDebugMode) {
          print('- Created test document with ID: ${docRef.id}');
        }

        // Delete the test document
        await docRef.delete();

        if (kDebugMode) {
          print('- Test document successfully deleted');
        }
      }

      // Check if 'templates' collection exists
      final templatesSnapshot =
          await _firestore!.collection('templates').limit(1).get();

      if (kDebugMode) {
        print(
            '- "templates" collection check: ${templatesSnapshot.size} documents found');
      }

      if (templatesSnapshot.docs.isEmpty) {
        // Create a temporary document in templates collection
        final templateRef = await _firestore!.collection('templates').add({
          'title': 'Test Template',
          'category': 'Test',
          'isTestDocument': true,
        });

        if (kDebugMode) {
          print('- Created test template with ID: ${templateRef.id}');
        }

        // Delete the test document
        await templateRef.delete();

        if (kDebugMode) {
          print('- Test template successfully deleted');
        }
      }

      if (kDebugMode) {
        print('✅ Firestore collection checks complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring collections exist: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      throw e; // Re-throw to be caught by the caller
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final snapshot = await _firestore!.collection('templates').get();
      final List<SOPTemplate> loadedTemplates = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedTemplates.add(SOPTemplate(
          id: doc.id,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          thumbnailUrl: data['thumbnailUrl'],
        ));
      }

      _templates = loadedTemplates;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading templates: $e');
      }
      throw Exception('Failed to load templates: $e');
    }
  }

  void _listenForSOPChanges() {
    if (_firestore == null) return;

    try {
      // Listen for changes to the SOPs collection
      _firestore!.collection('sops').snapshots().listen((snapshot) {
        if (snapshot.docChanges.isNotEmpty) {
          if (kDebugMode) {
            print('SOP changes detected, reloading SOPs...');
          }
          _loadSOPs(); // Reload all SOPs when changes are detected
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up SOP listener: $e');
      }
    }
  }

  Future<void> _loadSOPs() async {
    try {
      if (kDebugMode) {
        print('Attempting to load SOPs from Firestore...');
      }

      // Get all SOPs from Firestore
      final snapshot = await _firestore!.collection('sops').get();

      if (kDebugMode) {
        print('Retrieved ${snapshot.docs.length} SOPs from Firestore');
      }

      final List<SOP> loadedSOPs = [];

      for (var doc in snapshot.docs) {
        final sopData = doc.data();

        if (kDebugMode) {
          print(
              'Processing SOP document ID: ${doc.id}, title: ${sopData['title']}');
        }

        // Extract steps directly from the SOP document
        final List<SOPStep> steps = [];

        if (sopData['steps'] != null) {
          // Process each step from the steps array in the document
          final stepsList = sopData['steps'] as List<dynamic>;

          if (kDebugMode) {
            print('- Found ${stepsList.length} steps in SOP document');
          }

          for (var stepData in stepsList) {
            steps.add(SOPStep(
              id: stepData['id'] ?? '',
              title: stepData['title'] ?? '',
              instruction: stepData['instruction'] ?? '',
              imageUrl: stepData['imageUrl'],
              helpNote: stepData['helpNote'],
              assignedTo: stepData['assignedTo'],
              estimatedTime: stepData['estimatedTime'],
              stepTools: stepData['stepTools'] != null
                  ? List<String>.from(stepData['stepTools'])
                  : [],
              stepHazards: stepData['stepHazards'] != null
                  ? List<String>.from(stepData['stepHazards'])
                  : [],
            ));
          }
        } else {
          if (kDebugMode) {
            print('❌ Warning: No steps array found in SOP document ${doc.id}');
          }
        }

        loadedSOPs.add(SOP(
          id: doc.id,
          title: sopData['title'] ?? '',
          description: sopData['description'] ?? '',
          categoryId: sopData['categoryId'] ?? '',
          categoryName: sopData['categoryName'] ?? '',
          revisionNumber: sopData['revisionNumber'] ?? 1,
          createdBy: sopData['createdBy'] ?? '',
          createdAt:
              (sopData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (sopData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          steps: steps,
          tools: List<String>.from(sopData['tools'] ?? []),
          safetyRequirements:
              List<String>.from(sopData['safetyRequirements'] ?? []),
          cautions: List<String>.from(sopData['cautions'] ?? []),
          qrCodeUrl: sopData['qrCodeUrl'],
          thumbnailUrl: sopData['thumbnailUrl'],
        ));
      }

      _sops = loadedSOPs;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Successfully loaded ${loadedSOPs.length} SOPs from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading SOPs from Firestore: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      throw Exception('Failed to load SOPs: $e');
    }
  }

  SOP? getSopById(String id) {
    try {
      return _sops.firstWhere((sop) => sop.id == id);
    } catch (e) {
      return null;
    }
  }

  SOPTemplate? getTemplateById(String id) {
    try {
      return _templates.firstWhere((template) => template.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<SOP> createSop(
      String title, String description, String categoryId) async {
    final String sopId = const Uuid().v4();
    final DateTime now = DateTime.now();
    String? categoryName;

    if (kDebugMode) {
      print('Starting SOP creation process for "$title"');
    }

    // Get user info
    String userIdentifier = 'anonymous';
    if (_auth!.currentUser != null) {
      userIdentifier = _auth!.currentUser!.email ?? _auth!.currentUser!.uid;
      if (kDebugMode) {
        print('User creating SOP: $userIdentifier');
      }
    }

    // Get category name if categoryId is provided
    if (categoryId.isNotEmpty) {
      try {
        final categoryDoc =
            await _firestore!.collection('categories').doc(categoryId).get();
        if (categoryDoc.exists) {
          categoryName = categoryDoc.data()?['name'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fetch category name: $e');
        }
      }
    }

    try {
      if (kDebugMode) {
        print('_firestore instance exists: ${_firestore != null}');
      }

      // Create a QR code URL for the SOP
      final qrCodeUrl = _qrCodeService.generateQRDataForSOP(sopId);

      // Create the SOP document without any steps
      final sopData = {
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'revisionNumber': 1,
        'createdBy': userIdentifier,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'tools': [],
        'safetyRequirements': [],
        'cautions': [],
        'steps': [], // Empty steps array - no default step
        'qrCodeUrl': qrCodeUrl, // Add QR code URL
        'thumbnailUrl': null, // Initialize thumbnail URL as null
        'youtubeUrl': null, // Initialize YouTube URL as null
      };

      if (kDebugMode) {
        print('Creating SOP in Firestore with data: $sopData');
        print('Target Firestore path: sops/$sopId');
      }

      // Create the SOP with steps embedded in Firestore
      await _firestore!.collection('sops').doc(sopId).set(sopData).then((_) {
        if (kDebugMode) {
          print('✅ Successfully wrote SOP data to Firestore path: sops/$sopId');
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('❌ Failed to write to Firestore: $error');
        }
        throw error;
      });

      if (kDebugMode) {
        print('Created new SOP in Firestore with ID: $sopId');
        // Verify the document exists
        _firestore!.collection('sops').doc(sopId).get().then((doc) {
          if (doc.exists) {
            print('✅ Confirmed SOP document exists in Firestore');
          } else {
            print('❌ SOP document does not exist in Firestore after creation');
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating SOP in Firestore: $e');
      }
      throw Exception('Failed to create SOP: $e');
    }

    // Create and return the local SOP object with an empty steps list
    final sop = SOP(
      id: sopId,
      title: title,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      revisionNumber: 1,
      createdBy: userIdentifier,
      createdAt: now,
      updatedAt: now,
      steps: [], // Empty steps list - no default step
      tools: [],
      safetyRequirements: [],
      cautions: [],
      qrCodeUrl: _qrCodeService.generateQRDataForSOP(sopId), // Add QR code URL
      thumbnailUrl: null, // Initialize with no thumbnail
      youtubeUrl: null, // No YouTube video initially
    );

    // Add to the local list
    _sops.add(sop);
    notifyListeners();

    if (kDebugMode) {
      print('SOP created and added to local list. Total SOPs: ${_sops.length}');
    }

    // Explicitly reload SOPs from Firestore to ensure UI is updated with the latest data
    // Use a slight delay to allow Firestore to complete the write
    Future.delayed(const Duration(milliseconds: 500), () {
      if (kDebugMode) {
        print('Explicitly refreshing SOPs from Firestore after creation');
      }
      _loadSOPs();
    });

    return sop;
  }

  Future<SOP> createSopFromTemplate(
      String templateId, String title, String department) async {
    final template = getTemplateById(templateId);
    if (template == null) {
      throw Exception('Template not found');
    }

    return createSop(title, template.description, template.category);
  }

  // Method to update a SOP locally without saving to Firebase
  Future<void> updateSopLocally(SOP sop) async {
    // Store the updated SOP in the local changes map
    _localChanges[sop.id] = sop;

    // Update the local list for UI updates
    final index = _sops.indexWhere((s) => s.id == sop.id);
    if (index >= 0) {
      _sops[index] = sop.copyWith(updatedAt: DateTime.now());
      notifyListeners();
    }
  }

  // Modified updateSop method to save to Firebase
  Future<void> updateSop(SOP sop) async {
    final DateTime now = DateTime.now();

    // Ensure the SOP has a QR code URL
    String qrCodeUrl =
        sop.qrCodeUrl ?? _qrCodeService.generateQRDataForSOP(sop.id);
    final updatedSop = sop.copyWith(updatedAt: now, qrCodeUrl: qrCodeUrl);

    try {
      // Convert steps to a format suitable for Firestore
      List<Map<String, dynamic>> stepsData = updatedSop.steps
          .map((step) => {
                'id': step.id,
                'title': step.title,
                'instruction': step.instruction,
                'imageUrl': step.imageUrl,
                'helpNote': step.helpNote,
                'assignedTo': step.assignedTo,
                'estimatedTime': step.estimatedTime,
                'stepTools': step.stepTools,
                'stepHazards': step.stepHazards,
                'updatedAt': Timestamp.fromDate(now),
              })
          .toList();

      if (kDebugMode) {
        print('Saving SOP to Firestore with ${stepsData.length} steps');
        for (int i = 0; i < stepsData.length; i++) {
          print(
              'Step ${i + 1} - ID: ${stepsData[i]['id']}, imageUrl: ${stepsData[i]['imageUrl']}');
        }
      }

      // Update the SOP document with embedded steps
      final sopData = {
        'title': updatedSop.title,
        'description': updatedSop.description,
        'categoryId': updatedSop.categoryId,
        'categoryName': updatedSop.categoryName,
        'revisionNumber': updatedSop.revisionNumber,
        'updatedAt': Timestamp.fromDate(now),
        'tools': updatedSop.tools,
        'safetyRequirements': updatedSop.safetyRequirements,
        'cautions': updatedSop.cautions,
        'qrCodeUrl': qrCodeUrl, // Add QR code URL
        'thumbnailUrl': updatedSop.thumbnailUrl, // Add thumbnail URL
        'steps': stepsData, // Store steps directly in the document
      };

      await _firestore!.collection('sops').doc(updatedSop.id).update(sopData);

      if (kDebugMode) {
        print('Updated SOP in Firestore with ID: ${updatedSop.id}');
      }

      // Clear from local changes map since it's now saved to Firebase
      _localChanges.remove(updatedSop.id);

      // Update the local list
      final index = _sops.indexWhere((s) => s.id == updatedSop.id);
      if (index >= 0) {
        _sops[index] = updatedSop;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating SOP: $e');
      }
      throw Exception('Failed to update SOP: $e');
    }
  }

  Future<void> deleteSop(String id) async {
    try {
      // Delete the SOP document (steps are now embedded)
      await _firestore!.collection('sops').doc(id).delete();

      // Delete any associated images from storage
      final sop = getSopById(id);
      if (sop != null) {
        for (var step in sop.steps) {
          if (step.imageUrl != null &&
              (step.imageUrl!.startsWith('gs://') ||
                  step.imageUrl!.startsWith('https://firebasestorage'))) {
            try {
              final storageRef =
                  _storage!.ref().child('sop_images/$id/${step.id}.jpg');
              await storageRef.delete();
            } catch (e) {
              if (kDebugMode) {
                print('Error deleting image: $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('Deleted SOP with ID: $id from Firestore');
      }

      // Update the local list
      _sops.removeWhere((sop) => sop.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting SOP: $e');
      }
      throw Exception('Failed to delete SOP: $e');
    }
  }

  Future<String?> uploadImage(File file, String sopId, String stepId) async {
    try {
      final storageRef = _storage!.ref().child('sop_images/$sopId/$stepId.jpg');
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image to Firebase Storage: $e');
      }
      return null;
    }
  }

  Future<String> uploadImageFromDataUrl(
      String dataUrl, String sopId, String stepId) async {
    try {
      // Extract base64 data from the data URL
      if (dataUrl.contains('base64,')) {
        // Parse the data URL to extract the base64 string and content type
        final contentType = dataUrl.split(',')[0].split(':')[1].split(';')[0];
        final base64String = dataUrl.split(',')[1];
        final bytes = base64Decode(base64String);

        // Create a reference to the file location in Firebase Storage
        final storageRef =
            _storage!.ref().child('sop_images/$sopId/$stepId.jpg');

        // Upload the data
        final metadata = SettableMetadata(contentType: contentType);
        final uploadTask = storageRef.putData(bytes, metadata);
        final TaskSnapshot snapshot = await uploadTask;

        // Get the download URL from Firebase Storage
        final downloadUrl = await snapshot.ref.getDownloadURL();

        if (kDebugMode) {
          print(
              'Successfully uploaded image to Firebase Storage: $downloadUrl');
        }

        return downloadUrl;
      } else {
        // If it's not a base64 data URL, return as is
        return dataUrl;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image from data URL: $e');
      }
      return dataUrl; // Return the original data URL as fallback
    }
  }

  // Search SOPs by title, description, or department
  List<SOP> searchSOPs(String query) {
    query = query.toLowerCase();
    return _sops.where((sop) {
      return sop.title.toLowerCase().contains(query) ||
          sop.description.toLowerCase().contains(query) ||
          (sop.categoryName?.toLowerCase() ?? '').contains(query);
    }).toList();
  }

  List<SOPTemplate> searchTemplates(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _templates.where((template) {
      return template.title.toLowerCase().contains(lowercaseQuery) ||
          template.description.toLowerCase().contains(lowercaseQuery) ||
          template.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Public method to refresh SOPs
  Future<void> refreshSOPs() async {
    await _loadSOPs();
  }

  // Get QR code service
  QRCodeService get qrCodeService => _qrCodeService;

  // Create a SOP locally without saving to Firebase
  SOP createLocalSop(String title, String description, String categoryId) {
    final now = DateTime.now();
    final String sopId = const Uuid().v4();
    final String userIdentifier = _auth?.currentUser?.email ?? 'demo_user';
    final String userName = _auth?.currentUser?.displayName ?? 'Demo User';
    final String? categoryName = _findCategoryName(categoryId);
    final String qrCodeUrl = _qrCodeService.generateQRDataForSOP(sopId);

    // Create a new local SOP
    final sop = SOP(
      id: sopId,
      title: title,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName ?? '', // Handle null case
      revisionNumber: 1,
      createdBy: userName,
      createdAt: now,
      updatedAt: now,
      steps: [],
      tools: [],
      safetyRequirements: [],
      cautions: [],
      qrCodeUrl: qrCodeUrl, // QR code for the SOP access
      thumbnailUrl: null, // No thumbnail initially
      youtubeUrl: null, // No YouTube video initially
    );

    // Store in local changes
    _localChanges[sopId] = sop;

    return sop;
  }

  // Helper method to find a category name from its ID
  String? _findCategoryName(String categoryId) {
    // If the category ID is empty, return an empty string
    if (categoryId.isEmpty) {
      return '';
    }

    // For simplicity, just return empty string as we'll update this later
    // We would normally search through a category collection to find the name
    return '';
  }

  // Save a local SOP to Firebase
  Future<SOP> saveLocalSopToFirebase(SOP sop) async {
    try {
      // Get category name if needed
      String? categoryName = sop.categoryName;
      if (sop.categoryName?.isEmpty == true && sop.categoryId.isNotEmpty) {
        try {
          final categoryDoc = await _firestore!
              .collection('categories')
              .doc(sop.categoryId)
              .get();
          if (categoryDoc.exists) {
            categoryName = categoryDoc.data()?['name'];
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to fetch category name: $e');
          }
        }
      }

      // Process any steps with base64 image data URLs
      List<SOPStep> processedSteps = [];
      for (final step in sop.steps) {
        if (step.imageUrl != null && step.imageUrl!.startsWith('data:image/')) {
          try {
            // Upload the image to Firebase Storage
            final uploadedUrl = await uploadImageFromDataUrl(
              step.imageUrl!,
              sop.id,
              step.id,
            );
            // Create a new step with the uploaded URL
            processedSteps.add(step.copyWith(imageUrl: uploadedUrl));
          } catch (e) {
            // Keep original step if upload fails
            processedSteps.add(step);
            if (kDebugMode) {
              print('Failed to upload step image: $e');
            }
          }
        } else {
          // Keep original step if no image or already a storage URL
          processedSteps.add(step);
        }
      }

      // Update SOP with processed steps
      SOP processedSop = sop.copyWith(steps: processedSteps);

      // Convert steps to a format suitable for Firestore
      List<Map<String, dynamic>> stepsData = processedSop.steps
          .map((step) => {
                'id': step.id,
                'title': step.title,
                'instruction': step.instruction,
                'imageUrl': step.imageUrl,
                'helpNote': step.helpNote,
                'assignedTo': step.assignedTo,
                'estimatedTime': step.estimatedTime,
                'stepTools': step.stepTools,
                'stepHazards': step.stepHazards,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              })
          .toList();

      // Create the SOP document with embedded steps
      final sopData = {
        'title': processedSop.title,
        'description': processedSop.description,
        'categoryId': processedSop.categoryId,
        'categoryName': categoryName,
        'revisionNumber': processedSop.revisionNumber,
        'createdBy': processedSop.createdBy,
        'createdAt': Timestamp.fromDate(processedSop.createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'tools': processedSop.tools,
        'safetyRequirements': processedSop.safetyRequirements,
        'cautions': processedSop.cautions,
        'qrCodeUrl': processedSop.qrCodeUrl,
        'thumbnailUrl': processedSop.thumbnailUrl,
        'youtubeUrl': processedSop.youtubeUrl,
        'steps': stepsData,
      };

      // If this is a new document, let Firestore generate an ID
      DocumentReference docRef;
      if (processedSop.id.length < 20 ||
          !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(processedSop.id)) {
        docRef = await _firestore!.collection('sops').add(sopData);
        if (kDebugMode) {
          print('Created new SOP with Firebase-generated ID: ${docRef.id}');
        }
      } else {
        docRef = _firestore!.collection('sops').doc(processedSop.id);
        await docRef.set(sopData);
        if (kDebugMode) {
          print('Saved SOP with ID: ${processedSop.id}');
        }
      }

      // Update the SOP with the Firebase ID if we got a new one
      final String finalId = docRef.id;

      // Create the final SOP with updated ID and timestamp
      final updatedSop = processedSop.copyWith(
        id: finalId,
        categoryName: categoryName,
        updatedAt: DateTime.now(),
      );

      // Update the local list
      final index = _sops.indexWhere((s) => s.id == sop.id);
      if (index >= 0) {
        _sops[index] = updatedSop;
      } else {
        _sops.add(updatedSop);
      }

      // Remove from local changes map
      _localChanges.remove(sop.id);
      notifyListeners();

      return updatedSop;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving local SOP to Firebase: $e');
      }
      throw e;
    }
  }
}
