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
      
      // Test if Firestore is working
      await _firestore!.collection('test').limit(1).get();
      
      if (kDebugMode) {
        print('Using Firebase Firestore for SOP data');
      }
      
      await _loadTemplates();
      await _loadSOPs();
      
      // Listen for SOP changes
      _listenForSOPChanges();
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization error in SOPService: $e');
        print('Using local SOP data instead');
      }
      _usingLocalData = true;
      _loadSampleTemplates();
      _loadSampleSOPs();
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
        title: 'Equipment Maintenance',
        description: 'Standard template for equipment maintenance procedures',
        category: 'Maintenance',
        thumbnailUrl: 'assets/images/maintenance.png',
      ),
      SOPTemplate(
        id: '2',
        title: 'Safety Protocol',
        description: 'Standard safety protocols for workplace operations',
        category: 'Safety',
        thumbnailUrl: 'assets/images/safety.png',
      ),
      SOPTemplate(
        id: '3',
        title: 'Quality Assurance',
        description: 'Quality assurance procedures for product inspection',
        category: 'Quality',
        thumbnailUrl: 'assets/images/quality.png',
      ),
    ];
    notifyListeners();
  }
  
  void _loadSampleSOPs() {
    final now = DateTime.now();
    _sops = [
      SOP(
        id: '1',
        title: 'Monthly Equipment Check',
        description: 'Procedure for checking and maintaining kitchen equipment',
        department: 'Kitchen',
        revisionNumber: 1,
        createdBy: 'admin@example.com',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 5)),
        steps: [
          SOPStep(
            id: '1_1',
            title: 'Inspect Equipment',
            instruction: 'Check all kitchen equipment for signs of wear or damage.',
            helpNote: 'Look for frayed cords, loose parts, or unusual sounds.',
          ),
          SOPStep(
            id: '1_2',
            title: 'Clean Equipment',
            instruction: 'Clean all equipment according to manufacturer specifications.',
            assignedTo: 'Kitchen Staff',
            estimatedTime: 45,
          ),
        ],
        tools: ['Cleaning supplies', 'Inspection checklist', 'Maintenance tools'],
        safetyRequirements: ['Wear gloves', 'Unplug equipment before cleaning'],
        cautions: ['Do not use abrasive cleaners on stainless steel'],
      ),
      SOP(
        id: '2',
        title: 'Opening Procedures',
        description: 'Steps for opening the restaurant each day',
        department: 'Front of House',
        revisionNumber: 2,
        createdBy: 'admin@example.com',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 15)),
        steps: [
          SOPStep(
            id: '2_1',
            title: 'Unlock Doors',
            instruction: 'Unlock all entrances and exits.',
            assignedTo: 'Manager',
            estimatedTime: 5,
          ),
          SOPStep(
            id: '2_2',
            title: 'Turn On Equipment',
            instruction: 'Turn on all necessary equipment in the proper order.',
            helpNote: 'Start with ventilation systems, then cooking equipment.',
            assignedTo: 'Kitchen Manager',
            estimatedTime: 15,
          ),
        ],
        tools: ['Keys', 'Opening checklist'],
        safetyRequirements: ['Check fire extinguishers', 'Ensure exits are clear'],
        cautions: ['Do not rush through safety checks'],
      ),
    ];
    notifyListeners();
  }
  
  void _listenForSOPChanges() {
    if (_usingLocalData) return;
    
    final userId = _auth?.currentUser?.uid;
    if (userId == null) return;
    
    _firestore!
        .collection('sops')
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _loadSOPs();
    });
  }
  
  Future<void> _loadSOPs() async {
    if (_usingLocalData) {
      _loadSampleSOPs();
      return;
    }
    
    try {
      final userId = _auth?.currentUser?.uid;
      if (userId == null) {
        _sops = [];
        notifyListeners();
        return;
      }
      
      final snapshot = await _firestore!
          .collection('sops')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      final List<SOP> loadedSOPs = [];
      
      for (var doc in snapshot.docs) {
        final sopData = doc.data();
        final stepsData = sopData['steps'] as List<dynamic>? ?? [];
        
        final List<SOPStep> steps = stepsData.map<SOPStep>((stepData) {
          return SOPStep(
            id: stepData['id'] ?? '',
            title: stepData['title'] ?? '',
            instruction: stepData['instruction'] ?? '',
            imageUrl: stepData['imageUrl'],
            helpNote: stepData['helpNote'],
            assignedTo: stepData['assignedTo'],
            estimatedTime: stepData['estimatedTime'],
          );
        }).toList();
        
        loadedSOPs.add(SOP(
          id: doc.id,
          title: sopData['title'] ?? '',
          description: sopData['description'] ?? '',
          department: sopData['department'] ?? '',
          revisionNumber: sopData['revisionNumber'] ?? 1,
          createdBy: sopData['createdBy'] ?? '',
          createdAt: (sopData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (sopData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          steps: steps,
          tools: List<String>.from(sopData['tools'] ?? []),
          safetyRequirements: List<String>.from(sopData['safetyRequirements'] ?? []),
          cautions: List<String>.from(sopData['cautions'] ?? []),
        ));
      }
      
      _sops = loadedSOPs;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading SOPs: $e');
        _loadSampleSOPs();
      }
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
  
  Future<SOP> createSop(String title, String description, String department) async {
    final String sopId = const Uuid().v4();
    final now = DateTime.now();
    
    final userId = _auth?.currentUser?.uid ?? 'local_user';
    
    if (!_usingLocalData) {
      try {
        final sopData = {
          'title': title,
          'description': description,
          'department': department,
          'revisionNumber': 1,
          'createdBy': userId,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'steps': [],
          'tools': [],
          'safetyRequirements': [],
          'cautions': [],
        };
        
        // Create the SOP in Firestore
        await _firestore!.collection('sops').doc(sopId).set(sopData);
      } catch (e) {
        if (kDebugMode) {
          print('Error creating SOP in Firestore: $e');
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
      department: department,
      revisionNumber: 1,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      steps: [],
      tools: [],
      safetyRequirements: [],
      cautions: [],
    );
    
    _sops.add(sop);
    notifyListeners();
    return sop;
  }
  
  Future<SOP> createSopFromTemplate(String templateId, String title, String department) async {
    final template = getTemplateById(templateId);
    if (template == null) {
      throw Exception('Template not found');
    }
    
    return createSop(title, template.description, department);
  }
  
  Future<void> updateSop(SOP sop) async {
    try {
      if (!_usingLocalData) {
        final sopData = {
          'title': sop.title,
          'description': sop.description,
          'department': sop.department,
          'revisionNumber': sop.revisionNumber,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'steps': sop.steps.map((step) => {
            'id': step.id,
            'title': step.title,
            'instruction': step.instruction,
            'imageUrl': step.imageUrl,
            'helpNote': step.helpNote,
            'assignedTo': step.assignedTo,
            'estimatedTime': step.estimatedTime,
          }).toList(),
          'tools': sop.tools,
          'safetyRequirements': sop.safetyRequirements,
          'cautions': sop.cautions,
        };
        
        await _firestore!.collection('sops').doc(sop.id).update(sopData);
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
        await _firestore!.collection('sops').doc(id).delete();
        
        // Delete any associated images from storage
        final sop = getSopById(id);
        if (sop != null) {
          for (var step in sop.steps) {
            if (step.imageUrl != null && step.imageUrl!.startsWith('gs://')) {
              try {
                await _storage!.refFromURL(step.imageUrl!).delete();
              } catch (e) {
                if (kDebugMode) {
                  print('Error deleting image: $e');
                }
              }
            }
          }
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
  
  Future<String> uploadImage(File file, String sopId, String stepId) async {
    if (_usingLocalData) {
      // Just return a placeholder URL for local mode
      return 'assets/images/placeholder.png';
    }
    
    try {
      final ref = _storage!.ref().child('sops/$sopId/steps/$stepId/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      _usingLocalData = true;
      return 'assets/images/placeholder.png';
    }
  }
  
  List<SOP> searchSOPs(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _sops.where((sop) {
      return sop.title.toLowerCase().contains(lowercaseQuery) ||
          sop.description.toLowerCase().contains(lowercaseQuery) ||
          sop.department.toLowerCase().contains(lowercaseQuery);
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
} 