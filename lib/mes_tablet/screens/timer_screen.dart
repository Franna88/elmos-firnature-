import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/furniture_item.dart';
import '../models/production_timer.dart';
import '../models/user.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_interruption_model.dart';
import '../../data/models/mes_process_model.dart';
import '../../data/models/mes_production_record_model.dart';
import '../../presentation/widgets/cross_platform_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/sop_model.dart';
import '../../data/services/sop_service.dart';
import '../../presentation/widgets/sop_viewer.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  FurnitureItem? _selectedItem; // Now optional - can be null initially
  late User _user;
  String? _recordId; // Now optional - created when item is selected
  late ProductionTimer _timer;
  int _secondsRemaining = 0; // Default to 0 when no item selected
  List<MESInterruptionType> _interruptionTypes = [];
  bool _isLoading = true;
  int _dailyNonProductiveSeconds = 0; // Track daily non-productive time
  Timer? _saveProgressTimer; // Timer for periodic data saving
  MESProcess? _process; // The process associated with this item
  bool _setupCompleted = false; // Track if setup has been completed
  MESInterruptionType?
      _selectedAction; // Currently selected action (not necessarily running)
  List<FurnitureItem> _availableItems = []; // Items available for selection
  final Map<String, String> _resumableItemRecordIds =
      {}; // Track record IDs for resumable items
  final Set<String> _onHoldItemIds = {}; // Track which items are on hold

  // Production data fields
  int _expectedQty = 0;
  int _qtyPerCycle = 0; // Starts at 0, increments when Next button is pressed
  int _finishedQty = 0;
  int _rejectQty = 0;

  // Production button state
  bool _isInProductionMode = false;

  // Shutdown state flag
  bool _isShuttingDown = false;

  @override
  void initState() {
    super.initState();
    // Initialize production timer with onTick callback
    _timer = ProductionTimer(onTick: () {
      if (mounted) {
        try {
          setState(() {
            // Update remaining time when timer is running
            if (_timer.mode == ProductionTimerMode.running) {
              // Decrease seconds remaining only if greater than zero
              if (_secondsRemaining > 0) {
                _secondsRemaining--;
              }
            }
            // Also update during setup mode to show setup timer progress
          });
        } catch (e) {
          // Ignore setState errors if widget is disposed
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use post-frame callback to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the arguments - handle null case
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs == null) {
        throw Exception('No route arguments provided to TimerScreen');
      }
      
      final args = routeArgs as Map<String, dynamic>;
      _user = args['user'] as User;
      _process = args['process'] as MESProcess;

      // Item and recordId are now optional - will be set when user selects an item
      if (args.containsKey('item')) {
        _selectedItem = args['item'] as FurnitureItem;
        _recordId = args['recordId'] as String;
        _secondsRemaining = _selectedItem!.estimatedTimeInMinutes * 60;
      }

      // Load interruption types (excluding PRODUCTION which is handled by Start Production button)
      final mesService = Provider.of<MESService>(context, listen: false);

      try {
        await mesService.fetchInterruptionTypes(onlyActive: true);
        if (!mounted) return;

        _interruptionTypes = mesService.interruptionTypes
            .where((type) => !type.name.toLowerCase().contains('production'))
            .toList();
      } catch (e) {
        print('Warning: Could not fetch interruption types: $e');
        // Set default interruption types if Firebase fails
        _interruptionTypes = [
          MESInterruptionType(
            id: 'idle',
            name: 'Idle',
            isActive: true,
            color: '#6C757D',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          MESInterruptionType(
            id: 'setup',
            name: 'Setup',
            isActive: true,
            color: '#FF9800',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          MESInterruptionType(
            id: 'break',
            name: 'Break',
            isActive: true,
            color: '#2196F3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          MESInterruptionType(
            id: 'on_hold',
            name: 'On Hold',
            isActive: true,
            color: '#9C27B0',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
      }

      // Load process information to check setup requirements
      try {
        await mesService.fetchProcesses(onlyActive: true);
        if (!mounted) return;
      } catch (e) {
        print('Warning: Could not fetch processes: $e');
        // Continue without process validation
      }

      // Load available items for this process
      try {
        final mesItems = await mesService.fetchItems(onlyActive: true);
        if (!mounted) return;

        // Filter items for the selected process and convert to FurnitureItem
        final processItems =
            mesItems.where((item) => item.processId == _process!.id).toList();

        // Load regular available items
        _availableItems = processItems
            .map((mesItem) => FurnitureItem(
                  id: mesItem.id,
                  name: mesItem.name,
                  category: mesItem.category ?? 'Uncategorized',
                  imageUrl: mesItem.imageUrl,
                  estimatedTimeInMinutes: mesItem.estimatedTimeInMinutes,
                ))
            .toList();

        // Load resumable (on hold) items for this user and process
        await _loadResumableItems(mesService, processItems);

        // Process is already set from arguments, no need to find it
        // If we have a selected item, validate it belongs to this process
        if (_selectedItem != null) {
          try {
            final mesItem =
                mesItems.firstWhere((item) => item.id == _selectedItem!.id);
            if (mesItem.processId != _process!.id) {
              throw Exception(
                  'Selected item does not belong to the selected process');
            }
          } catch (e) {
            print('Warning: Could not validate selected item: $e');
            // Continue anyway
          }
        }
      } catch (e) {
        print('Warning: Could not fetch items: $e');
        // Set default items if Firebase fails
        _availableItems = [
          FurnitureItem(
            id: 'default_chair',
            name: 'Chair Assembly',
            category: 'Chairs',
            imageUrl: null,
            estimatedTimeInMinutes: 30,
          ),
          FurnitureItem(
            id: 'default_table',
            name: 'Table Assembly',
            category: 'Tables',
            imageUrl: null,
            estimatedTimeInMinutes: 45,
          ),
        ];
      }

      // Load daily non-productive time (this can fail silently)
      try {
        await _loadDailyNonProductiveTime(mesService);
      } catch (e) {
        print('Warning: Could not load daily non-productive time: $e');
        // Continue without this data
      }
    } catch (e) {
      print('Critical error in _loadData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // ALWAYS set loading to false, even if there were errors
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Auto-activate Idle action when entering timer screen (if no item is selected)
        if (_selectedItem == null && _selectedAction == null) {
          _autoActivateIdleAction();
        }
      }
    }
  }

  Future<void> _loadDailyNonProductiveTime(MESService mesService) async {
    try {
      // Skip this for now to avoid the Firestore index error
      // TODO: Create the required Firestore index and re-enable this feature
      if (!mounted) return;

      _dailyNonProductiveSeconds = 0;

      // Commented out until Firestore index is created
      /*
      // Get today's date (without time)
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      // Get all records for today for this user
      final records = await mesService.fetchProductionRecords(
        userId: _user.id,
        startDate: today,
        endDate: today,
      );

      // Sum up all interruption times for today
      int totalSeconds = 0;
      for (var record in records) {
        totalSeconds += record.totalInterruptionTimeSeconds;
      }

      if (mounted) {
        setState(() {
          _dailyNonProductiveSeconds = totalSeconds;
        });
      }
      */
    } catch (e) {
      print('Error loading daily non-productive time: $e');
    }
  }

  @override
  void dispose() {
    print('🧹 TIMER SCREEN DISPOSE: Cleaning up resources...');
    
    // Record end of current action if any (but don't await to avoid blocking disposal)
    if (_timer.currentAction != null) {
      _recordActionEnd(_timer.currentAction!);
    }
    
    // Stop the timer completely
    try {
      _timer.stopAction();
      _timer.endShift();
      _timer.dispose();
    } catch (e) {
      print('Warning: Error disposing timer: $e');
    }
    
    // Cancel periodic saving
    _saveProgressTimer?.cancel();
    _saveProgressTimer = null;
    
    print('✅ TIMER SCREEN DISPOSED: All resources cleaned up');
    super.dispose();
  }

  // Start or resume production
  void _startTimer() async {
    // Setup handling removed - actions switch immediately

    setState(() {
      _timer.startProduction();
    });

    // Start periodic saving if this is the first time starting
    if (_timer.productionStartCount == 1) {
      _startPeriodicSaving();
      return;
    }

    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
              ),
            ),
      );
    } catch (e) {
      // Silent error - we'll try again later
    }
  }

  // Start periodic saving of production data
  void _startPeriodicSaving() {
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_timer.mode == ProductionTimerMode.running) {
        _saveProductionProgress();
      }
    });
  }

  // Pause production
  void _pauseTimer() {
    setState(() {
      _timer.pauseProduction();
    });
  }

  // Auto-activate Idle action when entering timer screen or when no action is selected
  void _autoActivateIdleAction() {
    try {
      final idleType = _interruptionTypes.firstWhere(
        (type) => type.name.toLowerCase().contains('idle'),
      );

      setState(() {
        _selectedAction = idleType;
        _timer.startAction(idleType);
      });

      // Record the start of Idle action in Firebase
      _recordActionStart(idleType);

      print('✅ AUTO-ACTIVATED IDLE: Timer is now running on Idle action');
    } catch (e) {
      print('❌ NO IDLE ACTION AVAILABLE: Cannot auto-activate');
    }
  }

  // Ensure timer always has an action running (fallback to Idle)
  void _ensureActionRunning() {
    // If no action is currently selected, activate Idle
    // (unless we're in the middle of a shutdown process)
    if (_selectedAction == null && !_isShuttingDown) {
      _autoActivateIdleAction();
    }
  }

  // Select an action directly (simplified - no popups)
  void _startAction(MESInterruptionType type) {
    // Business Rules: Check if action is allowed
    final actionName = type.name.toLowerCase();

    // Business Rule: Standard actions require item selection (except Idle and Shutdown), but Other actions are allowed without item selection
    if (_selectedItem == null && !actionName.contains('idle') && !actionName.contains('shutdown') && _isStandardAction(type)) {
      _showActionBlockedDialog(
        'No Item Selected',
        'Please select an item first before starting standard actions.\n\nStandard action timers must run against a selected item for proper recording.',
      );
      return;
    }

    // Business Rule 1: Setup action - prompt if job completed when selecting setup
    if (actionName.contains('setup')) {
      // If we already have an item selected and any action running, ask if job is completed
      if (_selectedItem != null && _selectedAction != null) {
        _showSetupJobCompleteDialog(type);
        return;
      }
    }

    // Business Rule 2: Job Complete can only be selected if Finished QTY has value
    if (actionName.contains('job') && actionName.contains('complete')) {
      if (_finishedQty <= 0) {
        _showActionBlockedDialog(
          'Job Complete Blocked',
          'Job Complete can only be selected if Finished QTY has a value.\n\nCurrent Finished QTY: $_finishedQty\n\nPlease complete some items first or update the finished quantity.',
        );
        return;
      }
    }

    // Business Rule 3: Shut Down - check Total QTY and confirm end of day
    if (actionName.contains('shut') && actionName.contains('down')) {
      _handleShutdownAction(type);
      return;
    }

    // Business Rule 4: Counting - show item popup while keeping timer rolling
    if (actionName.contains('counting')) {
      _handleCountingAction(type);
      return;
    }

    // Business Rule 5: On Hold - pause current production and mark as on hold
    if (actionName.contains('hold')) {
      _handleOnHoldAction(type);
      return;
    }

    // All business rules passed - proceed with action
    _proceedWithAction(type);
  }

  // Show dialog when action is blocked by business rules
  void _showActionBlockedDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show dialog asking if job is completed when switching to Setup
  void _showSetupJobCompleteDialog(MESInterruptionType setupType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Job Status Check'),
          ],
        ),
        content: Text(
          'You are switching from "${_selectedAction?.name}" to Setup.\n\n'
          'Has the current job been completed?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Job not completed - just switch to setup
              _proceedWithAction(setupType);
            },
            child: const Text('No - Continue Setup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Job completed - open item popup with counting action for final QTY entry
              _showJobCompletionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yes - Job Completed'),
          ),
        ],
      ),
    );
  }

  // Show job completion dialog with counting action and final QTY requirement
  void _showJobCompletionDialog() {
    // Find the counting action
    final countingAction = _interruptionTypes.firstWhere(
      (type) => type.name.toLowerCase().contains('counting'),
      orElse: () => _interruptionTypes.first,
    );

    // Switch to counting action first
    _proceedWithAction(countingAction);

    // Then show the item dialog with enforced final QTY entry
    _showItemSelectionDialogForCompletion();
  }

  // Show item dialog for job completion with final QTY requirement
  void _showItemSelectionDialogForCompletion() {
    if (_selectedItem == null) return;

    final TextEditingController expectedQtyController =
        TextEditingController(text: _expectedQty.toString());
    final TextEditingController finishedQtyController =
        TextEditingController(text: _finishedQty.toString());
    final TextEditingController rejectQtyController =
        TextEditingController(text: _rejectQty.toString());

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to complete the process
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.02,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.task_alt,
                      color: Colors.green,
                      size: MediaQuery.of(context).size.height * 0.035),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.012),
                  Flexible(
                    child: Text(
                      'Complete Job: ${_selectedItem!.name}',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.height * 0.028,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: MediaQuery.of(context).size.height * 0.03),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.all(4),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.012),
              Text(
                'Please enter the final quantities before completing this job:',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.height * 0.022,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Quantity fields in a 2x2 grid - With frames matching Item Setup
                      Column(
                        children: [
                          // Top row: Expected QTY and QTY per Cycle
                          Row(
                            children: [
                              Expanded(
                                child: _buildUniformFramedSection(
                                  title: 'Expected QTY',
                                  icon: Icons.trending_up,
                                  color: AppColors.primaryBlue,
                                  badge: 'PLANNED',
                                  child: _buildUniformNumberField(
                                      expectedQtyController,
                                      'Expected QTY',
                                      AppColors.primaryBlue),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildUniformFramedSection(
                                  title: 'QTY per Cycle',
                                  icon: Icons.add_circle,
                                  color: AppColors.greenAccent,
                                  badge: 'CYCLES',
                                  child: _buildUniformDisplayField(
                                    value: '$_qtyPerCycle',
                                    subtitle: 'Completed cycles',
                                    color: AppColors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
              ),
              SizedBox(height: 16),
                          // Bottom row: Finished QTY and Reject QTY
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 140,
                                  padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 3, // Thicker border for emphasis
                                    ),
                                  ),
                                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Finished QTY',
                            style: TextStyle(
                                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'REQUIRED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Expanded(
                                        child: Center(
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: TextFormField(
                controller: finishedQtyController,
                keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(width: 2, color: Colors.red),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                                suffixIcon: Icon(Icons.edit, color: Colors.red, size: 18),
                                                hintText: 'Enter count',
                                                hintStyle: TextStyle(color: Colors.red.withOpacity(0.5)),
                                              ),
                                            ),
                                          ),
                ),
              ),
            ],
          ),
        ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildUniformFramedSection(
                                  title: 'Reject QTY',
                                  icon: Icons.cancel,
                                  color: AppColors.orangeAccent,
                                  badge: 'REJECT',
                                  child: _buildUniformNumberField(
                                      rejectQtyController,
                                      'Reject QTY',
                                      AppColors.orangeAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.02),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
          ),
          ElevatedButton(
            onPressed: () {
              // Validate that Finished QTY has been entered
              final finishedQty = int.tryParse(finishedQtyController.text) ?? 0;
              if (finishedQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Please enter a valid Finished QTY greater than 0'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                return;
              }

              // Save the final quantities
              _completeJobAndReset(
                expectedQty: int.tryParse(expectedQtyController.text) ?? 0,
                finishedQty: finishedQty,
                rejectQty: int.tryParse(rejectQtyController.text) ?? 0,
              );

              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Complete Job',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Complete job and reset for new item selection
  Future<void> _completeJobAndReset({
    required int expectedQty,
    required int finishedQty,
    required int rejectQty,
  }) async {
    if (_selectedItem == null) return;

    // Store item name before clearing state
    final completedItemName = _selectedItem!.name;

    try {
      // Save final production data to Firebase
      await _saveProductionDataToFirebase(
        item: _selectedItem!,
        expectedQty: expectedQty,
        qtyPerCycle: _qtyPerCycle,
        finishedQty: finishedQty,
        rejectQty: rejectQty,
      );

      // Update production record status to completed
      if (_recordId != null) {
        final mesService = Provider.of<MESService>(context, listen: false);
        final currentRecord = await mesService.getProductionRecord(_recordId!);
        final completedRecord = currentRecord.copyWith(
            status: ProductionStatus.completed,
            endTime: DateTime.now(),
          totalProductionTimeSeconds: _timer.getProductionTime(),
          totalInterruptionTimeSeconds: _getNonProductionActionTime(),
          itemCompletionRecords: _timer.completedItems,
          isCompleted: true,
        );
        await mesService.updateProductionRecord(completedRecord);
        
        print('🎯 JOB COMPLETION - FINAL RECORD UPDATE:');
        print('    - Record ID: ${completedRecord.id}');
        print('    - Item ID: ${completedRecord.itemId}');
        print('    - User Name: ${completedRecord.userName}');
        print('    - Start Time: ${completedRecord.startTime}');
        print('    - End Time: ${completedRecord.endTime}');
        print('    - Total Production Time: ${completedRecord.totalProductionTimeSeconds}s');
        print('    - Total Interruption Time: ${completedRecord.totalInterruptionTimeSeconds}s');
        print('    - Is Completed: ${completedRecord.isCompleted}');
        print('    - Status: ${completedRecord.status}');
        print('    - Interruptions: ${completedRecord.interruptions.length}');
        print('    - Item Completions: ${completedRecord.itemCompletionRecords.length}');
      }

      // Reset all state for new item selection
      setState(() {
        _selectedItem = null;
        _recordId = null;
        _expectedQty = 0;
        _qtyPerCycle = 0;
        _finishedQty = 0;
        _rejectQty = 0;
        _selectedAction = null;
        _isInProductionMode = false;
        _timer.resetForNewItemInDay(); // Clear timer but keep Total Time and session stats running
      });

      // Ensure timer always has an action running - fallback to Idle
      _ensureActionRunning();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job completed successfully! $completedItemName finished with $finishedQty items.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      print(
          '✅ JOB COMPLETED: $completedItemName with $finishedQty finished items');
    } catch (e) {
      print('❌ Error completing job: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing job: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Mark job as completed (increment qty per cycle only)
  void _markJobCompleted() {
    setState(() {
      _qtyPerCycle += 1; // Increment qty per cycle
      // Finished QTY remains manual entry only - not auto-incremented
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Job completed! QTY per cycle incremented (now $_qtyPerCycle)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Handle counting action - show item popup while keeping timer rolling
  void _handleCountingAction(MESInterruptionType countingType) {
    // First switch to counting action to start timer
    _proceedWithAction(countingType);

    // Then show the item selection popup for quantity updates
    _showItemSelectionDialog();
  }

  // Handle On Hold action - pause current production and mark as on hold
  void _handleOnHoldAction(MESInterruptionType onHoldType) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Put Item On Hold'),
        content: Text(
          'This will pause production of "${_selectedItem?.name}" and mark it as on hold.\n\n'
          'You can resume this item later from the item selection screen.\n\n'
          'Current progress and timing will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleAccent,
            ),
            child: const Text('Put On Hold'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Record the on hold action
      _proceedWithAction(onHoldType);

      // Wait a moment for the action to be recorded
      await Future.delayed(const Duration(seconds: 1));

      // Update the production record status to "On Hold"
      if (_recordId != null) {
        final record = await mesService.getProductionRecord(_recordId!);
        await mesService.updateProductionRecord(
          record.copyWith(status: ProductionStatus.onHold),
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedItem?.name} has been put on hold. You can resume it later.'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.purpleAccent,
          ),
        );

        // Navigate back to item selection after a brief delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/item_selection',
              arguments: _user,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error putting item on hold: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle End Job action - same workflow as Setup completion
  void _handleEndJobAction() {
    // Use the same job completion workflow as Setup
    _showJobCompletionDialog();
  }

  // Handle Shutdown action - check total qty and confirm end of day
  void _handleShutdownAction(MESInterruptionType shutdownType) {
    // Check if Total QTY is not 0 (unless we're in Idle mode)
    if (_finishedQty <= 0 && !_isCurrentlyInIdleMode()) {
      _showActionBlockedDialog(
        'Shutdown Blocked',
        'Shutdown can only be selected if Total QTY is not 0.\n\nCurrent Total QTY: $_finishedQty\n\nPlease complete some items first or update the finished quantity.',
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('End of Day Confirmation'),
          content: Text(
            'Are you sure you want to end the day?\n\nThis will complete the current job and return to the process selection screen.\n\nCurrent Total QTY: $_finishedQty',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _proceedWithShutdown(shutdownType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('End Day'),
            ),
          ],
        );
      },
    );
  }

  // Proceed with shutdown after confirmation
  void _proceedWithShutdown(MESInterruptionType shutdownType) async {
    // Set shutdown flag to prevent Idle fallback
    setState(() {
      _isShuttingDown = true;
    });

    // First execute the shutdown action
    _proceedWithAction(shutdownType);

    // Wait a moment for the action to be recorded
    await Future.delayed(Duration(seconds: 1));

    // Complete shutdown: stop timer completely and navigate back
    await _completeShutdown();
  }

  // Complete shutdown process - stop timer and navigate back
  Future<void> _completeShutdown() async {
    try {
      // Stop all timer activities completely
      if (_timer.currentAction != null) {
        _recordActionEnd(_timer.currentAction!);
      }

      // Stop the timer completely (no fallback to Idle)
      _timer.stopAction();
      _timer.endShift(); // Stop the entire timer system

      // Cancel any periodic saving
      _saveProgressTimer?.cancel();
      _saveProgressTimer = null;

      // Clear all state
      setState(() {
        _selectedItem = null;
        _recordId = null;
        _selectedAction = null;
        _isInProductionMode = false;
        _expectedQty = 0;
        _qtyPerCycle = 0;
        _finishedQty = 0;
        _rejectQty = 0;
      });

      print('✅ SHUTDOWN COMPLETE: Timer stopped completely');

      // Navigate back to process selection screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/process_selection', arguments: _user);
      }
    } catch (e) {
      print('❌ Error during shutdown: $e');
      // Still navigate back even if there was an error
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/process_selection', arguments: _user);
      }
    }
  }

  // Show counting dialog to update quantities while timer keeps running
  void _showCountingDialog() {
    // Pre-populate with current values
    final TextEditingController finishedQtyController =
        TextEditingController(text: _finishedQty.toString());
    final TextEditingController rejectQtyController =
        TextEditingController(text: _rejectQty.toString());
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false, // Don't allow dismissing during counting
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory, color: Colors.purple),
            SizedBox(width: 8),
            Text('Count Items'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Count your items and update the quantities below.\nTimer continues running for Counting action.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: finishedQtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Finished QTY',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final qty = int.tryParse(value);
                        if (qty == null || qty < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: rejectQtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Reject QTY',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final qty = int.tryParse(value);
                          if (qty == null || qty < 0) return 'Must be ≥ 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newFinishedQty = int.parse(finishedQtyController.text);
                final newRejectQty =
                    int.tryParse(rejectQtyController.text) ?? 0;

                setState(() {
                  _finishedQty = newFinishedQty;
                  _rejectQty = newRejectQty;
                });

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Quantities updated: Finished: $newFinishedQty, Reject: $newRejectQty'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Update Counts'),
          ),
        ],
      ),
    );
  }

  // Handle Production button press
  void _handleProductionButton() {
    if (!_isInProductionMode) {
      // First press: Switch to Production action
      _switchToProductionMode();
    } else {
      // In production mode: increment count (Next functionality)
      _incrementProductionCount();
    }
  }

  // Switch to production mode
  void _switchToProductionMode() {
    // Create a Production action type
    final productionAction = MESInterruptionType(
      id: 'production',
      name: 'Production',
      isActive: true,
      color: '#4CAF50', // Green
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _isInProductionMode = true;

      // Start production if not already started
      if (_timer.mode == ProductionTimerMode.notStarted ||
          _timer.mode == ProductionTimerMode.setup) {
        _timer.startProduction();
      }

      // If there's a current action, stop it first
      if (_timer.currentAction != null) {
        _recordActionEnd(_timer.currentAction!);
        _timer.stopAction();
      }

      // Select and start Production action (this will start item timer because it's Production)
      _selectedAction = productionAction;
      _timer.startAction(productionAction);
    });

    // Record the start of production action
    _recordActionStart(productionAction);

    // Production mode activated - no feedback message needed
  }

  // Increment production count (Next functionality)
  void _incrementProductionCount() {
    // Call the same functionality as Next Item
    _nextItem();
  }

  // Proceed with action without business rule checks (used after validation)
  void _proceedWithAction(MESInterruptionType type) {
    print('🔥 DEBUG: _proceedWithAction called for: ${type.name}');
    setState(() {
      // Business Rule 5: Reset production mode when other actions are selected
      if (!type.name.toLowerCase().contains('production')) {
        _isInProductionMode = false;
      }

      // Stop current action if any and record the end
      if (_timer.currentAction != null) {
        print('🔄 Stopping current action: ${_timer.currentAction!.name}');
        _recordActionEnd(_timer.currentAction!);
        _timer.stopAction();
      } else {
        print('🔄 No current action to stop');
      }

      // Select and start the new action immediately
      _selectedAction = type;
      _timer.startAction(type);

      // Debug information
      print('🔄 ACTION SWITCHED: ${type.name}');
      print('⏱️ TIMER RESET: Action time should start from 0');
      print('🎯 TIMER MODE: ${_timer.mode}');
      print('🎯 CURRENT ACTION: ${_timer.currentAction?.name ?? "NONE"}');
      print('📺 DISPLAY SHOULD SHOW: ${type.name.toUpperCase()}');
      print('🕐 ACTION TIME: ${_timer.getActionTime()}s');
      print('🕐 SETUP TIME: ${_timer.getSetupTime()}s');
    });

    // Record the start of this action in Firebase
    _recordActionStart(type);

    // Action selected - no feedback message needed
  }

  // Business Rule: Check if user can select a new item
  bool _canSelectNewItem() {
    // If no item is selected, can always select first item
    if (_selectedItem == null) return true;

    // Business Rule: Cannot select new item if current item has 0 final/finished QTY
    return _finishedQty > 0;
  }

  // Show item selection dialog
  void _showItemSelectionDialog() {
    // Always show the dialog - restrictions will be handled inside the dialog
    FurnitureItem? selectedItem =
        _selectedItem; // Pre-select current item if any
    final TextEditingController expectedQtyController =
        TextEditingController(text: _expectedQty.toString());
    // QTY per Cycle is now displayed dynamically, no controller needed
    final TextEditingController finishedQtyController =
        TextEditingController(text: _finishedQty.toString());
    final TextEditingController rejectQtyController =
        TextEditingController(text: _rejectQty.toString());

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.02,
              vertical: MediaQuery.of(context).size.height * 0.015,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.settings,
                        color: AppColors.primaryBlue,
                        size: MediaQuery.of(context).size.height *
                            0.035), // Responsive icon
                    SizedBox(
                        width: MediaQuery.of(context).size.width *
                            0.012), // Responsive spacing
                    Flexible(
                      child: Text(
                        'Item Production Setup',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height *
                              0.028, // Responsive text
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: MediaQuery.of(context).size.height *
                              0.03), // Responsive close
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.all(4),
                    ),
                  ],
                ),
                SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.012), // Responsive spacing
                Text(
                  'Process: ${_process?.name ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height *
                        0.022, // Responsive font size
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.015), // Responsive spacing

                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warning message when item selection is restricted
                        if (!_canSelectNewItem())
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.orange.shade700, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot change item: Current item "${_selectedItem!.name}" has 0 finished quantity. Complete some items first or update the finished quantity to select a different item.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 1. Selected Item Dropdown - Made More Prominent
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star, color: AppColors.primaryBlue, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Selected Item',
                                    style: TextStyle(
                                      fontSize: MediaQuery.of(context).size.height * 0.030,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'STEP 1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                              Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.02,
                                vertical: MediaQuery.of(context).size.height *
                                    0.015), // Responsive padding
                            decoration: BoxDecoration(
                              border: Border.all(
                                    color: AppColors.primaryBlue, width: 2),
                              borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<FurnitureItem>(
                                value: selectedItem,
                                hint: Text('Select an item to build',
                                    style: TextStyle(fontSize: 16)),
                                isExpanded: true,
                                items: _availableItems.isEmpty
                                    ? [
                                        DropdownMenuItem<FurnitureItem>(
                                          value: null,
                                          child: Text(
                                            'No items available for this process',
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14),
                                          ),
                                        )
                                      ]
                                    : _availableItems.map((item) {
                                        return DropdownMenuItem<FurnitureItem>(
                                          value: item,
                                          child: Row(
                                            children: [
                                              Icon(Icons.inventory_2,
                                                  size: 20,
                                                  color: AppColors.primaryBlue),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.name,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                fontSize: 16),
                                                          ),
                                                        ),
                                                        if (_onHoldItemIds
                                                            .contains(item.id))
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        2),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .purpleAccent,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            child: Text(
                                                              'ON HOLD',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    Text(
                                                      _onHoldItemIds
                                                              .contains(item.id)
                                                          ? 'Resume previous work'
                                                          : '${item.estimatedTimeInMinutes} min est.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: _onHoldItemIds
                                                                .contains(
                                                                    item.id)
                                                            ? AppColors
                                                                .purpleAccent
                                                            : Colors
                                                                .grey.shade600,
                                                        fontWeight:
                                                            _onHoldItemIds
                                                                    .contains(
                                                                        item.id)
                                                                ? FontWeight
                                                                    .w600
                                                                : FontWeight
                                                                    .normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                onChanged: _canSelectNewItem()
                                    ? (FurnitureItem? value) {
                                        setDialogState(() {
                                          selectedItem = value;
                                        });
                                      }
                                    : null, // Disable dropdown when cannot select new item
                              ),
                                  ),
                                ),
                              ],
                            ),
                        ), // Close the prominent container

                        const SizedBox(height: 24),

                        // Quantity fields in a 2x2 grid - Uniform sizing
                        Column(
                          children: [
                            // Top row: Expected QTY and QTY per Cycle
                        Row(
                          children: [
                            Expanded(
                                  child: _buildUniformFramedSection(
                                    title: 'Expected QTY',
                                    icon: Icons.trending_up,
                                    color: AppColors.primaryBlue,
                                    badge: 'STEP 2',
                                    child: _buildUniformNumberField(
                                    expectedQtyController,
                                    'Expected QTY',
                                    AppColors.primaryBlue),
                              ),
                            ),
                                SizedBox(width: 16),
                            Expanded(
                                  child: _buildUniformFramedSection(
                                    title: 'QTY per Cycle',
                                    icon: Icons.add_circle,
                                              color: AppColors.greenAccent,
                                    badge: 'AUTO',
                                    child: _buildUniformDisplayField(
                                      value: '$_qtyPerCycle',
                                      subtitle: 'Incremented with "Next"',
                                            color: AppColors.greenAccent,
                                    ),
                                        ),
                                      ),
                                    ],
                                  ),
                            SizedBox(height: 16),
                        // Bottom row: Finished QTY and Reject QTY
                        Row(
                          children: [
                            Expanded(
                                  child: _buildUniformFramedSection(
                                    title: 'Finished QTY',
                                    icon: Icons.check_circle,
                                    color: AppColors.greenAccent,
                                    badge: 'DONE',
                                    child: _buildUniformNumberField(
                                    finishedQtyController,
                                    'Finished QTY',
                                    AppColors.greenAccent),
                              ),
                            ),
                                SizedBox(width: 16),
                            Expanded(
                                  child: _buildUniformFramedSection(
                                    title: 'Reject QTY',
                                    icon: Icons.cancel,
                                    color: AppColors.orangeAccent,
                                    badge: 'REJECT',
                                    child: _buildUniformNumberField(
                                    rejectQtyController,
                                    'Reject QTY',
                                    AppColors.orangeAccent),
                              ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.02), // Responsive spacing

                // Action buttons - More compact
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Cancel button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.03,
                            vertical: MediaQuery.of(context).size.height * 0.015),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.022,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600),
                      ),
                    ),

                    // Center: On Hold button (only show if item is currently selected)
                    if (selectedItem != null &&
                        _selectedItem != null &&
                        _selectedItem!.id == selectedItem!.id)
                      ElevatedButton.icon(
                        onPressed: () {
                          // Handle On Hold action
                          Navigator.of(context).pop(); // Close dialog first

                          // Find the "On Hold" interruption type
                          final onHoldType = _interruptionTypes.firstWhere(
                            (type) => type.name.toLowerCase().contains('hold'),
                            orElse: () => _interruptionTypes.first,
                          );

                          // Trigger the on hold action
                          _handleOnHoldAction(onHoldType);
                        },
                        icon: Icon(Icons.pause_circle, size: 18),
                        label: Text(
                          'On Hold',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.02,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purpleAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.025,
                            vertical:
                                MediaQuery.of(context).size.height * 0.015,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                    // Right side: OK button
                        ElevatedButton(
                          onPressed: selectedItem == null
                              ? null
                              : () {
                                  // Check if item has changed or timer is not running
                                  bool itemChanged =
                                      _selectedItem?.id != selectedItem!.id;
                                  bool timerIsRunning = _timer.mode !=
                                      ProductionTimerMode.notStarted;

                                  if (itemChanged && timerIsRunning) {
                                    // Item changed and timer is running - save with item change
                                    _saveItemProductionData(
                                      item: selectedItem!,
                                      expectedQty: int.tryParse(
                                              expectedQtyController.text) ??
                                          0,
                                      qtyPerCycle: _qtyPerCycle,
                                      finishedQty: int.tryParse(
                                              finishedQtyController.text) ??
                                          0,
                                      rejectQty: int.tryParse(
                                              rejectQtyController.text) ??
                                          0,
                                    );
                                  } else if (!itemChanged && timerIsRunning) {
                                    // Same item and timer is running - just save data, don't restart
                                    _saveQuantityDataOnly(
                                      expectedQty: int.tryParse(
                                              expectedQtyController.text) ??
                                          0,
                                      qtyPerCycle: _qtyPerCycle,
                                      finishedQty: int.tryParse(
                                              finishedQtyController.text) ??
                                          0,
                                      rejectQty: int.tryParse(
                                              rejectQtyController.text) ??
                                          0,
                                    );
                                  } else {
                                    // Timer not running or initial setup - normal flow
                                    _saveItemProductionData(
                                      item: selectedItem!,
                                      expectedQty: int.tryParse(
                                              expectedQtyController.text) ??
                                          0,
                                      qtyPerCycle: _qtyPerCycle,
                                      finishedQty: int.tryParse(
                                              finishedQtyController.text) ??
                                          0,
                                      rejectQty: int.tryParse(
                                              rejectQtyController.text) ??
                                          0,
                                    );
                                  }
                                  Navigator.of(context).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.04,
                            vertical: MediaQuery.of(context).size.height * 0.018),
                            shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'OK',
                            style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.025,
                            fontWeight: FontWeight.bold),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build responsive form fields with labels
  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.height * 0.025,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        child,
      ],
    );
  }

  // Show compact number pad optimized for mobile web
  void _showCompactNumberPad(TextEditingController controller, String title) {
    String currentValue = controller.text;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 400,
            //MediaQuery.of(context).size.width * 0.40, // Optimized width
            height: 600,
            //MediaQuery.of(context).size.height, // Reduced height to prevent overflow
            padding: const EdgeInsets.all(20), // Reduced padding
            child: Column(
              children: [
                // Header - Compact
                Row(
                  children: [
                    Icon(Icons.dialpad, color: AppColors.primaryBlue, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Display current value - Compact
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: MediaQuery.of(context).size.height * 0.01,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade50,
                  ),
                  child: Text(
                    currentValue.isEmpty ? '0' : currentValue,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height *
                          0.025, // Responsive text
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Number pad grid - Compact for screen fit
                SizedBox(
                  height: 180, // Reduced height for better screen fit
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 2.0, // Even wider, shorter buttons
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 4,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      // Numbers 1-9
                      for (int i = 1; i <= 9; i++)
                        _buildMobileNumberButton(i.toString(), () {
                          setState(() {
                            if (currentValue == '0') {
                              currentValue = i.toString();
                            } else {
                              currentValue += i.toString();
                            }
                          });
                        }),

                      // Clear button
                      _buildMobileNumberButton('C', () {
                        setState(() {
                          currentValue = '0';
                        });
                      }, color: AppColors.orangeAccent),

                      // Zero
                      _buildMobileNumberButton('0', () {
                        setState(() {
                          if (currentValue != '0') {
                            currentValue += '0';
                          }
                        });
                      }),

                      // Backspace
                      _buildMobileNumberButton('⌫', () {
                        setState(() {
                          if (currentValue.length > 1) {
                            currentValue = currentValue.substring(
                                0, currentValue.length - 1);
                          } else {
                            currentValue = '0';
                          }
                        });
                      }, color: AppColors.orangeAccent),
                    ],
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                // Action buttons - Compact
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical:
                                MediaQuery.of(context).size.height * 0.012,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.height * 0.018,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          controller.text = currentValue;
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical:
                                MediaQuery.of(context).size.height * 0.012,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.02,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show large number pad for warehouse workers with gloves
  void _showNumberPad(TextEditingController controller, String title) {
    String currentValue = controller.text;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.dialpad, color: AppColors.primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 40,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Display current value
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Text(
                    currentValue.isEmpty ? '0' : currentValue,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Number pad grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      // Numbers 1-9
                      for (int i = 1; i <= 9; i++)
                        _buildNumberButton(i.toString(), () {
                          setState(() {
                            if (currentValue == '0') {
                              currentValue = i.toString();
                            } else {
                              currentValue += i.toString();
                            }
                          });
                        }),

                      // Clear button
                      _buildNumberButton('C', () {
                        setState(() {
                          currentValue = '0';
                        });
                      }, color: AppColors.orangeAccent),

                      // Zero
                      _buildNumberButton('0', () {
                        setState(() {
                          if (currentValue != '0') {
                            currentValue += '0';
                          }
                        });
                      }),

                      // Backspace
                      _buildNumberButton('⌫', () {
                        setState(() {
                          if (currentValue.length > 1) {
                            currentValue = currentValue.substring(
                                0, currentValue.length - 1);
                          } else {
                            currentValue = '0';
                          }
                        });
                      }, color: AppColors.orangeAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          controller.text = currentValue;
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build compact number pad button
  Widget _buildCompactNumberButton(String text, VoidCallback onPressed,
      {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.grey.shade100,
        foregroundColor: color != null ? Colors.white : Colors.black,
        padding: EdgeInsets.all(6), // Smaller padding for compact buttons
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Smaller radius
        ),
        elevation: 1, // Less elevation
        minimumSize: Size(50, 50), // Set minimum size for touch-friendliness
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18, // Smaller font to fit better
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper method to build uniform framed sections
  Widget _buildUniformFramedSection({
    required String title,
    required IconData icon,
    required Color color,
    required String badge,
    required Widget child,
  }) {
    return Container(
      height: 140, // Fixed height for uniformity
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(child: child), // Make child fill remaining space
        ],
      ),
    );
  }

  // Helper method to build uniform number input fields
  Widget _buildUniformNumberField(
    TextEditingController controller,
    String title,
    Color iconColor,
  ) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            suffixIcon: Icon(Icons.edit, color: iconColor, size: 18),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            final qty = int.tryParse(value);
            if (qty == null || qty < 0) return 'Must be ≥ 0';
            return null;
          },
        ),
      ),
    );
  }

  // Helper method to build uniform display field (for auto-increment values)
  Widget _buildUniformDisplayField({
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to build framed sections with consistent styling (legacy)
  Widget _buildFramedSection({
    required String title,
    required IconData icon,
    required Color color,
    required String badge,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // Build mobile web optimized number pad button
  Widget _buildMobileNumberButton(String text, VoidCallback onPressed,
      {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.grey.shade100,
        foregroundColor: color != null ? Colors.white : Colors.black,
        padding: const EdgeInsets.all(4), // Much smaller padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        elevation: 1,
        minimumSize: const Size(50, 35), // Compact size for screen fit
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14, // Compact font size
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build large number pad button
  Widget _buildNumberButton(String text, VoidCallback onPressed,
      {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.grey.shade100,
        foregroundColor: color != null ? Colors.white : Colors.black,
        padding: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper method to build compact form fields with labels
  Widget _buildCompactFormField(
      {required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14, // Compact label text
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8), // Less spacing
        child,
      ],
    );
  }

  // Helper method to build narrow number input fields (tablet-friendly)
  Widget _buildNarrowNumberField(
    TextEditingController controller,
    String title,
    Color iconColor, {
    String? helperText,
  }) {
    return SizedBox(
      width: 120, // Fixed narrow width for numbers
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Icon(Icons.edit, color: iconColor, size: 18),
          helperText: helperText,
          helperStyle: TextStyle(fontSize: 10),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          final qty = int.tryParse(value);
          if (qty == null || qty < 0) return 'Must be ≥ 0';
          return null;
        },
      ),
    );
  }

  // Helper method to build compact number input fields (deprecated - keeping for compatibility)
  Widget _buildCompactNumberField(
    TextEditingController controller,
    String title,
    Color iconColor, {
    String? helperText,
  }) {
    return GestureDetector(
      onTap: () => _showCompactNumberPad(controller, title),
      child: SizedBox(
        height: 60, // Fixed height to prevent overflow
        child: TextFormField(
          controller: controller,
          enabled: false, // Prevent keyboard, use custom numpad
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 1.5, color: Colors.grey.shade300),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: Icon(Icons.touch_app, color: iconColor, size: 20),
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(FurnitureItem item) {
    final isSelected = _selectedItem?.id == item.id;

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _selectItem(item),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Item image
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CrossPlatformImage(
                      imageUrl: item.imageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Item name
              Expanded(
                flex: 1,
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryBlue : null,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Estimated time
              Text(
                'Est. time: ${item.estimatedTimeInMinutes} min',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectItem(FurnitureItem item) async {
    String? recordId;

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Check if this is a resumable (on hold) item
      if (_onHoldItemIds.contains(item.id) &&
          _resumableItemRecordIds.containsKey(item.id)) {
        // Resume existing production record
        recordId = _resumableItemRecordIds[item.id]!;

        // Update the production record status to "in progress"
        await mesService.resumeProductionRecord(recordId);

        print('✅ RESUMING PRODUCTION RECORD: $recordId for item: ${item.name}');
      } else {
        // Create a new production record for the selected item
        final record = await mesService.startProductionRecord(
          item.id,
          _user.id,
          _user.name,
        );
        recordId = record.id;

        print('✅ NEW PRODUCTION RECORD: $recordId for item: ${item.name}');
      }
    } catch (e) {
      print('Warning: Could not create/resume production record: $e');
      // Continue with a temporary ID - the important thing is to start the setup
      recordId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }

    setState(() {
      _selectedItem = item;
      _recordId = recordId;
      _secondsRemaining = item.estimatedTimeInMinutes * 60;
      _timer
          .resetForNewItemInDay(); // Reset timer for new item but preserve day totals
      _setupCompleted = false; // Reset setup status
      _qtyPerCycle = 0; // Reset qty per cycle for new item

      // Auto-select Setup action when item is selected
      if (_interruptionTypes.isNotEmpty) {
        _selectedAction = _interruptionTypes.firstWhere(
          (type) => type.name.toLowerCase().contains('setup'),
          orElse: () => _interruptionTypes.first,
        );
      }

      // Start the selected action immediately
      if (_selectedAction != null) {
        _timer.startAction(_selectedAction!);

        // If this is a setup action, also put timer in setup mode
        if (_selectedAction!.name.toLowerCase().contains('setup')) {
          _timer.startSetup();
          print('✅ SETUP MODE STARTED: ${_selectedAction!.name}');
        } else {
          print('✅ ACTION STARTED: ${_selectedAction!.name}');
        }
      } else {
        print('❌ NO SETUP ACTION AVAILABLE');
      }
    });

    // Close the dialog - be specific about just closing the dialog
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: false).pop();
    }

    // Show confirmation
    final isResuming = _onHoldItemIds.contains(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isResuming
            ? 'Resumed: ${item.name} - Previous work continued!'
            : 'Selected: ${item.name} - Setup Started!'),
        backgroundColor:
            isResuming ? AppColors.purpleAccent : AppColors.primaryBlue,
        duration: const Duration(seconds: 3),
      ),
    );

    print('🎯 ITEM SELECTED: ${item.name}');
    print('🚀 SETUP ACTION: ${_selectedAction?.name ?? "NONE"}');
    print('⏱️ TIMER STATUS: ${_timer.mode}');
  }

  // Load resumable (on hold) items for the current user and process
  Future<void> _loadResumableItems(
      MESService mesService, List<dynamic> processItems) async {
    try {
      // Get on hold items for this user
      final onHoldMESItems = await mesService.getOnHoldItemsForUser(_user.id);

      // Filter by current process
      final processOnHoldItems = onHoldMESItems.where((mesItem) {
        return mesItem.processId == _process!.id;
      }).toList();

      // Clear previous resumable data
      _resumableItemRecordIds.clear();
      _onHoldItemIds.clear();

      // Process each on hold item
      for (final mesItem in processOnHoldItems) {
        // Add to on hold set
        _onHoldItemIds.add(mesItem.id);

        // Find the production record ID for this item
        final records = await mesService.fetchProductionRecords(
          userId: _user.id,
          itemId: mesItem.id,
        );
        final onHoldRecord = records
            .where((r) => r.status == ProductionStatus.onHold)
            .firstOrNull;
        if (onHoldRecord != null) {
          _resumableItemRecordIds[mesItem.id] = onHoldRecord.id;
        }

        // Add to available items if not already present
        final existingItem =
            _availableItems.where((item) => item.id == mesItem.id).firstOrNull;
        if (existingItem == null) {
          _availableItems.add(FurnitureItem(
            id: mesItem.id,
            name: mesItem.name,
            category: mesItem.category ?? 'Uncategorized',
            imageUrl: mesItem.imageUrl,
            estimatedTimeInMinutes: mesItem.estimatedTimeInMinutes,
          ));
        }
      }
    } catch (e) {
      print('Error loading resumable items: $e');
    }
  }

  // Save quantity data only (without restarting timer or changing item)
  Future<void> _saveQuantityDataOnly({
    required int expectedQty,
    required int qtyPerCycle,
    required int finishedQty,
    required int rejectQty,
  }) async {
    try {
      // Update production data fields only
      setState(() {
        _expectedQty = expectedQty;
        _qtyPerCycle = qtyPerCycle;
        _finishedQty = finishedQty;
        _rejectQty = rejectQty;
      });

      // Save to Firebase with current item (no item change)
      if (_selectedItem != null) {
        await _saveProductionDataToFirebase(
          item: _selectedItem!,
          expectedQty: expectedQty,
          qtyPerCycle: qtyPerCycle,
          finishedQty: finishedQty,
          rejectQty: rejectQty,
        );
      }

      print('📊 QUANTITY DATA UPDATED: No timer restart needed');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating production data: $e')),
      );
    }
  }

  // Save item production data and select the item
  Future<void> _saveItemProductionData({
    required FurnitureItem item,
    required int expectedQty,
    required int qtyPerCycle,
    required int finishedQty,
    required int rejectQty,
  }) async {
    try {
      // Update production data fields
      setState(() {
        _expectedQty = expectedQty;
        _qtyPerCycle = qtyPerCycle;
        _finishedQty = finishedQty;
        _rejectQty = rejectQty;
      });

      // Save to Firebase
      await _saveProductionDataToFirebase(
        item: item,
        expectedQty: expectedQty,
        qtyPerCycle: qtyPerCycle,
        finishedQty: finishedQty,
        rejectQty: rejectQty,
      );

      // Select the item (this will create production record)
      await _selectItem(item);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving production data: $e')),
      );
    }
  }

  // Save production data to Firebase using the correct MES service
  Future<void> _saveProductionDataToFirebase({
    required FurnitureItem item,
    required int expectedQty,
    required int qtyPerCycle,
    required int finishedQty,
    required int rejectQty,
  }) async {
    if (_recordId == null) {
      print('❌ No record ID available - cannot save production data');
      return;
    }

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Get the current production record
      final currentRecord = await mesService.getProductionRecord(_recordId!);

      // Update the production record with the new quantities and timing data
      final updatedRecord = currentRecord.copyWith(
        totalProductionTimeSeconds: _timer.getProductionTime(),
        totalInterruptionTimeSeconds: _getNonProductionActionTime(),
        itemCompletionRecords: _timer.completedItems,
      );

      // Save the updated record to the correct mes_production_records collection
      await mesService.updateProductionRecord(updatedRecord);

      print('🔥 Production data saved to mes_production_records: ${updatedRecord.id}');
      print('  📊 Production Time: ${_timer.getProductionTime()}s');
      print('  📊 Interruption Time: ${_getNonProductionActionTime()}s');
      print('  📊 Completed Items: ${_timer.completedItems.length}');
      print('  🗄️ FULL RECORD DATA:');
      print('    - Record ID: ${updatedRecord.id}');
      print('    - Item ID: ${updatedRecord.itemId}');
      print('    - User ID: ${updatedRecord.userId}');
      print('    - User Name: ${updatedRecord.userName}');
      print('    - Start Time: ${updatedRecord.startTime}');
      print('    - End Time: ${updatedRecord.endTime}');
      print('    - Total Production Time: ${updatedRecord.totalProductionTimeSeconds}s');
      print('    - Total Interruption Time: ${updatedRecord.totalInterruptionTimeSeconds}s');
      print('    - Is Completed: ${updatedRecord.isCompleted}');
      print('    - Status: ${updatedRecord.status}');
      print('    - Created At: ${updatedRecord.createdAt}');
      print('    - Updated At: ${updatedRecord.updatedAt}');
      print('    - Interruptions Count: ${updatedRecord.interruptions.length}');
      print('    - Item Completion Records: ${updatedRecord.itemCompletionRecords.length}');
    } catch (e) {
      print('❌ Error saving production data to MES records: $e');
      // Don't rethrow to avoid breaking the user workflow
    }
  }

  // Setup dialog removed - actions now switch immediately without popups

  // Record action start in Firebase
  Future<void> _recordActionStart(MESInterruptionType action) async {
    try {
      print('🔥 Recording action START: ${action.name} (ID: ${action.id})');
      
      // Skip recording if no production record exists (when no item is selected)
      if (_recordId == null) {
        print('⚠️ No production record available - skipping action recording for: ${action.name}');
        return;
      }
      
      final mesService = Provider.of<MESService>(context, listen: false);

      // Add interruption record to track this action
      final result = await mesService.addInterruptionToRecord(
        _recordId!,
        action.id,
        action.name,
        DateTime.now(),
        endTime: null, // Will be filled when action ends
        durationSeconds: 0, // Will be updated when action ends
      );
      print('🔥 Action START recorded successfully for: ${action.name}');
    } catch (e) {
      print('❌ Error recording action start: $e');
      // Don't show error to user, just log it
    }
  }

  // Record action end in Firebase
  Future<void> _recordActionEnd(MESInterruptionType action) async {
    try {
      print('🔥 _recordActionEnd called for: ${action.name}');
      print('   - Record ID: $_recordId');
      print('   - Current Action: ${_timer.currentAction?.name ?? "NONE"}');
      print('   - Action Start Time: ${_timer.actionStartTime}');
      
      // Check if we have a valid record ID
      if (_recordId == null) {
        print('❌ No record ID available - cannot save action end');
        return;
      }
      
      // Calculate action duration BEFORE stopping the action
      final now = DateTime.now();
      int actionDuration = 0;
      
      if (_timer.currentAction != null && _timer.currentAction!.id == action.id) {
        // Calculate duration from action start time to now
        if (_timer.actionStartTime != null) {
          actionDuration = now.difference(_timer.actionStartTime!).inSeconds;
        }
      }
      
      print('🔥 Recording action END: ${action.name} (Duration: ${actionDuration}s)');
      final mesService = Provider.of<MESService>(context, listen: false);

      // Update the most recent interruption record for this action type
      final result = await mesService.updateInterruptionInRecord(
        _recordId!,
        action.id,
        endTime: now,
        durationSeconds: actionDuration,
      );
      print(
          '🔥 Action END recorded successfully for: ${action.name} (${actionDuration}s)');
    } catch (e) {
      print('❌ Error recording action end: $e');
      // Don't show error to user, just log it
    }
  }

  // Record setup start as an interruption
  Future<void> _recordSetupStart() async {
    try {
      print('🔧 Recording setup start');
      final mesService = Provider.of<MESService>(context, listen: false);

      // Add interruption record to track setup
      await mesService.addInterruptionToRecord(
        _recordId!,
        'setup', // Special ID for setup
        'Setup',
        DateTime.now(),
        endTime: null, // Will be filled when setup completes
        durationSeconds: 0, // Will be updated when setup completes
      );
      print('🔧 Setup start recorded successfully');
    } catch (e) {
      print('❌ Error recording setup start: $e');
      // Don't show error to user, just log it
    }
  }

  // Record setup completion as an interruption
  Future<void> _recordSetupCompletion() async {
    try {
      final setupDuration = _timer.getSetupTime();
      if (setupDuration > 0) {
        print('🔧 Recording setup completion: ${setupDuration}s');
        final mesService = Provider.of<MESService>(context, listen: false);
        final now = DateTime.now();

        // Update the existing setup interruption record with end time and duration
        await mesService.updateInterruptionInRecord(
          _recordId!,
          'setup', // Special ID for setup
          endTime: now,
          durationSeconds: setupDuration,
        );
        print('🔧 Setup completion recorded successfully: ${setupDuration}s');
      }
    } catch (e) {
      print('❌ Error recording setup completion: $e');
      // Don't show error to user, just log it
    }
  }

  // Stop current action and return to production
  void _stopAction() {
    if (_timer.currentAction != null) {
      final actionName = _timer.currentAction!.name;
      final currentAction = _timer.currentAction!;

      // Record the end of this action in Firebase
      _recordActionEnd(currentAction);

      setState(() {
        _timer.stopAction();
      });

      // Action stopped - no feedback message needed
    }
  }

  // Start an interruption (generic handler) - kept for compatibility
  Future<void> _startInterruption(MESInterruptionType type) async {
    // Show interruption timer popup
    _showInterruptionTimerDialog(type);
  }

  // Show an interruption timer popup
  void _showInterruptionTimerDialog(MESInterruptionType type) {
    // Local variables for timer
    DateTime startTime = DateTime.now();
    int elapsedSeconds = 0;
    Timer? timer;

    // Determine color based on interruption type
    Color dialogColor = const Color(0xFF2C2C2C);
    IconData icon = Icons.pause_circle;

    if (type.name.toLowerCase().contains('break')) {
      icon = Icons.coffee;
      dialogColor = const Color(0xFF795548); // Brown
    } else if (type.name.toLowerCase().contains('maintenance')) {
      icon = Icons.build;
      dialogColor = const Color(0xFFFF9800); // Orange
    } else if (type.name.toLowerCase().contains('prep')) {
      icon = Icons.assignment;
      dialogColor = const Color(0xFF2196F3); // Blue
    } else if (type.name.toLowerCase().contains('material')) {
      icon = Icons.inventory;
      dialogColor = const Color(0xFF4CAF50); // Green
    } else if (type.name.toLowerCase().contains('training')) {
      icon = Icons.school;
      dialogColor = const Color(0xFF9C27B0); // Purple
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Format time
            String formattedTime =
                ProductionTimer.formatDuration(elapsedSeconds);

            // Start timer only once when dialog is shown
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
                elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
                setStateDialog(() {});
              });

            return Material(
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: dialogColor,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (type.description != null &&
                                      type.description!.isNotEmpty)
                                    Text(
                                      type.description!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                // Cancel timer
                                timer?.cancel();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Main content
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "TIME ELAPSED",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: dialogColor,
                                ),
                              ),
                              SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.015),
                              // Display timer with larger digits and no background
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 104, // Increased by 30% from 80
                                  fontWeight: FontWeight.bold,
                                  color: dialogColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                "Recording ${type.name}",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: dialogColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "This time will be added to today's no value added time",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: dialogColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  // Stop timer
                                  timer?.cancel();

                                  try {
                                    final mesService = Provider.of<MESService>(
                                        context,
                                        listen: false);
                                    final endTime = DateTime.now();

                                    // Close the dialog immediately
                                    Navigator.of(context).pop();

                                    // Then record the interruption in Firebase
                                    await mesService.addInterruptionToRecord(
                                      _recordId!,
                                      type.id,
                                      type.name,
                                      startTime,
                                      endTime: endTime,
                                      durationSeconds: elapsedSeconds,
                                    );

                                    // Calculate and update daily non-productive time
                                    await _updateDailyNonProductiveTime(
                                        mesService, elapsedSeconds);

                                    // Show success message
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${type.name} time recorded: $formattedTime'),
                                          backgroundColor: dialogColor,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Dialog is already closed at this point
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error recording interruption: $e')),
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  'DONE',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  timer?.cancel();
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Update the daily total non-productive time
  Future<void> _updateDailyNonProductiveTime(
      MESService mesService, int additionalSeconds) async {
    try {
      // Get today's date (without time)
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      // Get all records for today for this user
      final records = await mesService.fetchProductionRecords(
        userId: _user.id,
        startDate: today,
        endDate: today,
      );

      // Sum up all interruption times for today
      int totalNonProductiveSeconds = 0;
      for (var record in records) {
        totalNonProductiveSeconds += record.totalInterruptionTimeSeconds;
      }

      // Include the newly added seconds in case it's not yet reflected in the records
      totalNonProductiveSeconds += additionalSeconds;

      // Update the state
      setState(() {
        _dailyNonProductiveSeconds = totalNonProductiveSeconds;
      });

      // Format for display
      final formattedTotal =
          ProductionTimer.formatDuration(totalNonProductiveSeconds);

      // Show total non-productive time for today
      if (mounted) {
        // Delay slightly to show after the first snackbar
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Total non-productive time today: $formattedTotal'),
                backgroundColor: Colors.indigo,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }

      // For debugging
      print('Total non-productive time today: $formattedTotal');
    } catch (e) {
      print('Error updating daily non-productive time: $e');
    }
  }

  // Complete current item and move to next (Next button functionality)
  void _nextItem() async {
    // If production hasn't started yet, start it first
    if (_timer.mode == ProductionTimerMode.notStarted) {
      _startTimer();
      return;
    }

    setState(() {
      _timer.completeCurrentItem();
      // Reset cycle timer for next item
      _timer.resetCycleTimer();
      // Increment qty per cycle by 1 each time Next is pressed
      _qtyPerCycle += 1;
      // Increment item completed count by 1
      _selectedItem!.completedCount += 1;
      // Finished QTY remains manual entry only - not auto-incremented
    });

    // Save the updated item completion records to the database
    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecordWithActions(_recordId!).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
              ),
            ),
      );
    } catch (e) {
      // Silent error - we'll try again later
      print('Error saving item completion: $e');
    }

    // Item completed - no feedback message needed
  }

  // Periodically save production data to Firebase (call this regularly)
  Future<void> _saveProductionProgress() async {
    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
              ),
            ),
      );
    } catch (e) {
      print('Error saving production progress: $e');
      // Don't show error to user
    }
  }

  // Finish production with confirmation dialog
  void _finishProduction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Production'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to finish this production session?'),
            const SizedBox(height: 16),
            if (_timer.completedCount > 0) ...[
              Text('Items completed: ${_timer.completedCount}'),
              const SizedBox(height: 8),
              Text(
                'Average time per item: ${ProductionTimer.formatDuration(_timer.getAverageItemTime().isFinite ? _timer.getAverageItemTime().round() : 0)}',
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Total production time: ${ProductionTimer.formatDuration(_timer.getProductionTime())}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _completeProductionSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  // Complete the production session and navigate back
  Future<void> _completeProductionSession() async {
    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Record end of current action if any before finishing
      if (_timer.currentAction != null) {
        await _recordActionEnd(_timer.currentAction!);
      }

      // Stop all timers and save final state
      _timer.endShift();

      // Update the production record with final state
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
                isCompleted: true,
              ),
            ),
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Production session completed! ${_timer.completedCount} items finished.',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.greenAccent,
          ),
        );

        // Navigate back to item selection after a brief delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/item_selection',
              arguments: _user,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finishing production: $e')),
        );
      }
    }
  }

  // Complete current item (original complete functionality)
  Future<void> _completeItem() async {
    setState(() {
      _timer.completeItem();
      _selectedItem!.completedCount++;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Update the production record with final item completion records
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
                isCompleted: true,
              ),
            ),
      );

      // Show a confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item completed successfully!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Go back to item selection
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/item_selection',
          arguments: _user,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing item: $e')),
      );
    }
  }

  // Show SOP help dialog
  void _requestHelp() {
    _showSOPListDialog();
  }

  // Show SOP list popup
  void _showSOPListDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Standard Operating Procedures',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),

              // SOP List
              Expanded(
                child: Consumer<SOPService>(
                  builder: (context, sopService, child) {
                    if (sopService.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (sopService.sops.isEmpty) {
                      return const Center(
                        child: Text('No SOPs available'),
                      );
                    }

                    return ListView.builder(
                      itemCount: sopService.sops.length,
                      itemBuilder: (context, index) {
                        final sop = sopService.sops[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.description),
                            title: Text(sop.title),
                            subtitle: Text(sop.description),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.pop(context); // Close SOP list
                              _showSOPViewerDialog(sop); // Show SOP viewer
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show SOP viewer popup
  void _showSOPViewerDialog(SOP sop) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Header with back and close buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context); // Close viewer
                        _showSOPListDialog(); // Show list again
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        sop.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // SOP Viewer Content
              Expanded(
                child: SOPViewer(
                  sop: sop,
                  showFullDetails: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle end shift process
  Future<void> _endShift() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Ending shift and saving data...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Record end of current action if any
      if (_timer.currentAction != null) {
        await _recordActionEnd(_timer.currentAction!);
      }

      // End the shift in the timer
      _timer.endShift();

      final mesService = Provider.of<MESService>(context, listen: false);

      // Update the current production record with final data including all item completion records
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _getNonProductionActionTime(),
                itemCompletionRecords: _timer.completedItems,
                isCompleted: false, // Mark as incomplete since shift ended
              ),
            ),
      );

      // Show shift summary
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        await _showShiftSummary();
      }

      // Navigate back to login screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending shift: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Show exit confirmation dialog when user tries to go home
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Exit Timer?'),
          ],
        ),
        content: Text(
          'Are you sure you want to exit the timer?\n\n'
          'Current timer activity will be stopped and recorded. '
          'Any unsaved production data will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _exitToHome();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit Timer'),
          ),
        ],
      ),
    );
  }

  // Properly stop timer and navigate to home
  Future<void> _exitToHome() async {
    try {
      print('🏠 EXITING TIMER: Stopping timer and saving data...');
      
      // Record end of current action if any
      if (_timer.currentAction != null) {
        await _recordActionEnd(_timer.currentAction!);
      }

      // Save any pending production data
      if (_recordId != null) {
        await _saveProductionProgress();
      }

      // Stop the timer completely (no fallback to Idle)
      _timer.stopAction();
      _timer.endShift(); // Stop the entire timer system

      // Cancel any periodic saving
      _saveProgressTimer?.cancel();
      _saveProgressTimer = null;

      print('✅ TIMER STOPPED: Data saved, navigating to home');

      // Navigate back to process selection screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/process_selection',
            arguments: _user);
      }
    } catch (e) {
      print('❌ Error during exit: $e');
      // Still navigate back even if there was an error
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/process_selection',
            arguments: _user);
      }
    }
  }

  // Show shift summary dialog
  Future<void> _showShiftSummary() async {
    final totalTime =
        _timer.getProductionTime() + _getNonProductionActionTime();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assignment_turned_in, color: AppColors.greenAccent),
            const SizedBox(width: 8),
            const Text('Shift Complete'),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Great work, ${_user.name}!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                        'Items Completed', '${_timer.completedCount}'),
                    _buildSummaryRow(
                        'Production Time',
                        ProductionTimer.formatDuration(
                            _timer.getProductionTime())),
                    _buildSummaryRow('Total Shift Time',
                        ProductionTimer.formatDuration(totalTime)),
                    _buildSummaryRow('Current Item',
                        _selectedItem?.name ?? 'No Item Selected'),
                    if (_timer.currentAction != null)
                      _buildSummaryRow(
                          'Last Action', _timer.currentAction!.name),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your data has been saved successfully. Thank you for your hard work today!',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.greenAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 40),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper method to build summary rows
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Show end shift confirmation dialog
  void _showEndShiftDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            const Text('End Shift'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to end your shift?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text('This will:'),
            const SizedBox(height: 8),
            const Text('• Stop all timers'),
            const Text('• Save your production data'),
            const Text('• Generate shift summary'),
            const Text('• Return to login screen'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Shift Summary:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Items Completed: ${_timer.completedCount}'),
                  Text(
                      'Production Time: ${ProductionTimer.formatDuration(_timer.getProductionTime())}'),
                  Text(
                      'Current Item: ${_selectedItem?.name ?? 'No Item Selected'}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _endShift();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get screen dimensions to make more responsive calculations
    final screenSize = MediaQuery.of(context).size;
    final isNarrow = screenSize.width < 900;

    // Calculate appropriate height constraints based on screen size
    // This will help prevent overflow on smaller screens
    final double maxHeaderHeight = isNarrow ? 45 : 55;
    final double maxStatHeight = isNarrow ? 100 : 130;
    final double buttonHeight = isNarrow ? 80 : 100; // Increased button size

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false, // Remove back button since we use replacement navigation
        title: Text(_selectedItem != null
            ? 'Building: ${_selectedItem!.name}'
            : 'Process: ${_process?.name ?? 'Unknown'} - Select Item'),
        backgroundColor: _timer.mode == ProductionTimerMode.running
            ? _timer.getActionColor() // Use action color when running
            : _timer.mode == ProductionTimerMode.setup
                ? _timer.getActionColor() // Use action color for setup too
                : _timer.mode == ProductionTimerMode.interrupted
                    ? AppColors.orangeAccent // Orange for non-productive
                    : AppColors.primaryBlue, // Default blue theme
        foregroundColor: Colors.white,
        actions: [
          // Home button
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              _showExitConfirmationDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Request Help',
            onPressed: _requestHelp,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'End Shift',
            onPressed: () {
              _showEndShiftDialog();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 4.0 : 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left panel - Item info and completed count
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 8.0 : 12.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Select Item Button at top
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showItemSelectionDialog,
                              icon: Icon(Icons.inventory_2),
                              label: Text(
                                'Item',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 21),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isNarrow ? 12 : 16),

                          // Item information card
                          Container(
                            padding: EdgeInsets.all(isNarrow ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedItem?.name ?? 'No Item Selected',
                                  style: TextStyle(
                                    fontSize: isNarrow ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isNarrow ? 8 : 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedItem?.category ??
                                            'No Category',
                                        style: TextStyle(
                                          fontSize: isNarrow ? 12 : 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _selectedItem != null
                                          ? '${_selectedItem!.estimatedTimeInMinutes} min est.'
                                          : 'No time estimate',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 12 : 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isNarrow ? 12 : 16),

                          // Completed items card
                          Container(
                            padding: EdgeInsets.all(isNarrow ? 12 : 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryBlue.withOpacity(0.1),
                                  AppColors.primaryBlue.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: isNarrow ? 20 : 24,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                SizedBox(width: isNarrow ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Completed Items',
                                        style: TextStyle(
                                          fontSize: isNarrow ? 12 : 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '${_timer.completedCount}',
                                        style: TextStyle(
                                          fontSize: isNarrow ? 20 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isNarrow ? 12 : 16),

                          // Session statistics - compact version
                          _buildCompactSessionStatistics(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: isNarrow ? 8 : 12),

              // Center panel - Timer and main controls
              Expanded(
                flex: 4,
                child: Card(
                  elevation: 4,
                  color: _timer.mode == ProductionTimerMode.running
                      ? _timer.getActionColor().withOpacity(
                          0.4) // More prominent tint of action color when running
                      : _timer.mode == ProductionTimerMode.setup
                          ? _timer.getActionColor().withOpacity(
                              0.4) // More prominent tint for setup too
                          : _timer.mode == ProductionTimerMode.interrupted
                              ? AppColors.orangeAccent.withOpacity(
                                  0.4) // More prominent orange for interrupted
                              : Colors.white, // Pure white by default
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                    child: Column(
                      children: [
                        // Timer display - expanded to fill more space
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(height: 10), // Reduced top padding

                                  // Clock - Vertical layout
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Timer indicator moved to top with increased height
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isNarrow ? 8 : 12,
                                          vertical: isNarrow
                                              ? 16
                                              : 20, // Increased by 30%
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor()
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getStatusColor()
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _timer.mode ==
                                                      ProductionTimerMode.setup
                                                  ? Icons.build
                                                  : Icons.timer,
                                              color: _getStatusColor(),
                                              size: isNarrow
                                                  ? 26
                                                  : 31, // Increased by 30%
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _timer.currentAction != null
                                                  ? _timer.currentAction!.name
                                                      .toUpperCase()
                                                  : _timer.mode ==
                                                          ProductionTimerMode
                                                              .setup
                                                      ? 'SETUP'
                                                      : 'PRODUCTION',
                                              style: TextStyle(
                                                fontSize: isNarrow
                                                    ? 23
                                                    : 26, // Increased by 30%
                                                fontWeight: FontWeight.bold,
                                                color: _getContrastingTextColor(
                                                    _getStatusColor()),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (_timer.completedCount > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${_timer.completedCount} items',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Dual Timer Display
                                      Column(
                                        children: [
                                          // Dual timer display only for debugging/management (never show for normal production)
                                          if (false) ...[
                                            // Action Timer
                                            Column(
                                              children: [
                                                Text(
                                                  _timer.currentAction != null
                                                      ? '${_timer.currentAction!.name.toUpperCase()} TIMER'
                                                      : 'ACTION TIMER',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isNarrow ? 14 : 16,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        _timer.getActionColor(),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  width: double.infinity,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isNarrow ? 8 : 12,
                                                    vertical: isNarrow ? 8 : 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _timer.getActionColor(),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: FittedBox(
                                                    child: Text(
                                                      ProductionTimer
                                                          .formatDuration(_timer
                                                              .getActionTime()),
                                                      style: TextStyle(
                                                        fontSize:
                                                            isNarrow ? 32 : 40,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                        color: Colors.white,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            // Item Timer
                                            Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      _timer.isItemTimerRunning
                                                          ? Icons
                                                              .play_circle_filled
                                                          : Icons
                                                              .pause_circle_filled,
                                                      color: _timer
                                                              .isItemTimerRunning
                                                          ? const Color(
                                                              0xFF4CAF50)
                                                          : Colors.orange,
                                                      size: isNarrow ? 16 : 18,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'ITEM TIMER',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isNarrow ? 14 : 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _timer
                                                                .isItemTimerRunning
                                                            ? const Color(
                                                                0xFF4CAF50)
                                                            : Colors.orange,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _timer.isItemTimerRunning
                                                          ? '(Running)'
                                                          : '(Paused)',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isNarrow ? 10 : 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: _timer
                                                                .isItemTimerRunning
                                                            ? const Color(
                                                                0xFF4CAF50)
                                                            : Colors.orange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  width: double.infinity,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isNarrow ? 8 : 12,
                                                    vertical:
                                                        isNarrow ? 12 : 16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _timer
                                                            .isItemTimerRunning
                                                        ? const Color(
                                                            0xFF4CAF50)
                                                        : Colors.orange,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: FittedBox(
                                                    child: Text(
                                                      ProductionTimer
                                                          .formatDuration(_timer
                                                              .getCurrentItemTimerTime()),
                                                      style: TextStyle(
                                                        fontSize:
                                                            isNarrow ? 48 : 64,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                        color: Colors.white,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            // Single timer (for both setup and production)
                                            Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isNarrow ? 8 : 12,
                                                vertical: isNarrow ? 12 : 16,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: FittedBox(
                                                child: Text(
                                                  ProductionTimer.formatDuration(_timer
                                                              .currentAction !=
                                                          null
                                                      ? _timer.getActionTime()
                                                      : _timer.mode ==
                                                              ProductionTimerMode
                                                                  .setup
                                                          ? _timer
                                                              .getSetupTime()
                                                          : _timer
                                                              .getActionTime()),
                                                  style: TextStyle(
                                                    fontSize:
                                                        isNarrow ? 48 : 64,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    color:
                                                        _getContrastingTextColor(
                                                            _getStatusColor()),
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],

                                          // Cycle time display below timer (same size and color as previous status text)
                                          const SizedBox(height: 12),
                                          Text(
                                            'Cycle Time: ${ProductionTimer.formatDuration(_timer.getCycleTime())}',
                                            style: TextStyle(
                                              fontSize: isNarrow
                                                  ? 27
                                                  : 36, // Same size as previous status text
                                              fontWeight: FontWeight.bold,
                                              color: _getContrastingTextColor(
                                                  _getStatusColor()),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),

                                                                    // Removed duplicate item counter - already shown at top


                                          
                                          // Cycle time statistics
                                          if (_timer.completedCycleTimes.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isNarrow ? 8 : 12,
                                                vertical: isNarrow ? 6 : 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getContrastingTextColor(_getStatusColor())
                                                    .withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _getContrastingTextColor(_getStatusColor())
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                          Text(
                                                    'Cycle Time Stats (${_timer.completedCycleTimes.length} cycles)',
                                            style: TextStyle(
                                                      fontSize: isNarrow ? 13 : 16,
                                                      color: _getContrastingTextColor(_getStatusColor())
                                                          .withOpacity(0.7),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                                  SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                    children: [
                                                      _buildCycleTimeStat(
                                                        'Min', 
                                                        ProductionTimer.formatDuration(_timer.getMinCycleTime()),
                                                        isNarrow,
                                                      ),
                                                      _buildCycleTimeStat(
                                                        'Avg', 
                                                        ProductionTimer.formatDuration(_timer.getAverageCycleTime().round()),
                                                        isNarrow,
                                                      ),
                                                      _buildCycleTimeStat(
                                                        'Max', 
                                                        ProductionTimer.formatDuration(_timer.getMaxCycleTime()),
                                                        isNarrow,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Divider(height: 4),

                        // Production Button (big green button below timers)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical:
                                  8), // Reduced horizontal padding to make button wider (30% wider button = less padding)
                          child: ElevatedButton(
                            onPressed: _selectedItem != null
                                ? _handleProductionButton
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isInProductionMode
                                  ? Colors.green
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical:
                                      26), // Increased by 30% for easier pressing
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: _isInProductionMode ? 6 : 3,
                            ),
                            child: _isInProductionMode
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'NEXT ITEM',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 24,
                                        color: Colors.white,
                                      ),
                                    ],
                                  )
                                : Text(
                                    'PRODUCTION',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: isNarrow ? 8 : 12),

              // Right panel - Additional controls
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Controls',
                          style: TextStyle(
                            fontSize: isNarrow ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isNarrow ? 4 : 6),
                        Text(
                          'Track time spent on no value added activities',
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isNarrow ? 12 : 16),
                        Expanded(
                          child: ListView(
                            children: _interruptionTypes.isEmpty
                                ? [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          'No interruption types configured',
                                          style: TextStyle(
                                              color: Colors.grey[600]),
                                        ),
                                      ),
                                    )
                                  ]
                                : [
                                    // Standard Actions Section
                                    _buildSectionHeader('Standard', isNarrow),
                                    SizedBox(height: isNarrow ? 4 : 6),

                                    // Standard actions: Setup, Counting, End Job, Shutdown
                                    ..._getStandardActions().map((action) {
                                      if (action['isInterruptionType']) {
                                        return _buildActionButton(
                                            action['type']
                                                as MESInterruptionType,
                                            isNarrow);
                                      } else {
                                        return action['widget'] as Widget;
                                      }
                                    }),

                                    // Add spacing between sections
                                    SizedBox(height: isNarrow ? 12 : 16),

                                    // Other Actions Section
                                    _buildSectionHeader('Other', isNarrow),
                                    SizedBox(height: isNarrow ? 4 : 6),

                                    // Other actions: All remaining interruption types
                                    ..._getOtherActions().map((type) {
                                      return _buildActionButton(type, isNarrow);
                                    }),

                                    // Help button always available
                                    _buildFullWidthButton(
                                      icon: Icons.help_outline,
                                      label: 'Help',
                                      color: AppColors.primaryBlue,
                                      onPressed: _requestHelp,
                                      description:
                                          'Call supervisor for assistance',
                                      isNarrow: isNarrow,
                                      interruptionType: null,
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 20,
              color: AppColors.textDark,
            ),
            SizedBox(width: 8),
        Text(
          'Session Statistics',
          style: TextStyle(
                fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
            child: Column(
              children: [
              // Value Added Block
                Expanded(
                flex: 2,
                child: _buildLargeStatisticCard(
                  'Value Added',
                    _formatTimeForStatistics(_getProductionActionTime()),
                    Colors.green,
                  Icons.trending_up,
                  ),
                ),
              const SizedBox(height: 12),
              // No Value Block
                Expanded(
                flex: 2,
                child: _buildLargeStatisticCard(
                  'No Value',
                    _formatTimeForStatistics(_getNonProductionActionTime()),
                    Colors.red,
                  Icons.pause_circle_outline,
                  ),
                ),
              const SizedBox(height: 12),
              // Total Time Block
                Expanded(
                flex: 2,
                child: _buildLargeStatisticCard(
                  'Total Time',
                    _formatTimeForStatistics(_timer.getTotalTime()),
                    const Color(0xFF1976D2),
                  Icons.access_time,
                  ),
                ),
              ],
            ),
        ),
      ],
    );
  }

    // Compact statistic card for column layout
  Widget _buildLargeStatisticCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      height: 80, // Fixed height to prevent scrolling
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'monospace',
          ),
        ),
      ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isNarrow,
  }) {
    return SizedBox(
      height: isNarrow ? 60 : 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isNarrow ? 6 : 8,
            horizontal: isNarrow ? 6 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isNarrow ? 22 : 26),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: isNarrow ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'chairs':
        return Icons.chair;
      case 'tables':
        return Icons.table_restaurant;
      case 'ottomans':
        return Icons.weekend;
      case 'benches':
        return Icons.deck;
      case 'cutting wood':
        return Icons.carpenter;
      default:
        return Icons.chair_alt;
    }
  }

  // Get icon for action based on interruption type
  IconData _getActionIcon(MESInterruptionType action) {
    final actionName = action.name.toLowerCase();

    if (actionName.contains('break')) {
      return Icons.coffee;
    } else if (actionName.contains('maintenance')) {
      return Icons.build;
    } else if (actionName.contains('prep')) {
      return Icons.assignment;
    } else if (actionName.contains('material')) {
      return Icons.inventory;
    } else if (actionName.contains('training')) {
      return Icons.school;
    } else {
      return Icons.pause_circle;
    }
  }

  // New method for the full-width buttons with descriptions in the right panel
  Widget _buildFullWidthButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onPressed, // Made nullable to support disabled state
    required bool isNarrow,
    MESInterruptionType? interruptionType,
  }) {
    // Check if this action is currently selected
    final bool isSelected = _selectedAction != null &&
        interruptionType != null &&
        _selectedAction!.id == interruptionType.id;

    // Check if button is disabled
    final bool isDisabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: isDisabled ? 0.5 : (isSelected ? 6 : 2),
        margin: EdgeInsets.zero,
        color: isDisabled
            ? Colors.grey.shade100
            : (isSelected ? color.withOpacity(0.1) : null),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDisabled
                ? Colors.grey.shade300
                : (isSelected ? color : color.withOpacity(0.3)),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: isNarrow ? 12 : 16, horizontal: isNarrow ? 10 : 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.grey.shade200
                        : (isSelected
                            ? color.withOpacity(0.3)
                            : color.withOpacity(0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDisabled
                        ? Colors.grey.shade400
                        : (isSelected ? Colors.white : color),
                    size: isNarrow ? 20 : 24,
                  ),
                ),
                SizedBox(width: isNarrow ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: isNarrow ? 14 : 16,
                          fontWeight:
                              isSelected ? FontWeight.w900 : FontWeight.bold,
                          color: isDisabled
                              ? Colors.grey.shade500
                              : (isSelected ? color : color),
                        ),
                      ),
                      SizedBox(height: isNarrow ? 2 : 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isNarrow ? 10 : 12,
                          color: isDisabled
                              ? Colors.grey.shade400
                              : (isSelected
                                  ? color.withOpacity(0.8)
                                  : Colors.grey[600]),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isDisabled
                      ? Icons.block
                      : (isSelected ? Icons.check_circle : Icons.timer),
                  color: isDisabled
                      ? Colors.grey.shade400
                      : (isSelected ? color : color.withOpacity(0.7)),
                  size: isSelected ? 20 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Format remaining time
  String _formatTimeRemaining() {
    final duration = Duration(seconds: _secondsRemaining);
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Add a new method for formatting time in the "00:00:11" format shown in the screenshot
  String _formatTimeForStatistics(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Get time spent only on production actions (Value Added)
  int _getProductionActionTime() {
    // Use the production time directly from timer - this tracks time in production mode
    return _timer.getProductionTime();
  }

  // Get time spent on all non-production actions (No Value)
  int _getNonProductionActionTime() {
    // Non-production time = Total Time - Production Time
    return _timer.getTotalTime() - _timer.getProductionTime();
  }

  Color _getStatusColor() {
    // Check if current action is production (value time = green) or other (non-value time = red)
    if (_timer.currentAction != null) {
      final actionName = _timer.currentAction!.name.toLowerCase();

      // Production actions = green (value time)
      if (actionName.contains('production')) {
        return Colors.green;
      }
      // All other actions = red (non-value time)
      else {
        return Colors.red;
      }
    }

    // Fallback to original timer mode logic for special cases
    switch (_timer.mode) {
      case ProductionTimerMode.setup:
        return Colors.red; // Setup is non-value time
      case ProductionTimerMode.running:
        return Colors.green; // Default running is value time
      case ProductionTimerMode.interrupted:
        return Colors.red; // Interrupted is non-value time
      default:
        return AppColors.textMedium;
    }
  }

  Widget _buildItemImagePlaceholder(bool isNarrow) {
    return Container(
      color: AppColors.backgroundWhite,
      child: Center(
        child: Icon(
          _getIconForCategory(_selectedItem!.category),
          size: isNarrow ? 24 : 30,
          color: AppColors.textMedium,
        ),
      ),
    );
  }

  Widget _buildLargeItemImagePlaceholder() {
    return Container(
      color: AppColors.backgroundWhite,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForCategory(_selectedItem!.category),
              size: 60,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactImagePlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForCategory(_selectedItem!.category),
              size: 40,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'No Image',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSessionStatistics() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: AppColors.textDark,
              ),
              SizedBox(width: 8),
              Text(
                'Session Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Value Added Block
          _buildLargeStatisticCard(
                  'Value Added',
                  _formatTimeForStatistics(_getProductionActionTime()),
                  Colors.green,
                  Icons.trending_up,
                ),
          const SizedBox(height: 8),
          // No Value Block
          _buildLargeStatisticCard(
                  'No Value',
                  _formatTimeForStatistics(_getNonProductionActionTime()),
                  Colors.red,
                  Icons.pause_circle_outline,
          ),
          const SizedBox(height: 8),
          // Total Time Block
          _buildLargeStatisticCard(
            'Total Time',
            _formatTimeForStatistics(_timer.getTotalTime()),
            const Color(0xFF1976D2),
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildNoItemSelectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2,
              size: 120,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Item Selected',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Process: ${_process?.name ?? 'Unknown'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please select an item to start production timing.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _canSelectNewItem() ? _showItemSelectionDialog : null,
              icon: const Icon(Icons.inventory_2),
              label: Text(_canSelectNewItem()
                  ? 'Select Item'
                  : 'Cannot Select: 0 Finished QTY'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canSelectNewItem() ? AppColors.primaryBlue : Colors.grey,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_availableItems.isNotEmpty) ...[
              Text(
                '${_availableItems.length} item${_availableItems.length != 1 ? 's' : ''} available for this process',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'No items configured for this process',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatCard(
      String label, String value, Color color, IconData icon,
      {bool fullWidth = false}) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: fullWidth
          ? Row(
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title, bool isNarrow) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isNarrow ? 4 : 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isNarrow ? 14 : 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  // Helper method to check if current action is Idle
  bool _isCurrentlyInIdleMode() {
    return _selectedAction != null && 
           _selectedAction!.name.toLowerCase().contains('idle');
  }

  // Helper method to build cycle time stat display
  Widget _buildCycleTimeStat(String label, String value, bool isNarrow) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isNarrow ? 10 : 13,
            color: _getContrastingTextColor(_getStatusColor()).withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isNarrow ? 13 : 16,
            color: _getContrastingTextColor(_getStatusColor()),
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // Helper method to get standard actions (Idle, Setup, Counting, End Job, Shutdown)
  List<Map<String, dynamic>> _getStandardActions() {
    List<Map<String, dynamic>> standardActions = [];

    // Idle (always first in standard actions)
    final idleTypes = _interruptionTypes
        .where(
          (type) => type.name.toLowerCase().contains('idle'),
        )
        .toList();
    if (idleTypes.isNotEmpty) {
      standardActions.add({
        'isInterruptionType': true,
        'type': idleTypes.first,
      });
    }

    // Setup
    final setupTypes = _interruptionTypes
        .where(
          (type) => type.name.toLowerCase().contains('setup'),
        )
        .toList();
    if (setupTypes.isNotEmpty) {
      standardActions.add({
        'isInterruptionType': true,
        'type': setupTypes.first,
      });
    }

    // Counting
    final countingTypes = _interruptionTypes
        .where(
          (type) => type.name.toLowerCase().contains('counting'),
        )
        .toList();
    if (countingTypes.isNotEmpty) {
      standardActions.add({
        'isInterruptionType': true,
        'type': countingTypes.first,
      });
    }

    // End Job (hardcoded button)
    standardActions.add({
      'isInterruptionType': false,
      'widget': Column(
        children: [
          _buildFullWidthButton(
            icon: Icons.stop_circle,
            label: 'End Job',
            color: Colors.red.shade600,
            onPressed: _selectedItem != null && !_isCurrentlyInIdleMode() ? _handleEndJobAction : null,
            description: _selectedItem != null
                ? (_isCurrentlyInIdleMode()
                    ? 'Only Shutdown is available in Idle mode'
                    : 'Complete current job and count items')
                : 'Please select an item first',
            isNarrow: MediaQuery.of(context).size.width < 1200,
            interruptionType: null,
          ),
          SizedBox(height: MediaQuery.of(context).size.width < 1200 ? 6 : 8),
        ],
      ),
    });

    // Shutdown
    final shutdownTypes = _interruptionTypes
        .where(
          (type) => type.name.toLowerCase().contains('shutdown'),
        )
        .toList();
    if (shutdownTypes.isNotEmpty) {
      standardActions.add({
        'isInterruptionType': true,
        'type': shutdownTypes.first,
      });
    }

    return standardActions;
  }

  // Helper method to get other actions (all remaining interruption types)
  List<MESInterruptionType> _getOtherActions() {
    // Get list of standard action names
    final standardNames = ['idle', 'setup', 'counting', 'shutdown'];

    // Return interruption types that are not in the standard list
    return _interruptionTypes.where((type) {
      final typeName = type.name.toLowerCase();
      return !standardNames
          .any((standardName) => typeName.contains(standardName));
    }).toList();
  }

  // Helper method to check if an action is a standard action
  bool _isStandardAction(MESInterruptionType type) {
    final standardNames = ['idle', 'setup', 'counting', 'shutdown'];
    final typeName = type.name.toLowerCase();
    return standardNames.any((standardName) => typeName.contains(standardName));
  }

  // Helper method to build action buttons with consistent styling
  Widget _buildActionButton(MESInterruptionType type, bool isNarrow) {
    // Determine icon based on type name or use default
    IconData icon = Icons.pause_circle;
    Color buttonColor = AppColors.textDark;

    // Use the color from MES setup if available (but override for specific types)
    if (!type.name.toLowerCase().contains('shutdown') && type.color != null && type.color!.isNotEmpty) {
      try {
        String colorHex = type.color!.replaceAll('#', '');
        if (colorHex.length == 6) {
          colorHex = 'FF$colorHex'; // Add alpha channel
        }
        buttonColor = Color(int.parse(colorHex, radix: 16));
      } catch (e) {
        // Fall back to name-based colors if parsing fails
        buttonColor = AppColors.textDark;
      }
    }

    // Determine icon based on type name
    if (type.name.toLowerCase().contains('idle')) {
      icon = Icons.hourglass_empty;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = Colors.red.shade600;
      }
    } else if (type.name.toLowerCase().contains('break')) {
      icon = Icons.coffee;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.orangeAccent;
      }
    } else if (type.name.toLowerCase().contains('maintenance')) {
      icon = Icons.build;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.orangeAccent;
      }
    } else if (type.name.toLowerCase().contains('prep')) {
      icon = Icons.assignment;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.blueAccent;
      }
    } else if (type.name.toLowerCase().contains('material')) {
      icon = Icons.inventory;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.greenAccent;
      }
    } else if (type.name.toLowerCase().contains('training')) {
      icon = Icons.school;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.purpleAccent;
      }
    } else if (type.name.toLowerCase().contains('hold')) {
      icon = Icons.pause_circle;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.purpleAccent;
      }
    } else if (type.name.toLowerCase().contains('setup')) {
      icon = Icons.build_circle;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.orangeAccent;
      }
    } else if (type.name.toLowerCase().contains('counting')) {
      icon = Icons.inventory_2;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = AppColors.blueAccent;
      }
    } else if (type.name.toLowerCase().contains('shutdown')) {
      icon = Icons.power_settings_new;
      if (type.color == null || type.color!.isEmpty) {
        buttonColor = Colors.deepPurple.shade600;
      }
    }

    return Column(
      children: [
        _buildFullWidthButton(
          icon: icon,
          label: type.name,
          color: buttonColor,
          onPressed: (!_isStandardAction(type) || type.name.toLowerCase().contains('shutdown') || _selectedItem != null) && !(_isCurrentlyInIdleMode() && _isStandardAction(type) && !type.name.toLowerCase().contains('shutdown'))
              ? () {
                  _startAction(type);
                }
              : null, // Allow Other actions and Shutdown without item, disable Standard actions when no item selected or in Idle mode (except Shutdown)
          description: (!_isStandardAction(type) || type.name.toLowerCase().contains('shutdown') || _selectedItem != null)
              ? (_isCurrentlyInIdleMode() && _isStandardAction(type) && !type.name.toLowerCase().contains('shutdown')
                  ? 'Only Shutdown is available in Idle mode'
                  : (type.description ?? 'Track time for ${type.name}'))
              : 'Please select an item first',
          isNarrow: isNarrow,
          interruptionType: type,
        ),
        SizedBox(height: isNarrow ? 6 : 8),
      ],
    );
  }

  // Helper method to determine if a color is light or dark
  bool _isColorLight(Color color) {
    // Calculate relative luminance using the formula: 0.299*R + 0.587*G + 0.114*B
    final luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5; // If luminance > 0.5, it's considered light
  }

  // Helper method to get contrasting text color based on background
  Color _getContrastingTextColor(Color backgroundColor) {
    return _isColorLight(backgroundColor) ? Colors.black : Colors.white;
  }
}
