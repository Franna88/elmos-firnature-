import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sop_model.dart';

class SOPService extends ChangeNotifier {
  // Nullable Firebase services
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAuth? _auth;

  List<SOP> _sops = [];
  List<SOPTemplate> _templates = [];

  // Flag to track if we're using local data
  bool _usingLocalData = false;

  List<SOP> get sops => List.unmodifiable(_sops);
  List<SOPTemplate> get templates => List.unmodifiable(_templates);
  bool get usingLocalData => _usingLocalData;

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
        print('Using local SOP data instead');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      _usingLocalData = true;
      _loadSampleTemplates();
      _loadSampleSOPs();
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
    if (_usingLocalData) {
      _loadSampleTemplates();
      return;
    }

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
      // Load some sample templates if there's an error
      _loadSampleTemplates();
    }
  }

  void _loadSampleTemplates() {
    _templates = [
      SOPTemplate(
        id: '1',
        title: 'Furniture Assembly Template',
        description: 'Standard template for furniture assembly procedures',
        category: 'Assembly',
        thumbnailUrl:
            'https://media.istockphoto.com/id/1271691214/photo/successful-furniture-assembly-worker-reads-instructions-to-assemble-shelf.jpg?s=612x612&w=0&k=20&c=KBMOiPX2o2WeTN6jcdpDVbMlBwizXTM2Sps2Jex2eQ0=',
      ),
      SOPTemplate(
        id: '2',
        title: 'Wood Finishing Template',
        description: 'Standard procedures for wood finishing and treatment',
        category: 'Finishing',
        thumbnailUrl:
            'https://media.istockphoto.com/id/1303862719/photo/applying-varnish-to-a-wooden-surface-with-a-brush.jpg?s=612x612&w=0&k=20&c=F5VFRuPmX_yreFirNlBBX98lPg_l2CqCDnG6I2WyFSY=',
      ),
      SOPTemplate(
        id: '3',
        title: 'Quality Control Template',
        description: 'Quality control procedures for furniture inspection',
        category: 'Quality',
        thumbnailUrl:
            'https://media.istockphoto.com/id/655986486/photo/man-using-a-digital-level-while-installing-furniture.jpg?s=612x612&w=0&k=20&c=Ih_mSCZaM7Q0JnLniCdaFMJE38XWQNc15GmiXaZVkM0=',
      ),
      SOPTemplate(
        id: '4',
        title: 'Upholstery Template',
        description: 'Standard procedures for furniture upholstery',
        category: 'Upholstery',
        thumbnailUrl:
            'https://media.istockphoto.com/id/1440598592/photo/close-up-hands-of-professional-upholsterer-stapling-fabric-to-a-furniture-upholstery-of-a.jpg?s=612x612&w=0&k=20&c=N1T8eAe1vP38ek4DxSXBt5rJ6p0ZfOiX62QkTIyUn10=',
      ),
      SOPTemplate(
        id: '5',
        title: 'Machine Operation Template',
        description: 'Safety procedures for woodworking machinery operation',
        category: 'Machinery',
        thumbnailUrl:
            'https://media.istockphoto.com/id/1132841403/photo/a-cnc-wood-router-cutting-out-a-pattern-for-furniture.jpg?s=612x612&w=0&k=20&c=Bh-G3D0Fdo5RZtZdvnJxm-J1-qdmKI7hGU_WcGx29so=',
      ),
    ];
    notifyListeners();
  }

  void _listenForSOPChanges() {
    if (_usingLocalData || _firestore == null) return;

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
    if (_usingLocalData) {
      if (kDebugMode) {
        print('Using local data: Loading sample SOPs');
      }
      _loadSampleSOPs();
      return;
    }

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
        print('Using sample SOPs instead');
      }
      _loadSampleSOPs();
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
    final now = DateTime.now();
    final sopId = const Uuid().v4();

    if (kDebugMode) {
      print('Starting SOP creation process for "$title"');
      print(
          'Firebase connection status: ${!_usingLocalData ? "Connected" : "Not connected (local mode)"}');
    }

    // Get user info
    String userIdentifier = 'anonymous';
    if (!_usingLocalData && _auth!.currentUser != null) {
      userIdentifier = _auth!.currentUser!.email ?? _auth!.currentUser!.uid;
      if (kDebugMode) {
        print('User creating SOP: $userIdentifier');
      }
    }

    // Get category name if categoryId is provided
    String? categoryName;
    if (categoryId.isNotEmpty && !_usingLocalData) {
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

    // Default image URL for steps
    final defaultImageUrl = null;

    // Create a default first step
    final defaultFirstStep = SOPStep(
      id: "${sopId}_1",
      title: "",
      instruction: "",
      imageUrl: defaultImageUrl,
      stepTools: [],
      stepHazards: [],
    );

    if (!_usingLocalData) {
      try {
        if (kDebugMode) {
          print('_firestore instance exists: ${_firestore != null}');
        }

        // Create the SOP document with embedded steps
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
          'steps': [
            {
              'id': defaultFirstStep.id,
              'title': defaultFirstStep.title,
              'instruction': defaultFirstStep.instruction,
              'imageUrl': defaultFirstStep.imageUrl,
              'helpNote': defaultFirstStep.helpNote,
              'assignedTo': defaultFirstStep.assignedTo,
              'estimatedTime': defaultFirstStep.estimatedTime,
              'stepTools': defaultFirstStep.stepTools,
              'stepHazards': defaultFirstStep.stepHazards,
              'createdAt': Timestamp.fromDate(now),
            }
          ]
        };

        if (kDebugMode) {
          print('Creating SOP in Firestore with data: $sopData');
          print('Target Firestore path: sops/$sopId');
        }

        // Create the SOP with steps embedded in Firestore
        await _firestore!.collection('sops').doc(sopId).set(sopData).then((_) {
          if (kDebugMode) {
            print(
                '✅ Successfully wrote SOP data to Firestore path: sops/$sopId');
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
              print(
                  '❌ SOP document does not exist in Firestore after creation');
            }
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error creating SOP in Firestore: $e');
          print('Using local SOP data instead');
        }
        _usingLocalData = true;
      }
    }

    // Create and return the local SOP object
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
      steps: [defaultFirstStep],
      tools: [],
      safetyRequirements: [],
      cautions: [],
    );

    // Add to the local list
    _sops.add(sop);
    notifyListeners();

    if (kDebugMode) {
      print('SOP created and added to local list. Total SOPs: ${_sops.length}');
    }

    // Explicitly reload SOPs from Firestore to ensure UI is updated with the latest data
    if (!_usingLocalData) {
      // Use a slight delay to allow Firestore to complete the write
      Future.delayed(const Duration(milliseconds: 500), () {
        if (kDebugMode) {
          print('Explicitly refreshing SOPs from Firestore after creation');
        }
        _loadSOPs();
      });
    }

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

  Future<void> updateSop(SOP sop) async {
    try {
      if (!_usingLocalData) {
        // Convert steps to a format suitable for Firestore
        List<Map<String, dynamic>> stepsData = sop.steps
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

        // Update the SOP document with embedded steps
        final sopData = {
          'title': sop.title,
          'description': sop.description,
          'categoryId': sop.categoryId,
          'categoryName': sop.categoryName,
          'revisionNumber': sop.revisionNumber,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'tools': sop.tools,
          'safetyRequirements': sop.safetyRequirements,
          'cautions': sop.cautions,
          'steps': stepsData, // Store steps directly in the document
        };

        await _firestore!.collection('sops').doc(sop.id).update(sopData);

        if (kDebugMode) {
          print('Updated SOP in Firestore with ID: ${sop.id}');
        }
      }

      // Update the local list
      final index = _sops.indexWhere((s) => s.id == sop.id);
      if (index >= 0) {
        _sops[index] = sop.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating SOP: $e');
      }

      // If using Firestore failed, switch to local data
      if (!_usingLocalData) {
        _usingLocalData = true;

        // Update local list
        final index = _sops.indexWhere((s) => s.id == sop.id);
        if (index >= 0) {
          _sops[index] = sop.copyWith(updatedAt: DateTime.now());
          notifyListeners();
        }
      } else {
        throw Exception('Failed to update SOP: $e');
      }
    }
  }

  Future<void> deleteSop(String id) async {
    try {
      if (!_usingLocalData) {
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
      }

      // Update the local list
      _sops.removeWhere((sop) => sop.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting SOP: $e');
      }

      if (!_usingLocalData) {
        _usingLocalData = true;
        // Update the local list
        _sops.removeWhere((sop) => sop.id == id);
        notifyListeners();
      } else {
        throw Exception('Failed to delete SOP: $e');
      }
    }
  }

  Future<String?> uploadImage(File file, String sopId, String stepId) async {
    if (_usingLocalData) {
      // For local data mode, we'll just return a placeholder
      return 'assets/images/placeholder.png';
    }

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
    if (_usingLocalData) {
      // In local mode, just return the data URL
      return dataUrl;
    }

    try {
      // On Firebase, we'd convert the data URL to a file and upload
      // For now in web mode, we'll just return the data URL
      return dataUrl;
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

  // Sample SOPs for local development and testing
  void _loadSampleSOPs() {
    final now = DateTime.now();
    _sops = [
      SOP(
        id: '1',
        title: 'Dining Table Assembly',
        description:
            'Procedure for assembling wooden dining tables with four legs',
        categoryId: 'Assembly',
        categoryName: 'Assembly',
        revisionNumber: 2,
        createdBy: 'assembly@elmosfurniture.com',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(days: 5)),
        steps: [
          SOPStep(
            id: '1_1',
            title: 'Prepare Components',
            instruction:
                'Gather all table components and verify completeness against the bill of materials.',
            helpNote: 'Ensure all parts are free from damage and defects.',
            stepTools: ['Inspection checklist', 'Measuring tape'],
            stepHazards: ['Splinters from rough edges'],
            imageUrl:
                'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000',
          ),
          SOPStep(
            id: '1_2',
            title: 'Attach Table Legs',
            instruction:
                'Align table legs with designated mounting points and secure with bolts.',
            assignedTo: 'Assembly Team',
            estimatedTime: 20,
            stepTools: ['Electric screwdriver', '5mm hex key', 'Rubber mallet'],
            stepHazards: ['Pinch points when aligning legs', 'Heavy lifting'],
            imageUrl:
                'https://media.istockphoto.com/id/1271691214/photo/successful-furniture-assembly-worker-reads-instructions-to-assemble-shelf.jpg?s=612x612&w=0&k=20&c=KBMOiPX2o2WeTN6jcdpDVbMlBwizXTM2Sps2Jex2eQ0=',
          ),
          SOPStep(
            id: '1_3',
            title: 'Secure Cross-Supports',
            instruction:
                'Attach cross-support beams between legs using the provided hardware.',
            assignedTo: 'Assembly Team',
            estimatedTime: 15,
            stepTools: ['Electric screwdriver', 'Level', 'Tape measure'],
            stepHazards: ['Unstable structure during assembly'],
            imageUrl:
                'https://media.istockphoto.com/id/825530266/photo/assembling-of-furniture-closeup-hex-wrench-in-hand-furniture-screw-screwed-into-board-of-bench.jpg?s=612x612&w=0&k=20&c=tUMEuNdtJ7N0sNwIkJ0J5kMkzG0OjLB7MZlqKl-0Uo8=',
          ),
          SOPStep(
            id: '1_4',
            title: 'Final Inspection',
            instruction:
                'Check stability, level, and quality of finished assembly.',
            helpNote:
                'Table should not wobble and all connections should be tight.',
            assignedTo: 'Quality Control',
            estimatedTime: 10,
            stepTools: ['Level', 'Inspection checklist'],
            stepHazards: [],
            imageUrl:
                'https://media.istockphoto.com/id/655986486/photo/man-using-a-digital-level-while-installing-furniture.jpg?s=612x612&w=0&k=20&c=Ih_mSCZaM7Q0JnLniCdaFMJE38XWQNc15GmiXaZVkM0=',
          ),
        ],
        tools: [
          'Electric screwdriver',
          '5mm hex key',
          'Rubber mallet',
          'Level',
          'Measuring tape'
        ],
        safetyRequirements: [
          'Wear safety gloves',
          'Use proper lifting technique'
        ],
        cautions: [
          'Do not overtighten fasteners',
          'Ensure level surface for assembly'
        ],
      ),
      SOP(
        id: '2',
        title: 'Oak Finishing Process',
        description: 'Standard procedure for applying finish to oak furniture',
        categoryId: 'Finishing',
        categoryName: 'Finishing',
        revisionNumber: 3,
        createdBy: 'finishing@elmosfurniture.com',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 10)),
        steps: [
          SOPStep(
            id: '2_1',
            title: 'Surface Preparation',
            instruction:
                'Sand all surfaces with 120-grit sandpaper, then 220-grit for final smoothing.',
            helpNote:
                'Ensure all surfaces are sanded with the grain to avoid scratches.',
            assignedTo: 'Finishing Department',
            estimatedTime: 30,
            stepTools: [
              'Orbital sander',
              'Sanding blocks',
              'Tack cloth',
              'Dust mask'
            ],
            stepHazards: ['Wood dust inhalation', 'Skin irritation from dust'],
            imageUrl:
                'https://media.istockphoto.com/id/1200265110/photo/carpenter-working-with-sander-on-wooden-surface-in-carpentry-workshop.jpg?s=612x612&w=0&k=20&c=XxULNxf7adQlV3wMbIvANJ6a3Vp0KdnvqBWRcvP-IlQ=',
          ),
        ],
        tools: [
          'Orbital sander',
          'Sanding blocks',
          'Brushes',
          'Clean cloths',
          'Respirator',
          'Gloves'
        ],
        safetyRequirements: [
          'Wear respirator',
          'Ensure proper ventilation',
          'Wear nitrile gloves',
          'No open flames in work area'
        ],
        cautions: [
          'Dispose of rags properly to prevent spontaneous combustion',
          'Keep all chemicals away from heat sources'
        ],
      ),
    ];
    notifyListeners();
  }
}
