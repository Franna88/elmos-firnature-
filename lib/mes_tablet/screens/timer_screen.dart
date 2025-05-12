import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/furniture_item.dart';
import '../models/production_timer.dart';
import '../models/user.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_interruption_model.dart';

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

  // Start an interruption (generic handler)
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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

        return StatefulBuilder(
          builder: (context, setState) {
            // Start timer if not started
            timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              setState(() {
                elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
              });
            });

            // Format time
            String formattedTime =
                ProductionTimer.formatDuration(elapsedSeconds);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: dialogColor, width: 3),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: dialogColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: dialogColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          type.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (type.description != null &&
                            type.description!.isNotEmpty)
                          Text(
                            type.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dialogColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: dialogColor, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "ELAPSED TIME",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: dialogColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Recording ${type.name} Time",
                    style: TextStyle(
                      fontSize: 16,
                      color: dialogColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Cancel timer
                    timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    // End timer
                    timer?.cancel();

                    // Record the interruption in Firebase
                    try {
                      final mesService =
                          Provider.of<MESService>(context, listen: false);
                      final endTime = DateTime.now();

                      await mesService.addInterruptionToRecord(
                        _recordId,
                        type.id,
                        type.name,
                        startTime,
                        endTime: endTime,
                        durationSeconds: elapsedSeconds,
                      );

                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${type.name} time recorded: $formattedTime'),
                            backgroundColor: dialogColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error recording interruption: $e')),
                        );
                      }
                    }

                    // Close dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Complete current item
  Future<void> _completeItem() async {
    setState(() {
      _timer.completeItem();
      _selectedItem.completedCount++;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Complete the production record in Firebase
      await mesService.completeProductionRecord(
        _recordId,
        _timer.getProductionTime(),
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
    final isLandscape = screenSize.width > screenSize.height;
    final isNarrow = screenSize.width < 900;

    // Calculate appropriate height constraints based on screen size
    // This will help prevent overflow on smaller screens
    final double maxHeaderHeight = isNarrow ? 45 : 55;
    final double maxStatHeight = isNarrow ? 100 : 130;
    final double maxTimeDisplayHeight = isNarrow ? 160 : 200;
    final double buttonHeight = isNarrow ? 45 : 60;

    return Scaffold(
      appBar: AppBar(
        title: Text('Building: ${_selectedItem.name}'),
        backgroundColor: _timer.mode == ProductionTimerMode.running
            ? const Color(0xFF4CAF50) // Green for productive
            : _timer.mode == ProductionTimerMode.interrupted
                ? const Color(0xFFEB281E) // Red for non-productive
                : null, // Default for paused/not started
        foregroundColor: _timer.mode == ProductionTimerMode.running ||
                _timer.mode == ProductionTimerMode.interrupted
            ? Colors.white
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Request Help',
            onPressed: _requestHelp,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit',
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Exit Production'),
                  content: const Text(
                    'Are you sure you want to exit? Your progress will be saved, '
                    'but the item will be marked as incomplete.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushReplacementNamed(
                          context,
                          '/item_selection',
                          arguments: _user,
                        );
                      },
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
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
                              // Placeholder for actual image
                              Container(
                                width: isNarrow ? 50 : 60,
                                height: isNarrow ? 50 : 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getIconForCategory(_selectedItem.category),
                                    size: isNarrow ? 24 : 30,
                                    color: Colors.grey[600],
                                  ),
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
                                color: Theme.of(context).colorScheme.primary,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
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
                                      // Current time
                                      Column(
                                        children: [
                                          Text(
                                            'Current Time',
                                            style: TextStyle(
                                              fontSize: isNarrow ? 18 : 20,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                                            .getProductionTime()),
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
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // Time remaining
                                      Column(
                                        children: [
                                          Text(
                                            'Time Remaining',
                                            style: TextStyle(
                                              fontSize: isNarrow ? 18 : 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isNarrow ? 8 : 12,
                                              vertical: isNarrow ? 12 : 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor()
                                                  .withOpacity(0.8),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: FittedBox(
                                              child: Text(
                                                _formatTimeRemaining(),
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
                              // Start/Pause button
                              Expanded(
                                child:
                                    _timer.mode == ProductionTimerMode.running
                                        ? _buildControlButton(
                                            icon: Icons.pause,
                                            label: 'Pause',
                                            color: const Color(0xFF2C2C2C),
                                            onPressed: _pauseTimer,
                                            isNarrow: isNarrow,
                                          )
                                        : _timer.mode ==
                                                ProductionTimerMode.interrupted
                                            ? _buildControlButton(
                                                icon: Icons.play_arrow,
                                                label: 'Resume',
                                                color: const Color(0xFF4CAF50),
                                                onPressed: _startTimer,
                                                isNarrow: isNarrow,
                                              )
                                            : _buildControlButton(
                                                icon: Icons.play_arrow,
                                                label: 'Start',
                                                color: const Color(0xFFEB281E),
                                                onPressed: _startTimer,
                                                isNarrow: isNarrow,
                                              ),
                              ),
                              SizedBox(width: isNarrow ? 8 : 12),
                              // Complete button
                              Expanded(
                                child: _buildControlButton(
                                  icon: Icons.check,
                                  label: 'Complete',
                                  color: const Color(0xFF2C2C2C),
                                  onPressed: _completeItem,
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
                                      Color buttonColor =
                                          const Color(0xFF2C2C2C);

                                      if (type.name
                                          .toLowerCase()
                                          .contains('break')) {
                                        icon = Icons.coffee;
                                        buttonColor =
                                            const Color(0xFF795548); // Brown
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('maintenance')) {
                                        icon = Icons.build;
                                        buttonColor =
                                            const Color(0xFFFF9800); // Orange
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('prep')) {
                                        icon = Icons.assignment;
                                        buttonColor =
                                            const Color(0xFF2196F3); // Blue
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('material')) {
                                        icon = Icons.inventory;
                                        buttonColor =
                                            const Color(0xFF4CAF50); // Green
                                      } else if (type.name
                                          .toLowerCase()
                                          .contains('training')) {
                                        icon = Icons.school;
                                        buttonColor =
                                            const Color(0xFF9C27B0); // Purple
                                      }

                                      return Column(
                                        children: [
                                          _buildFullWidthButton(
                                            icon: icon,
                                            label: type.name,
                                            color: buttonColor,
                                            onPressed: () {
                                              _startInterruption(type);
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
                                      color: const Color(0xFFEB281E),
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
                      'Production time:',
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
                      'Non-Production Time:',
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

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEB281E),
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
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: color.withOpacity(0.3),
            width: 1,
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
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
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
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(height: isNarrow ? 2 : 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isNarrow ? 10 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.timer,
                  color: color.withOpacity(0.7),
                  size: 16,
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

  // Get color for timer based on remaining time
  Color _getTimerColor() {
    final percent =
        _secondsRemaining / (_selectedItem.estimatedTimeInMinutes * 60);
    if (percent > 0.5) {
      return Colors.green;
    } else if (percent > 0.25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
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
        return Colors.green;
      case ProductionTimerMode.interrupted:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
