import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/furniture_item.dart';
import '../models/production_timer.dart';
import '../models/user.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_interruption_model.dart';
import '../../data/models/mes_process_model.dart';
import '../../presentation/widgets/cross_platform_image.dart';
import '../../core/theme/app_theme.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late FurnitureItem _selectedItem;
  late User _user;
  late String _recordId;
  late ProductionTimer _timer;
  late int _secondsRemaining;
  List<MESInterruptionType> _interruptionTypes = [];
  bool _isLoading = true;
  int _dailyNonProductiveSeconds = 0; // Track daily non-productive time
  Timer? _saveProgressTimer; // Timer for periodic data saving
  MESProcess? _process; // The process associated with this item
  bool _setupCompleted = false; // Track if setup has been completed

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
      // Get the arguments
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _selectedItem = args['item'] as FurnitureItem;
      _user = args['user'] as User;
      _recordId = args['recordId'] as String;

      // Initialize remaining time
      _secondsRemaining = _selectedItem.estimatedTimeInMinutes * 60;

      // Load interruption types (excluding PRODUCTION which is handled by Start Production button)
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.fetchInterruptionTypes(onlyActive: true);
      if (!mounted) return;

      _interruptionTypes = mesService.interruptionTypes
          .where((type) => !type.name.toLowerCase().contains('production'))
          .toList();

      // Load process information to check setup requirements
      await mesService.fetchProcesses(onlyActive: true);
      if (!mounted) return;

      // Find the process for this item (from MESItem.processId via FurnitureItem)
      final mesItems = await mesService.fetchItems(onlyActive: true);
      final mesItem =
          mesItems.firstWhere((item) => item.id == _selectedItem.id);
      _process =
          mesService.processes.firstWhere((p) => p.id == mesItem.processId);

      // Load daily non-productive time
      await _loadDailyNonProductiveTime(mesService);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    // Clean up timer resources
    _timer.dispose();
    _saveProgressTimer?.cancel();
    super.dispose();
  }

  // Start or resume production
  void _startTimer() async {
    // Check if setup is required and not yet completed
    if (_process?.requiresSetup == true && !_setupCompleted) {
      _showSetupDialog();
      return;
    }

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
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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

  // Start/Stop an action (toggle functionality)
  void _startAction(MESInterruptionType type) {
    // Only allow actions when production is running
    if (_timer.mode != ProductionTimerMode.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please start production first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if this action is already active - if so, stop it
    if (_timer.currentAction != null && _timer.currentAction!.id == type.id) {
      _stopAction();
      return;
    }

    // Check if operator is working on an item and prompt for completion
    if (_timer.currentAction == null && _timer.getCurrentItemTime() > 0) {
      _showItemCompletionDialog(type);
      return;
    }

    // Record end of previous action before starting new one
    if (_timer.currentAction != null) {
      _recordActionEnd(_timer.currentAction!);
    }

    // Start the new action
    setState(() {
      _timer.startAction(type);
    });

    // Record the start of this action in Firebase
    _recordActionStart(type);

    // Show brief feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started: ${type.name}'),
        duration: const Duration(seconds: 1),
        backgroundColor: _timer.getActionColor(),
      ),
    );
  }

  // Show setup dialog before starting production
  void _showSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without action
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.build, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 8),
            const Text('Setup Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This process requires setup before production can begin.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Please complete the setup tasks and then click "Complete Setup" to proceed with production.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_timer.mode == ProductionTimerMode.setup)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Setup in progress for:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ProductionTimer.formatDuration(_timer.getSetupTime()),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          if (_timer.mode != ProductionTimerMode.setup)
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _timer.startSetup();
                });

                // Record setup start after starting the timer
                await _recordSetupStart();

                Navigator.of(context).pop();
                // Show the dialog again to track progress
                _showSetupDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Setup'),
            ),
          if (_timer.mode == ProductionTimerMode.setup)
            ElevatedButton(
              onPressed: () async {
                // Record setup time as an interruption before completing
                await _recordSetupCompletion();

                setState(() {
                  _timer.completeSetup();
                  _setupCompleted = true;
                });
                Navigator.of(context).pop();

                // Start periodic saving since this is the first time starting
                _startPeriodicSaving();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete Setup'),
            ),
        ],
      ),
    );
  }

  // Show dialog to confirm item completion before starting action
  void _showItemCompletionDialog(MESInterruptionType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.orangeAccent, size: 24),
            SizedBox(width: 8),
            Text('Item in Progress'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are currently working on an item for:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: Text(
                ProductionTimer.formatDuration(_timer.getCurrentItemTime()),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Would you like to complete this item before starting "${type.name}"?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Start action without completing item
              _startActionWithoutCompletion(type);
            },
            child: Text('Continue Item Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Complete current item first, then start action
              _completeItemAndStartAction(type);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.greenAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Complete Item'),
          ),
        ],
      ),
    );
  }

  // Complete current item and then start the action
  void _completeItemAndStartAction(MESInterruptionType type) {
    // Complete the current item
    _nextItem();

    // Then start the action
    setState(() {
      _timer.startAction(type);
    });

    // Record the start of this action in Firebase
    _recordActionStart(type);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item completed. Started: ${type.name}'),
        duration: const Duration(seconds: 2),
        backgroundColor: _timer.getActionColor(),
      ),
    );
  }

  // Start action without completing current item
  void _startActionWithoutCompletion(MESInterruptionType type) {
    setState(() {
      _timer.startAction(type);
    });

    // Record the start of this action in Firebase
    _recordActionStart(type);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started: ${type.name} (item continues)'),
        duration: const Duration(seconds: 1),
        backgroundColor: _timer.getActionColor(),
      ),
    );
  }

  // Record action start in Firebase
  Future<void> _recordActionStart(MESInterruptionType action) async {
    try {
      print('🔥 Recording action START: ${action.name} (ID: ${action.id})');
      final mesService = Provider.of<MESService>(context, listen: false);

      // Add interruption record to track this action
      final result = await mesService.addInterruptionToRecord(
        _recordId,
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
      print(
          '🔥 Recording action END: ${action.name} (Duration: ${_timer.getActionTime()}s)');
      final mesService = Provider.of<MESService>(context, listen: false);
      final now = DateTime.now();

      // Calculate action duration
      final actionDuration = _timer.getActionTime();

      // Update the most recent interruption record for this action type
      final result = await mesService.updateInterruptionInRecord(
        _recordId,
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
        _recordId,
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
          _recordId,
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

      // Show brief feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stopped: $actionName'),
          duration: const Duration(seconds: 1),
          backgroundColor: _timer.getActionColor(),
        ),
      );
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
            if (timer == null) {
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
                setStateDialog(() {});
              });
            }

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
                              const SizedBox(height: 16),
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
                                      _recordId,
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
      _selectedItem.completedCount++;
    });

    // Save the updated item completion records to the database
    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
                itemCompletionRecords: _timer.completedItems,
              ),
            ),
      );
    } catch (e) {
      // Silent error - we'll try again later
      print('Error saving item completion: $e');
    }

    // Show brief confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Item ${_timer.completedCount} completed! Production continues.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Periodically save production data to Firebase (call this regularly)
  Future<void> _saveProductionProgress() async {
    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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
      _selectedItem.completedCount++;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Update the production record with final item completion records
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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

  // Show help request dialog
  void _requestHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Request'),
        content:
            const Text('Your help request has been sent to the supervisor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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

  // Show shift summary dialog
  Future<void> _showShiftSummary() async {
    final totalTime =
        _timer.getProductionTime() + _timer.getTotalInterruptionTime();

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
                    _buildSummaryRow('Current Item', _selectedItem.name),
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
                  Text('Current Item: ${_selectedItem.name}'),
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
    final double buttonHeight = isNarrow ? 45 : 60;

    return Scaffold(
      appBar: AppBar(
        title: Text('Building: ${_selectedItem.name}'),
        backgroundColor: _timer.mode == ProductionTimerMode.running
            ? _timer.getActionColor() // Use action color when running
            : _timer.mode == ProductionTimerMode.interrupted
                ? AppColors.orangeAccent // Orange for non-productive
                : AppColors.primaryBlue, // Default blue theme
        foregroundColor: Colors.white,
        actions: [
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
                          // Item image - compact but professional
                          Container(
                            height: isNarrow ? 120 : 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1,
                              ),
                              color: Colors.grey[50],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: _selectedItem.imageUrl != null &&
                                      _selectedItem.imageUrl!.isNotEmpty
                                  ? CrossPlatformImage(
                                      imageUrl: _selectedItem.imageUrl!,
                                      width: 300,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        color: Colors.red[100],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error,
                                                  color: Colors.red, size: 30),
                                              Text('Image Error',
                                                  style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 10)),
                                              if (_selectedItem.imageUrl !=
                                                  null)
                                                Text(
                                                  'URL: ${_selectedItem.imageUrl!.length > 20 ? _selectedItem.imageUrl!.substring(0, 20) + '...' : _selectedItem.imageUrl!}',
                                                  style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 8),
                                                  textAlign: TextAlign.center,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.blue[100],
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _getIconForCategory(
                                                  _selectedItem.category),
                                              size: 40,
                                              color: AppColors.textMedium,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'No Image URL',
                                              style: TextStyle(
                                                color: AppColors.textLight,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'URL: ${_selectedItem.imageUrl ?? 'null'}',
                                              style: TextStyle(
                                                color: Colors.blue[700],
                                                fontSize: 8,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
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
                                  _selectedItem.name,
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
                                        _selectedItem.category,
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
                                      '${_selectedItem.estimatedTimeInMinutes} min est.',
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
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                    child: Column(
                      children: [
                        // Timer display - expanded to fill more space
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Status
                                  Text(
                                    _getStatusText(),
                                    style: TextStyle(
                                      fontSize: isNarrow ? 22 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(),
                                    ),
                                  ),
                                  SizedBox(height: isNarrow ? 8 : 12),

                                  // Clock - Vertical layout
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Main Production Timer
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _timer.mode ==
                                                        ProductionTimerMode
                                                            .setup
                                                    ? Icons.build
                                                    : Icons.timer,
                                                color: _getStatusColor(),
                                                size: isNarrow ? 20 : 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _timer.mode ==
                                                        ProductionTimerMode
                                                            .setup
                                                    ? 'SETUP TIMER'
                                                    : 'ITEM TIMER',
                                                style: TextStyle(
                                                  fontSize: isNarrow ? 18 : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (_timer.completedCount > 0)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    '${_timer.completedCount} items',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
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
                                                _timer.mode ==
                                                        ProductionTimerMode
                                                            .setup
                                                    ? ProductionTimer
                                                        .formatDuration(_timer
                                                            .getSetupTime())
                                                    : ProductionTimer
                                                        .formatDuration(_timer
                                                            .getCurrentItemTime()),
                                                style: TextStyle(
                                                  fontSize: isNarrow ? 48 : 64,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                  color: Colors.white,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Average time display moved outside the main timer container
                                          if (_timer.completedCount > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Avg: ${ProductionTimer.formatDuration(_timer.getAverageItemTime().isFinite ? _timer.getAverageItemTime().round() : 0)}',
                                              style: TextStyle(
                                                fontSize: isNarrow ? 12 : 14,
                                                color: _getStatusColor()
                                                    .withOpacity(0.8),
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // Action Timer
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _timer.currentAction != null
                                                    ? _getActionIcon(
                                                        _timer.currentAction!)
                                                    : Icons
                                                        .production_quantity_limits,
                                                color: _timer.getActionColor(),
                                                size: isNarrow ? 20 : 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _timer.currentAction?.name
                                                          .toUpperCase() ??
                                                      'PRODUCTION',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isNarrow ? 18 : 20,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _timer.getActionColor(),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              if (_timer.currentAction != null)
                                                GestureDetector(
                                                  onTap: _stopAction,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isNarrow ? 8 : 12,
                                              vertical: isNarrow ? 12 : 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _timer.getActionColor(),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: FittedBox(
                                              child: Text(
                                                ProductionTimer.formatDuration(
                                                    _timer.getActionTime()),
                                                style: TextStyle(
                                                  fontSize: isNarrow ? 48 : 64,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                  color: Colors.white,
                                                  height: 1.0,
                                                ),
                                              ),
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
                        ),

                        const Divider(height: 4),

                        // Main controls
                        SizedBox(
                          height: buttonHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Start button (only show if not started or in setup)
                              if (_timer.mode == ProductionTimerMode.notStarted)
                                Expanded(
                                  child: _buildControlButton(
                                    icon: Icons.play_arrow,
                                    label: _process?.requiresSetup == true &&
                                            !_setupCompleted
                                        ? 'Start Setup'
                                        : 'Start Production',
                                    color: AppColors.primaryBlue,
                                    onPressed: _startTimer,
                                    isNarrow: isNarrow,
                                  ),
                                ),

                              // Setup button (show when in setup mode)
                              if (_timer.mode == ProductionTimerMode.setup)
                                Expanded(
                                  child: _buildControlButton(
                                    icon: Icons.build,
                                    label: 'Complete Setup',
                                    color: AppColors.greenAccent,
                                    onPressed: () {
                                      setState(() {
                                        _timer.completeSetup();
                                        _setupCompleted = true;
                                      });
                                      // Start periodic saving since this is the first time starting
                                      _startPeriodicSaving();
                                    },
                                    isNarrow: isNarrow,
                                  ),
                                ),

                              // Next button (always show when in running/paused/interrupted modes)
                              if (_timer.mode == ProductionTimerMode.running ||
                                  _timer.mode == ProductionTimerMode.paused ||
                                  _timer.mode ==
                                      ProductionTimerMode.interrupted)
                                Expanded(
                                  child: _buildControlButton(
                                    icon: Icons.arrow_forward,
                                    label: 'Next Item',
                                    color: AppColors.greenAccent,
                                    onPressed: _nextItem,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                            ],
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
                                    // Generate buttons dynamically based on interruption types
                                    ..._interruptionTypes.map((type) {
                                      // Determine icon based on type name or use default
                                      IconData icon = Icons.pause_circle;
                                      Color buttonColor = AppColors.textDark;

                                      // Use the color from MES setup if available
                                      if (type.color != null &&
                                          type.color!.isNotEmpty) {
                                        try {
                                          String colorHex =
                                              type.color!.replaceAll('#', '');
                                          if (colorHex.length == 6) {
                                            colorHex =
                                                'FF$colorHex'; // Add alpha channel
                                          }
                                          buttonColor = Color(
                                              int.parse(colorHex, radix: 16));
                                        } catch (e) {
                                          // Fall back to name-based colors if parsing fails
                                          buttonColor = AppColors.textDark;
                                        }
                                      }

                                      // Determine icon based on type name
                                      if (type.name
                                          .toLowerCase()
                                          .contains('break')) {
                                        icon = Icons.coffee;
                                        // Use MES color or fallback
                                        if (type.color == null ||
                                            type.color!.isEmpty) {
                                          buttonColor = AppColors.orangeAccent;
                                        }
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('maintenance')) {
                                        icon = Icons.build;
                                        if (type.color == null ||
                                            type.color!.isEmpty) {
                                          buttonColor = AppColors.orangeAccent;
                                        }
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('prep')) {
                                        icon = Icons.assignment;
                                        if (type.color == null ||
                                            type.color!.isEmpty) {
                                          buttonColor = AppColors.blueAccent;
                                        }
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('material')) {
                                        icon = Icons.inventory;
                                        if (type.color == null ||
                                            type.color!.isEmpty) {
                                          buttonColor = AppColors.greenAccent;
                                        }
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('training')) {
                                        icon = Icons.school;
                                        if (type.color == null ||
                                            type.color!.isEmpty) {
                                          buttonColor = AppColors.purpleAccent;
                                        }
                                      }

                                      return Column(
                                        children: [
                                          _buildFullWidthButton(
                                            icon: icon,
                                            label: type.name,
                                            color: buttonColor,
                                            onPressed: () {
                                              _startAction(type);
                                            },
                                            description: type.description ??
                                                'Track time for ${type.name}',
                                            isNarrow: isNarrow,
                                            interruptionType: type,
                                          ),
                                          SizedBox(height: isNarrow ? 6 : 8),
                                        ],
                                      );
                                    }).toList(),

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
        Text(
          'Session Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Value Added Row
                Expanded(
                  child: _buildStatisticRow(
                    'Value Added:',
                    _formatTimeForStatistics(_timer.getProductionTime()),
                    Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                // No Value Added Row
                Expanded(
                  child: _buildStatisticRow(
                    'No Value Added:',
                    _formatTimeForStatistics(_timer.getTotalInterruptionTime()),
                    Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                // Total Time Row
                Expanded(
                  child: _buildStatisticRow(
                    'Total time:',
                    _formatTimeForStatistics(_timer.getTotalTime()),
                    const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  String _getStatusText() {
    switch (_timer.mode) {
      case ProductionTimerMode.notStarted:
        return 'Ready to Start';
      case ProductionTimerMode.setup:
        return 'Setup in Progress';
      case ProductionTimerMode.running:
        return 'Production in Progress';
      case ProductionTimerMode.paused:
        return 'Production Paused';
      case ProductionTimerMode.interrupted:
        return 'Production Interrupted';
    }
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
    required VoidCallback onPressed,
    required bool isNarrow,
    MESInterruptionType? interruptionType,
  }) {
    // Check if this action is currently selected
    final bool isSelected = _timer.currentAction != null &&
        interruptionType != null &&
        _timer.currentAction!.id == interruptionType.id;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: isSelected ? 6 : 2,
        margin: EdgeInsets.zero,
        color: isSelected ? color.withOpacity(0.1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? color : color.withOpacity(0.3),
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
                    color: isSelected
                        ? color.withOpacity(0.3)
                        : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : color,
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
                          color: isSelected ? color : color,
                        ),
                      ),
                      SizedBox(height: isNarrow ? 2 : 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isNarrow ? 10 : 12,
                          color: isSelected
                              ? color.withOpacity(0.8)
                              : Colors.grey[600],
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.timer,
                  color: isSelected ? color : color.withOpacity(0.7),
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

  Color _getStatusColor() {
    switch (_timer.mode) {
      case ProductionTimerMode.setup:
        return AppColors.primaryBlue;
      case ProductionTimerMode.running:
        return AppColors.greenAccent;
      case ProductionTimerMode.interrupted:
        return AppColors.orangeAccent;
      default:
        return AppColors.textMedium;
    }
  }

  Widget _buildItemImagePlaceholder(bool isNarrow) {
    return Container(
      color: AppColors.backgroundWhite,
      child: Center(
        child: Icon(
          _getIconForCategory(_selectedItem.category),
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
              _getIconForCategory(_selectedItem.category),
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
              _getIconForCategory(_selectedItem.category),
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
                size: 18,
                color: AppColors.textDark,
              ),
              SizedBox(width: 8),
              Text(
                'Session Statistics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Value Added',
                  _formatTimeForStatistics(_timer.getProductionTime()),
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'No Value',
                  _formatTimeForStatistics(_timer.getTotalInterruptionTime()),
                  Colors.red,
                  Icons.pause_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactStatCard(
            'Total Time',
            _formatTimeForStatistics(_timer.getTotalTime()),
            const Color(0xFF1976D2),
            Icons.schedule,
            fullWidth: true,
          ),
          // Finish button - only show when production is running
          if (_timer.mode != ProductionTimerMode.notStarted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _finishProduction,
                icon: Icon(Icons.stop, size: 16),
                label: Text(
                  'Finish',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
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
}
