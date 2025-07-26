import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/furniture_item.dart';
import '../models/production_timer.dart';
import '../models/user.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_interruption_model.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize production timer with onTick callback
    _timer = ProductionTimer(onTick: () {
      if (mounted) {
        setState(() {
          // Update remaining time when timer is running
          if (_timer.mode == ProductionTimerMode.running) {
            // Decrease seconds remaining only if greater than zero
            if (_secondsRemaining > 0) {
              _secondsRemaining--;
            }
          }
        });
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

      // Load interruption types
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.fetchInterruptionTypes(onlyActive: true);
      _interruptionTypes = mesService.interruptionTypes;

      // Load daily non-productive time
      await _loadDailyNonProductiveTime(mesService);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDailyNonProductiveTime(MESService mesService) async {
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
      int totalSeconds = 0;
      for (var record in records) {
        totalSeconds += record.totalInterruptionTimeSeconds;
      }

      setState(() {
        _dailyNonProductiveSeconds = totalSeconds;
      });
    } catch (e) {
      print('Error loading daily non-productive time: $e');
    }
  }

  @override
  void dispose() {
    // Clean up timer resources
    _timer.dispose();
    super.dispose();
  }

  // Start or resume production
  void _startTimer() async {
    setState(() {
      _timer.startProduction();
    });

    // If this is the first time starting, no need to update the record
    if (_timer.productionStartCount == 1) return;

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

  // Pause production
  void _pauseTimer() {
    setState(() {
      _timer.pauseProduction();
    });
  }

  // Start an action (replaces interruption dialog system)
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

    setState(() {
      _timer.startAction(type);
    });

    // Show brief feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started: ${type.name}'),
        duration: const Duration(seconds: 1),
        backgroundColor: _timer.getActionColor(),
      ),
    );
  }

  // Stop current action and return to production
  void _stopAction() {
    if (_timer.currentAction != null) {
      final actionName = _timer.currentAction!.name;
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

      // End the shift in the timer
      _timer.endShift();

      final mesService = Provider.of<MESService>(context, listen: false);

      // Update the current production record with final data
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId).then(
              (record) => record.copyWith(
                endTime: DateTime.now(),
                totalProductionTimeSeconds: _timer.getProductionTime(),
                totalInterruptionTimeSeconds: _timer.getTotalInterruptionTime(),
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
                    padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item info - constrain height
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: maxHeaderHeight),
                          child: Row(
                            children: [
                              // Item image or placeholder
                              Container(
                                width: isNarrow ? 50 : 60,
                                height: isNarrow ? 50 : 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: _selectedItem.imageUrl != null &&
                                          _selectedItem.imageUrl!.isNotEmpty
                                      ? CrossPlatformImage(
                                          imageUrl: _selectedItem.imageUrl!,
                                          width: isNarrow ? 50 : 60,
                                          height: isNarrow ? 50 : 60,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              _buildItemImagePlaceholder(
                                                  isNarrow),
                                        )
                                      : _buildItemImagePlaceholder(isNarrow),
                                ),
                              ),
                              SizedBox(width: isNarrow ? 8 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedItem.name,
                                      style: TextStyle(
                                        fontSize: isNarrow ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: isNarrow ? 2 : 4),
                                    Text(
                                      'Category: ${_selectedItem.category}',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 12 : 13,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                    ),
                                    Text(
                                      'Est. time: ${_selectedItem.estimatedTimeInMinutes} min',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 12 : 13,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 16),

                        // Completed count section - constrained height
                        Container(
                          constraints:
                              BoxConstraints(maxHeight: maxStatHeight * 0.6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: isNarrow ? 20 : 24,
                                color: AppColors.primaryBlue,
                              ),
                              SizedBox(width: isNarrow ? 6 : 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Completed Items',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 12 : 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: isNarrow ? 4 : 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isNarrow ? 12 : 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${_selectedItem.completedCount}',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 18 : 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Stats - constrained height
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxStatHeight),
                          child: SingleChildScrollView(
                            child: _buildSessionStatistics(),
                          ),
                        ),
                      ],
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
                                                Icons.timer,
                                                color: _getStatusColor(),
                                                size: isNarrow ? 20 : 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'ITEM TIMER',
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
                                              vertical: isNarrow ? 8 : 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                FittedBox(
                                                  child: Text(
                                                    ProductionTimer
                                                        .formatDuration(_timer
                                                            .getCurrentItemTime()),
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
                                                if (_timer.completedCount >
                                                    0) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Avg: ${ProductionTimer.formatDuration(_timer.getAverageItemTime().round())}',
                                                    style: TextStyle(
                                                      fontSize:
                                                          isNarrow ? 12 : 14,
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
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
                              // Single Start button (only show if not started)
                              if (_timer.mode == ProductionTimerMode.notStarted)
                                Expanded(
                                  child: _buildControlButton(
                                    icon: Icons.play_arrow,
                                    label: 'Start Production',
                                    color: AppColors.primaryBlue,
                                    onPressed: _startTimer,
                                    isNarrow: isNarrow,
                                  ),
                                ),

                              // Next button (only show if production is running AND no action is selected)
                              if (_timer.mode == ProductionTimerMode.running &&
                                  _timer.currentAction == null)
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Session Statistics',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Value Added:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Text(
                        _formatTimeForStatistics(_timer.getProductionTime()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'No Value Added:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Text(
                        _formatTimeForStatistics(
                            _timer.getTotalInterruptionTime()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Total time:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Text(
                        _formatTimeForStatistics(_timer.getTotalTime()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
}
