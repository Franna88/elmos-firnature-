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

  void _loadSampleSOPs() {
    final now = DateTime.now();
    _sops = [
      SOP(
        id: '1',
        title: 'Dining Table Assembly',
        description:
            'Procedure for assembling wooden dining tables with four legs',
        department: 'Assembly',
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
        department: 'Finishing',
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
          SOPStep(
            id: '2_2',
            title: 'Apply Wood Conditioner',
            instruction:
                'Apply pre-stain wood conditioner evenly with a clean cloth.',
            helpNote:
                'Allow to penetrate for 15 minutes, then wipe off excess with clean cloth.',
            assignedTo: 'Finishing Department',
            estimatedTime: 25,
            stepTools: [
              'Clean lint-free cloths',
              'Gloves',
              'Pre-stain conditioner'
            ],
            stepHazards: ['Chemical exposure', 'Eye irritation'],
            imageUrl:
                'https://media.istockphoto.com/id/960995348/photo/carpenter-rubbing-wood-with-wax-close-up.jpg?s=612x612&w=0&k=20&c=HrwzZ9fZJ9Wr8xLGYPR4KxRxA0zzG5LwiBo6I4oGEUs=',
          ),
          SOPStep(
            id: '2_3',
            title: 'Apply Stain',
            instruction:
                'Apply stain evenly using a brush or cloth, following the wood grain.',
            helpNote:
                'Let stain sit for 5-10 minutes before wiping excess with clean cloth.',
            assignedTo: 'Finishing Department',
            estimatedTime: 40,
            stepTools: ['Stain brushes', 'Clean cloths', 'Stain', 'Gloves'],
            stepHazards: ['Chemical exposure', 'Flammable materials'],
            imageUrl:
                'https://media.istockphoto.com/id/178401484/photo/worker-painting-furniture-detail.jpg?s=612x612&w=0&k=20&c=Vc9ZLs--r6b1eLvgO7JjEnTbJQTCuANdzJubLJvO9gY=',
          ),
          SOPStep(
            id: '2_4',
            title: 'Apply Topcoat',
            instruction:
                'Apply polyurethane topcoat with a high-quality brush.',
            helpNote:
                'Apply thin, even coats. Allow 24 hours drying time between coats.',
            assignedTo: 'Finishing Department',
            estimatedTime: 35,
            stepTools: [
              'Fine brushes',
              'Polyurethane',
              'Ventilation equipment'
            ],
            stepHazards: ['Chemical fumes', 'Fire hazard'],
            imageUrl:
                'https://media.istockphoto.com/id/1303862719/photo/applying-varnish-to-a-wooden-surface-with-a-brush.jpg?s=612x612&w=0&k=20&c=F5VFRuPmX_yreFirNlBBX98lPg_l2CqCDnG6I2WyFSY=',
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
      SOP(
        id: '3',
        title: 'Upholstered Chair Production',
        description: 'Complete process for upholstering dining chairs',
        department: 'Upholstery',
        revisionNumber: 1,
        createdBy: 'admin@elmosfurniture.com',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
        steps: [
          SOPStep(
            id: '3_1',
            title: 'Frame Preparation',
            instruction:
                'Inspect wooden frame for defects and sand any rough areas.',
            helpNote:
                'Check for loose joints and repair if necessary before proceeding.',
            assignedTo: 'Upholstery Prep',
            estimatedTime: 15,
            stepTools: ['Fine sandpaper', 'Wood glue', 'Clamps'],
            stepHazards: ['Wood dust', 'Pinch points from clamps'],
            imageUrl:
                'https://media.istockphoto.com/id/1411280311/photo/craftsman-is-assembling-furniture-chair-in-his-workshop.jpg?s=612x612&w=0&k=20&c=Jxn3Kx8LlO_b8ZILd6Ni9h7z_tpCjXFPYHOmxCOZxF8=',
          ),
          SOPStep(
            id: '3_2',
            title: 'Apply Webbing',
            instruction:
                'Stretch and attach jute webbing to seat frame, creating a support grid.',
            helpNote:
                'Ensure webbing is tight and secure with at least 5 staples per attachment point.',
            assignedTo: 'Upholstery Team',
            estimatedTime: 20,
            stepTools: [
              'Webbing stretcher',
              'Heavy-duty stapler',
              'Jute webbing'
            ],
            stepHazards: ['Stapler injury', 'Strain from stretching'],
            imageUrl:
                'https://media.istockphoto.com/id/1420539579/photo/upholsterer-is-pulling-elastic-webbing-bands-through-the-wooden-seat-frame.jpg?s=612x612&w=0&k=20&c=Oi4rmIZ_6xtW8LkMrTjWTLCrN-7gVuMn_fJMu3UMj0U=',
          ),
          SOPStep(
            id: '3_3',
            title: 'Install Foam and Batting',
            instruction:
                'Cut foam to size and attach to frame, then cover with polyester batting.',
            helpNote:
                'Foam should extend slightly beyond frame edges for comfortable seating.',
            assignedTo: 'Upholstery Team',
            estimatedTime: 25,
            stepTools: [
              'Electric knife',
              'Spray adhesive',
              'Measuring tape',
              'Batting'
            ],
            stepHazards: ['Cutting hazard', 'Chemical exposure from adhesives'],
            imageUrl:
                'https://media.istockphoto.com/id/1208764897/photo/upholstery-artisan-adjusts-the-yellow-foam-rubber-on-the-armchair.jpg?s=612x612&w=0&k=20&c=brbJqojaC0G9H9PICPfH0rQQiyPiKa3lsKg-E0qFGf4=',
          ),
          SOPStep(
            id: '3_4',
            title: 'Apply Fabric Cover',
            instruction:
                'Position fabric over chair and staple to underside of frame, working from center outward.',
            helpNote:
                'Keep fabric taut but not stretched to prevent distortion of patterns.',
            assignedTo: 'Upholstery Team',
            estimatedTime: 45,
            stepTools: [
              'Pneumatic stapler',
              'Fabric scissors',
              'Pliers',
              'Upholstery tack strips'
            ],
            stepHazards: ['Stapler injury', 'Sharp tools'],
            imageUrl:
                'https://media.istockphoto.com/id/1440598592/photo/close-up-hands-of-professional-upholsterer-stapling-fabric-to-a-furniture-upholstery-of-a.jpg?s=612x612&w=0&k=20&c=N1T8eAe1vP38ek4DxSXBt5rJ6p0ZfOiX62QkTIyUn10=',
          ),
          SOPStep(
            id: '3_5',
            title: 'Final Trim and Inspection',
            instruction:
                'Trim excess fabric and apply decorative elements like piping or buttons if specified.',
            helpNote:
                'Check for loose threads, uneven stapling, or fabric defects.',
            assignedTo: 'Quality Control',
            estimatedTime: 20,
            stepTools: [
              'Fabric scissors',
              'Thread trimmers',
              'Inspection mirror'
            ],
            stepHazards: ['Sharp tools'],
            imageUrl:
                'https://media.istockphoto.com/id/1413018543/photo/female-upholsterer-working-at-her-studio.jpg?s=612x612&w=0&k=20&c=v0n7-0pL7RUyH--VaX42hWVJMUuRvDh0lEfQ7IRz1Q8=',
          ),
        ],
        tools: [
          'Pneumatic stapler',
          'Webbing stretcher',
          'Electric knife',
          'Fabric scissors',
          'Spray adhesive',
          'Measuring tape'
        ],
        safetyRequirements: [
          'Wear safety glasses when using stapler',
          'Use ventilation when applying adhesives',
          'Keep cutting tools sheathed when not in use'
        ],
        cautions: [
          'Test fabric for colorfastness before applying',
          'Check pattern alignment before stapling'
        ],
      ),
      SOP(
        id: '4',
        title: 'CNC Router Operation',
        description: 'Safe operation procedure for CNC wood cutting machine',
        department: 'Machinery',
        revisionNumber: 5,
        createdBy: 'cnc@elmosfurniture.com',
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now.subtract(const Duration(days: 15)),
        steps: [
          SOPStep(
            id: '4_1',
            title: 'Machine Inspection',
            instruction:
                'Conduct pre-operation inspection of CNC router components and safety features.',
            helpNote:
                'Verify emergency stop button, dust collection system, and guards are all functional.',
            assignedTo: 'CNC Operator',
            estimatedTime: 10,
            stepTools: ['Inspection checklist', 'Flashlight'],
            stepHazards: ['Electrical hazards', 'Moving parts'],
            imageUrl:
                'https://media.istockphoto.com/id/1461036269/photo/checking-the-cnc-machine-before-starting-the-production-of-molds-and-dies.jpg?s=612x612&w=0&k=20&c=kJ6TjC6lNuS9LiJrfqjvvxbMt2uBP_J3qfR4sNpRMuE=',
          ),
          SOPStep(
            id: '4_2',
            title: 'Material Loading',
            instruction:
                'Secure wooden workpiece to CNC bed using appropriate clamping methods.',
            helpNote:
                'Ensure material is flat against the bed and properly aligned with machine coordinates.',
            assignedTo: 'CNC Operator',
            estimatedTime: 15,
            stepTools: ['T-clamps', 'Alignment squares', 'Measuring tape'],
            stepHazards: ['Pinch points', 'Heavy materials'],
            imageUrl:
                'https://media.istockphoto.com/id/538018043/photo/wooden-manufacturing-worker-using-industrial-tools.jpg?s=612x612&w=0&k=20&c=D64UHxPUBFFIqgfT_7UKlcXaRN8QPpMTGTVXvA1OP-s=',
          ),
          SOPStep(
            id: '4_3',
            title: 'Program Setup',
            instruction:
                'Load cutting program and verify tool paths through simulation.',
            helpNote:
                'Check that correct tools are loaded in the tool changer and tool offsets are set.',
            assignedTo: 'CNC Operator',
            estimatedTime: 10,
            stepTools: ['CNC software', 'Tool verification gauge'],
            stepHazards: ['Software errors could lead to machine crashes'],
            imageUrl:
                'https://media.istockphoto.com/id/1214577526/photo/checking-details-on-a-digital-screen.jpg?s=612x612&w=0&k=20&c=pMtcdBVTkftv9m0i7T6WzAIPgKXWx21a3tCOo0QGIh0=',
          ),
          SOPStep(
            id: '4_4',
            title: 'Operation',
            instruction:
                'Start cutting cycle and monitor operation throughout the process.',
            helpNote:
                'Maintain safe distance during operation and be ready to press emergency stop if needed.',
            assignedTo: 'CNC Operator',
            estimatedTime: 45,
            stepTools: ['Hearing protection', 'Safety glasses', 'Dust mask'],
            stepHazards: ['Flying debris', 'Loud noise', 'Dust exposure'],
            imageUrl:
                'https://media.istockphoto.com/id/1132841403/photo/a-cnc-wood-router-cutting-out-a-pattern-for-furniture.jpg?s=612x612&w=0&k=20&c=Bh-G3D0Fdo5RZtZdvnJxm-J1-qdmKI7hGU_WcGx29so=',
          ),
          SOPStep(
            id: '4_5',
            title: 'Unloading and Cleanup',
            instruction:
                'After completion, remove finished parts and clean machine area.',
            helpNote:
                'Inspect cut pieces for quality issues before removing from the machine.',
            assignedTo: 'CNC Operator',
            estimatedTime: 10,
            stepTools: ['Air hose', 'Vacuum', 'Deburring tool'],
            stepHazards: ['Sharp edges on cut material', 'Residual dust'],
            imageUrl:
                'https://media.istockphoto.com/id/1189749481/photo/man-cleaning-and-blowing-debris-and-dust-from-cnc-cutter.jpg?s=612x612&w=0&k=20&c=Ix2JZVzbx-ky5Uy0nUUubVKw2DTEf9_lZJpyGx-KdKI=',
          ),
        ],
        tools: [
          'CNC router',
          'Clamping system',
          'CAD/CAM software',
          'Measuring tools',
          'Hearing protection',
          'Safety glasses',
          'Dust mask'
        ],
        safetyRequirements: [
          'Complete CNC training certification',
          'Wear appropriate PPE',
          'Never leave running machine unattended',
          'Know location of emergency stops'
        ],
        cautions: [
          'Verify tool paths before running full program',
          'Keep hands away from cutting area',
          'Follow lockout/tagout procedures for maintenance'
        ],
      ),
      SOP(
        id: '5',
        title: 'Drawer Slide Installation',
        description:
            'Process for installing precision drawer slides in furniture',
        department: 'Assembly',
        revisionNumber: 2,
        createdBy: 'assembly@elmosfurniture.com',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 20)),
        steps: [
          SOPStep(
            id: '5_1',
            title: 'Measure and Mark',
            instruction:
                'Measure and mark positions for drawer slides on both cabinet and drawer sides.',
            helpNote:
                'Double-check measurements to ensure drawers will be level and aligned.',
            assignedTo: 'Assembly Team',
            estimatedTime: 10,
            stepTools: ['Measuring tape', 'Carpenter\'s square', 'Pencil'],
            stepHazards: [],
            imageUrl:
                'https://media.istockphoto.com/id/584705692/photo/carpenter-at-work.jpg?s=612x612&w=0&k=20&c=q0hy4YWDlol4SdGG-S7y_BfGAWxmkOcm_hRIgBW84rE=',
          ),
          SOPStep(
            id: '5_2',
            title: 'Mount Cabinet Slides',
            instruction:
                'Attach slide hardware to cabinet interior using appropriate screws.',
            helpNote:
                'Pre-drill holes to prevent splitting wood. Ensure slides are level and parallel.',
            assignedTo: 'Assembly Team',
            estimatedTime: 15,
            stepTools: ['Cordless drill', 'Drill bits', 'Level', 'Screwdriver'],
            stepHazards: ['Drill injuries', 'Wood splinters'],
            imageUrl:
                'https://media.istockphoto.com/id/1397745117/photo/artisan-working-on-a-drawer.jpg?s=612x612&w=0&k=20&c=J0-ypHWrtm9q3DGdh4M9VUBx1bvxZXTGwxH3-H6_vTQ=',
          ),
          SOPStep(
            id: '5_3',
            title: 'Mount Drawer Slides',
            instruction: 'Attach corresponding slide hardware to drawer sides.',
            helpNote:
                'Ensure alignment with cabinet slides for smooth operation.',
            assignedTo: 'Assembly Team',
            estimatedTime: 15,
            stepTools: ['Cordless drill', 'Drill bits', 'Screwdriver'],
            stepHazards: ['Drill injuries'],
            imageUrl:
                'https://media.istockphoto.com/id/1391236532/photo/carpenter-installing-drawer-slides-in-custom-cabinets.jpg?s=612x612&w=0&k=20&c=DnJGbPp4yEZx52DF0Qn1ePJEUU6MFu0QEUNfqVp2QTw=',
          ),
          SOPStep(
            id: '5_4',
            title: 'Test Operation',
            instruction:
                'Insert drawer into cabinet and test smooth operation.',
            helpNote:
                'Drawer should glide easily and close completely without binding.',
            assignedTo: 'Quality Control',
            estimatedTime: 5,
            stepTools: ['Adjustment tool for slides'],
            stepHazards: ['Pinch points between drawer and cabinet'],
            imageUrl:
                'https://media.istockphoto.com/id/1355063876/photo/man-opening-kitchen-cupboard-drawer.jpg?s=612x612&w=0&k=20&c=H9ExaGJzIEuHr2cMuR_ugtI1RYKSXLYmpJPR_I7D-pM=',
          ),
        ],
        tools: [
          'Measuring tape',
          'Carpenter\'s square',
          'Cordless drill',
          'Screwdriver set',
          'Level',
          'Pencil'
        ],
        safetyRequirements: [
          'Wear safety glasses when drilling',
          'Use sharp drill bits to prevent binding'
        ],
        cautions: [
          'Do not overtighten screws in soft wood',
          'Check drawer clearance before final assembly'
        ],
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
            stepTools: stepData['stepTools'] != null
                ? List<String>.from(stepData['stepTools'])
                : [],
            stepHazards: stepData['stepHazards'] != null
                ? List<String>.from(stepData['stepHazards'])
                : [],
          );
        }).toList();

        loadedSOPs.add(SOP(
          id: doc.id,
          title: sopData['title'] ?? '',
          description: sopData['description'] ?? '',
          department: sopData['department'] ?? '',
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

  Future<SOP> createSop(
      String title, String description, String department) async {
    final String sopId = const Uuid().v4();
    final now = DateTime.now();

    final userId = _auth?.currentUser?.uid ?? 'local_user';

    // Default placeholder image for new SOPs
    String defaultImageUrl =
        'https://media.istockphoto.com/id/1271691214/photo/successful-furniture-assembly-worker-reads-instructions-to-assemble-shelf.jpg?s=612x612&w=0&k=20&c=KBMOiPX2o2WeTN6jcdpDVbMlBwizXTM2Sps2Jex2eQ0=';

    // Choose department-specific default image
    if (department.toLowerCase().contains('finish')) {
      defaultImageUrl =
          'https://media.istockphoto.com/id/1303862719/photo/applying-varnish-to-a-wooden-surface-with-a-brush.jpg?s=612x612&w=0&k=20&c=F5VFRuPmX_yreFirNlBBX98lPg_l2CqCDnG6I2WyFSY=';
    } else if (department.toLowerCase().contains('upholstery')) {
      defaultImageUrl =
          'https://media.istockphoto.com/id/1440598592/photo/close-up-hands-of-professional-upholsterer-stapling-fabric-to-a-furniture-upholstery-of-a.jpg?s=612x612&w=0&k=20&c=N1T8eAe1vP38ek4DxSXBt5rJ6p0ZfOiX62QkTIyUn10=';
    } else if (department.toLowerCase().contains('machine') ||
        department.toLowerCase().contains('cnc')) {
      defaultImageUrl =
          'https://media.istockphoto.com/id/1132841403/photo/a-cnc-wood-router-cutting-out-a-pattern-for-furniture.jpg?s=612x612&w=0&k=20&c=Bh-G3D0Fdo5RZtZdvnJxm-J1-qdmKI7hGU_WcGx29so=';
    }

    // Default first step for a new SOP
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
        final sopData = {
          'title': title,
          'description': description,
          'department': department,
          'revisionNumber': 1,
          'createdBy': userId,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'steps': [
            {
              'id': defaultFirstStep.id,
              'title': defaultFirstStep.title,
              'instruction': defaultFirstStep.instruction,
              'imageUrl': defaultFirstStep.imageUrl,
              'stepTools': defaultFirstStep.stepTools,
              'stepHazards': defaultFirstStep.stepHazards,
            }
          ],
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
      steps: [defaultFirstStep],
      tools: [],
      safetyRequirements: [],
      cautions: [],
    );

    _sops.add(sop);
    notifyListeners();
    return sop;
  }

  Future<SOP> createSopFromTemplate(
      String templateId, String title, String department) async {
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
          'steps': sop.steps
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
                  })
              .toList(),
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

    // Check if the file path is actually a data URL (for web)
    if (file.path.startsWith('data:image/')) {
      // This is already a data URL, just return it
      return file.path;
    }

    try {
      final ref = _storage!.ref().child(
          'sops/$sopId/steps/$stepId/${DateTime.now().millisecondsSinceEpoch}');
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
