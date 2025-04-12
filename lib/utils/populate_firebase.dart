import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class FirebasePopulator {
  final FirebaseFirestore _firestore;

  FirebasePopulator(this._firestore);

  Future<void> populateChairSOPs() async {
    try {
      // 1. Dining Chair Assembly SOP
      await _createChairSOP(
          title: 'Dining Chair Assembly',
          description: 'Complete assembly process for wooden dining chairs.',
          department: 'Assembly',
          steps: [
            {
              'title': 'Prepare Components',
              'instruction':
                  'Gather all wooden components: 4 legs, seat frame, backrest, and spindles. Ensure all parts are sanded and ready for assembly.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'helpNote':
                  'Check for any defects or cracks in the wood before proceeding.',
              'stepTools': [
                'Parts checklist',
                'Inspection light',
                'Sanding block'
              ],
            },
            {
              'title': 'Attach Legs to Seat Frame',
              'instruction':
                  'Apply wood glue to the leg joints and insert into the seat frame. Ensure legs are properly aligned at 90° angles.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1556228453-efd6c1ff04f6?q=80&w=1000&auto=format&fit=crop',
              'helpNote': 'Wipe excess glue immediately with a damp cloth.',
              'stepTools': ['Wood glue', 'Rubber mallet', 'Square', 'Clamps'],
            },
            {
              'title': 'Attach Backrest',
              'instruction':
                  'Apply wood glue to the backrest joints and attach to the seat frame. Use clamps to hold in place while securing with screws.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Wood glue',
                'Cordless drill',
                '1.5" wood screws',
                'Clamps'
              ],
            },
            {
              'title': 'Insert Spindles',
              'instruction':
                  'Apply wood glue to spindle ends and insert between the seat and backrest. Ensure even spacing between spindles.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Wood glue', 'Rubber mallet', 'Spacing jig'],
            },
            {
              'title': 'Final Assembly Check',
              'instruction':
                  'Check all joints for tightness. Apply pressure to ensure chair is sturdy. Wipe any excess glue.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1592078615290-033ee584e267?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Torque wrench', 'Cleaning cloth'],
            }
          ],
          tools: [
            'Rubber mallet',
            'Cordless drill',
            'Screwdriver set',
            'Clamps',
            'Square',
            'Cleaning cloth'
          ],
          safetyRequirements: [
            'Wear safety glasses when drilling',
            'Use clamps to secure workpieces',
            'Keep work area clean'
          ],
          cautions: [
            'Ensure proper ventilation when using adhesives',
            'Handle sharp tools with care'
          ]);

      // 2. Upholstered Chair Seat SOP
      await _createChairSOP(
          title: 'Upholstered Chair Seat Production',
          description:
              'Process for upholstering wooden chair seats with fabric and padding.',
          department: 'Upholstery',
          steps: [
            {
              'title': 'Prepare Wooden Seat Base',
              'instruction':
                  'Inspect wooden seat base for splinters or rough edges. Sand if necessary for a smooth surface.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Orbital sander',
                'Sandpaper (120-220 grit)',
                'Tack cloth'
              ],
            },
            {
              'title': 'Cut Foam Padding',
              'instruction':
                  'Measure and cut high-density foam to match seat dimensions with 1/2 inch overlap on all sides.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Measuring tape',
                'Electric knife',
                'Straight edge'
              ],
            },
            {
              'title': 'Attach Foam to Seat',
              'instruction':
                  'Apply spray adhesive to wooden seat base. Center foam on seat and press firmly to adhere.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Spray adhesive', 'Ventilation mask', 'Gloves'],
              'helpNote':
                  'Allow adhesive to become tacky before applying foam for best results.',
            },
            {
              'title': 'Cut Upholstery Fabric',
              'instruction':
                  'Cut fabric to size, allowing 4 inches of excess on all sides for wrapping and stapling.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Fabric scissors',
                'Measuring tape',
                'Chalk marker'
              ],
            },
            {
              'title': 'Upholster Seat',
              'instruction':
                  'Center fabric over padded seat. Starting from the center of each side, pull fabric taut and staple to underside of seat. Fold corners neatly and staple.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Pneumatic stapler',
                'Staples (3/8")',
                'Pliers',
                'Scissors'
              ],
              'helpNote': 'Keep fabric tension even to prevent wrinkles.',
            }
          ],
          tools: [
            'Pneumatic stapler',
            'Electric knife',
            'Fabric scissors',
            'Spray adhesive',
            'Orbital sander'
          ],
          safetyRequirements: [
            'Wear ventilation mask when using spray adhesive',
            'Use protective gloves',
            'Ensure proper ventilation'
          ],
          cautions: [
            'Test fabric for colorfastness',
            'Keep adhesives away from heat sources',
            'Store unused foam in fire-safe location'
          ]);

      // 3. Chair Back Frame Construction SOP
      await _createChairSOP(
          title: 'Chair Back Frame Construction',
          description:
              'Procedure for constructing wooden chair back frames with mortise and tenon joinery.',
          department: 'Woodworking',
          steps: [
            {
              'title': 'Select and Prepare Lumber',
              'instruction':
                  'Select straight-grained hardwood for back rails and stiles. Cut to rough dimensions, allowing 1/2 inch excess in length.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Table saw', 'Measuring tape', 'Pencil'],
            },
            {
              'title': 'Mill Stock to Final Dimensions',
              'instruction':
                  'Plane lumber to 7/8" thickness. Cut stiles to 28" length and rails to 16" length with jointer and table saw.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Planer', 'Jointer', 'Table saw', 'Push sticks'],
            },
            {
              'title': 'Mark Mortise Locations',
              'instruction':
                  'Mark mortise locations on stiles using layout template. Typical chair back has 3 rails requiring 6 mortises.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Mortise template',
                'Marking gauge',
                'Square',
                'Pencil'
              ],
            },
            {
              'title': 'Cut Mortises',
              'instruction':
                  'Set up mortiser with 3/8" bit. Cut mortises 1-1/2" deep on marked locations. Clean mortise corners with chisel if needed.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Mortiser',
                '3/8" mortising bit',
                'Chisels',
                'Mallet'
              ],
            },
            {
              'title': 'Cut Tenons on Rails',
              'instruction':
                  'Set up tenoning jig on table saw. Cut 3/8" tenons on rail ends to match mortises. Test fit and adjust as needed.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Table saw',
                'Tenoning jig',
                'Calipers',
                'Shoulder plane'
              ],
            },
            {
              'title': 'Assemble Frame',
              'instruction':
                  'Apply wood glue to tenons and insert into mortises. Clamp frame and check for square. Allow 24 hours for glue to dry completely.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Wood glue',
                'Bar clamps',
                'Corner clamps',
                'Square'
              ],
            }
          ],
          tools: [
            'Table saw',
            'Mortiser',
            'Jointer',
            'Planer',
            'Chisels',
            'Clamps',
            'Marking gauge'
          ],
          safetyRequirements: [
            'Wear eye protection',
            'Use push sticks on table saw',
            'Use dust collection system',
            'Wear ear protection'
          ],
          cautions: [
            'Never place hands near moving blades',
            'Ensure proper tool setup before cutting',
            'Check for metal in reclaimed wood'
          ]);

      // 4. Chair Leg Turning SOP
      await _createChairSOP(
          title: 'Chair Leg Turning on Lathe',
          description:
              'Procedure for turning consistent chair legs on a wood lathe.',
          department: 'Machinery',
          steps: [
            {
              'title': 'Select and Prepare Blanks',
              'instruction':
                  'Select straight-grained maple or oak blanks, 2" x 2" x 18". Mark centers on both ends of each blank.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Center finder', 'Pencil', 'Square'],
            },
            {
              'title': 'Mount Blank on Lathe',
              'instruction':
                  'Install drive center in headstock and live center in tailstock. Mount blank between centers and lock tailstock.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Drive center', 'Live center', 'Knockout bar'],
            },
            {
              'title': 'Rough Turn to Cylinder',
              'instruction':
                  'Set lathe to 800 RPM. Using roughing gouge, turn blank to 1-3/4" cylinder. Stop lathe and check diameter periodically.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Roughing gouge', 'Calipers', 'Spindle caliper'],
            },
            {
              'title': 'Mark Design Features',
              'instruction':
                  'Stop lathe. Mark key points of leg design: transitions, coves, beads, and tapers using layout tool and pencil.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Story stick', 'Pencil', 'Marking gauge'],
            },
            {
              'title': 'Turn Design Features',
              'instruction':
                  'Turn to marked dimensions using spindle gouge and skew chisel. Form coves with spindle gouge and beads with skew chisel.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Spindle gouge',
                'Skew chisel',
                'Parting tool',
                'Calipers'
              ],
            },
            {
              'title': 'Sand on the Lathe',
              'instruction':
                  'With lathe at 1000 RPM, sand leg with progressive grits: 120, 150, 180, 220. Keep sandpaper moving to prevent rings.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Sandpaper (multiple grits)', 'Sanding pad'],
            },
            {
              'title': 'Apply Finish on Lathe',
              'instruction':
                  'Apply sanding sealer with lathe at 500 RPM. Once dry, apply shellac or lacquer with clean cloth.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Sanding sealer',
                'Shellac',
                'Clean cloth',
                'Respirator'
              ],
            }
          ],
          tools: [
            'Wood lathe',
            'Roughing gouge',
            'Spindle gouge',
            'Skew chisel',
            'Parting tool',
            'Calipers',
            'Sandpaper'
          ],
          safetyRequirements: [
            'Wear face shield',
            'Secure loose clothing and hair',
            'Use dust collection',
            'Ensure proper tool rest height'
          ],
          cautions: [
            'Never adjust tool rest with lathe running',
            'Stand to side during startup',
            'Check for cracks in wood before turning'
          ]);

      // 5. Chair Quality Control SOP
      await _createChairSOP(
          title: 'Chair Quality Control Inspection',
          description:
              'Quality control procedures for finished chairs before packaging.',
          department: 'Quality',
          steps: [
            {
              'title': 'Visual Inspection',
              'instruction':
                  'Examine entire chair for visible defects: scratches, dents, uneven finish, or glue residue. Ensure consistent color and finish.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Inspection light',
                'Magnifying glass',
                'Inspection checklist'
              ],
            },
            {
              'title': 'Structural Stability Test',
              'instruction':
                  'Place chair on level surface. Check for rocking or unevenness. Apply pressure to joints to verify stability.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Level surface', 'Level tool', 'Pressure gauge'],
            },
            {
              'title': 'Weight Test',
              'instruction':
                  'Apply 250 lbs of weight to seat for 30 seconds. Check for creaking, movement, or joint failure.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Calibrated weights', 'Timer', 'Pressure pad'],
            },
            {
              'title': 'Measurement Verification',
              'instruction':
                  'Verify all dimensions against specification sheet: height, width, depth, seat height, and backrest angle.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': [
                'Tape measure',
                'Angle finder',
                'Specifications sheet'
              ],
            },
            {
              'title': 'Surface Finish Test',
              'instruction':
                  'Perform standard tests on finish: water drop test, scratch resistance test, and chemical resistance test if applicable.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['Test kit', 'Cotton swabs', 'Microfiber cloth'],
            },
            {
              'title': 'Documentation and Tagging',
              'instruction':
                  'Record all test results in quality control log. Attach QC passed tag to chair with date and inspector ID.',
              'imageUrl':
                  'https://images.unsplash.com/photo-1581539250439-c96689b516dd?q=80&w=1000&auto=format&fit=crop',
              'stepTools': ['QC log', 'QC tags', 'Barcode scanner'],
            }
          ],
          tools: [
            'Inspection light',
            'Level tool',
            'Tape measure',
            'Angle finder',
            'Calibrated weights',
            'QC log'
          ],
          safetyRequirements: [
            'Wear gloves when handling chemicals',
            'Use proper lifting technique for chair manipulation'
          ],
          cautions: [
            'Do not perform weight test if visual defects are found',
            'Report any unusual findings immediately'
          ]);

      if (kDebugMode) {
        print('Successfully populated Firebase with 5 chair SOPs!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error populating chair SOPs: $e');
      }
    }
  }

  Future<void> _createChairSOP({
    required String title,
    required String description,
    required String department,
    required List<Map<String, dynamic>> steps,
    required List<String> tools,
    required List<String> safetyRequirements,
    required List<String> cautions,
  }) async {
    final String sopId = const Uuid().v4();
    final now = DateTime.now();

    // Create main SOP document
    await _firestore.collection('sops').doc(sopId).set({
      'title': title,
      'description': description,
      'department': department,
      'revisionNumber': 1,
      'createdBy': 'admin@elmosfurniture.com',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'tools': tools,
      'safetyRequirements': safetyRequirements,
      'cautions': cautions,
    });

    // Create steps as subcollection
    for (int i = 0; i < steps.length; i++) {
      final stepId = '${sopId}_${i + 1}';
      final stepData = steps[i];

      await _firestore
          .collection('sops')
          .doc(sopId)
          .collection('steps')
          .doc(stepId)
          .set({
        'id': stepId,
        'title': stepData['title'] ?? '',
        'instruction': stepData['instruction'] ?? '',
        'imageUrl': stepData['imageUrl'] ?? '',
        'helpNote': stepData['helpNote'] ?? '',
        'assignedTo': stepData['assignedTo'] ?? '',
        'estimatedTime': stepData['estimatedTime'] ?? 0,
        'stepTools': stepData['stepTools'] ?? [],
        'stepHazards': stepData['stepHazards'] ?? [],
        'createdAt': Timestamp.fromDate(now),
      });
    }

    if (kDebugMode) {
      print('Created SOP: $title with ID: $sopId');
    }
  }
}
