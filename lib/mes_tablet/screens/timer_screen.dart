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
          if (_timer.mode == ProductionTimerMode.running &&
              _secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
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
    // Only allow starting an interruption from running state
    if (_timer.mode == ProductionTimerMode.running) {
      setState(() {
        _timer.startInterruption();
      });

      // Show appropriate dialog based on type
      String? notes = await _showInterruptionDialog(type);

      // Record the interruption in Firebase
      try {
        final mesService = Provider.of<MESService>(context, listen: false);
        final now = DateTime.now();

        await mesService.addInterruptionToRecord(
          _recordId,
          type.id,
          type.name,
          now,
          notes: notes,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording interruption: $e')),
        );
      }
    } else {
      // If not running, show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('You must start the timer before recording an interruption'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  // Show interruption dialog
  Future<String?> _showInterruptionDialog(MESInterruptionType type) async {
    final notesController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${type.name} in Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You have started a ${type.name.toLowerCase()}. '
                'Please add any notes below if needed.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText:
                    'Enter any details about this ${type.name.toLowerCase()}',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _timer.startProduction();
              Navigator.pop(context, notesController.text);
            },
            child: const Text('Resume Production'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Building: ${_selectedItem.name}'),
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
          padding: EdgeInsets.all(isNarrow ? 12.0 : 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left panel - Item info and completed count
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item info
                        Row(
                          children: [
                            // Placeholder for actual image
                            Container(
                              width: isNarrow ? 60 : 70,
                              height: isNarrow ? 60 : 70,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  _getIconForCategory(_selectedItem.category),
                                  size: isNarrow ? 30 : 36,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            SizedBox(width: isNarrow ? 12 : 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedItem.name,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Category: ${_selectedItem.category}',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 13 : 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Est. time: ${_selectedItem.estimatedTimeInMinutes} min',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 13 : 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 30),

                        // Completed count
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: isNarrow ? 24 : 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: isNarrow ? 8 : 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Completed Items',
                                  style: TextStyle(
                                    fontSize: isNarrow ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 16 : 20,
                                    vertical: 8,
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
                                      fontSize: isNarrow ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Stats
                        Text(
                          'Session Statistics',
                          style: TextStyle(
                            fontSize: isNarrow ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildStatRow(
                                  'Production time:',
                                  ProductionTimer.formatDuration(
                                      _timer.getProductionTime())),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                  'Interruption time:',
                                  ProductionTimer.formatDuration(
                                      _timer.getTotalInterruptionTime())),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: isNarrow ? 12 : 16),

              // Center panel - Timer and main controls
              Expanded(
                flex: 4,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 16.0 : 20.0),
                    child: Column(
                      children: [
                        // Timer display
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Status
                                Text(
                                  _getStatusText(),
                                  style: TextStyle(
                                    fontSize: isNarrow ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: isNarrow ? 20 : 30),

                                // Clock - Vertical layout for smaller screens
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Current time
                                    Column(
                                      children: [
                                        Text(
                                          'Current Time',
                                          style: TextStyle(
                                            fontSize: isNarrow ? 16 : 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          width: isNarrow ? 240 : 280,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isNarrow ? 16 : 24,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _timer.mode ==
                                                    ProductionTimerMode.running
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.grey.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            ProductionTimer.formatDuration(
                                                _timer.getProductionTime()),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isNarrow ? 38 : 48,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: isNarrow ? 16 : 25),

                                    // Estimated time remaining
                                    Column(
                                      children: [
                                        Text(
                                          'Time Remaining',
                                          style: TextStyle(
                                            fontSize: isNarrow ? 16 : 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          width: isNarrow ? 240 : 280,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isNarrow ? 16 : 24,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getTimerColor()
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _formatTimeRemaining(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isNarrow ? 38 : 48,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              color: _getTimerColor(),
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

                        const Divider(height: 32),

                        // Main controls - Start/Pause and Complete
                        SizedBox(
                          height: isNarrow ? 70 : 80,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Start/Pause
                                Expanded(
                                  child: _buildControlButton(
                                    icon: _timer.mode ==
                                            ProductionTimerMode.running
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    label: _timer.mode ==
                                            ProductionTimerMode.running
                                        ? 'Pause'
                                        : 'Start',
                                    color: _timer.mode ==
                                            ProductionTimerMode.running
                                        ? const Color(0xFF2C2C2C)
                                        : const Color(0xFFEB281E),
                                    onPressed: _timer.mode ==
                                            ProductionTimerMode.running
                                        ? _pauseTimer
                                        : _startTimer,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                                SizedBox(width: isNarrow ? 12 : 16),
                                // Complete
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: isNarrow ? 12 : 16),

              // Right panel - Additional controls
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Controls',
                          style: TextStyle(
                            fontSize: isNarrow ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isNarrow ? 16 : 20),
                        Expanded(
                          child: ListView(
                            // Use ListView instead of Column to handle potential overflow
                            children: [
                              // Break button
                              _buildFullWidthButton(
                                icon: Icons.coffee,
                                label: 'Take a Break',
                                color:
                                    _timer.mode == ProductionTimerMode.running
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey,
                                onPressed: () {
                                  if (_interruptionTypes.isNotEmpty) {
                                    _startInterruption(_interruptionTypes[0]);
                                  }
                                },
                                description: 'Pause production for a break',
                                isNarrow: isNarrow,
                              ),
                              SizedBox(height: isNarrow ? 8 : 12),

                              // Maintenance button
                              _buildFullWidthButton(
                                icon: Icons.build,
                                label: 'Maintenance',
                                color:
                                    _timer.mode == ProductionTimerMode.running
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey,
                                onPressed: () {
                                  if (_interruptionTypes.length > 1) {
                                    _startInterruption(_interruptionTypes[1]);
                                  }
                                },
                                description: 'Record equipment maintenance',
                                isNarrow: isNarrow,
                              ),
                              SizedBox(height: isNarrow ? 8 : 12),

                              // Prep button
                              _buildFullWidthButton(
                                icon: Icons.assignment,
                                label: 'Prep Time',
                                color: const Color(0xFF2196F3),
                                onPressed: () {
                                  if (_interruptionTypes.length > 2) {
                                    _startInterruption(_interruptionTypes[2]);
                                  }
                                },
                                description: 'Track material preparation',
                                isNarrow: isNarrow,
                              ),
                              SizedBox(height: isNarrow ? 8 : 12),

                              // Help button
                              _buildFullWidthButton(
                                icon: Icons.help_outline,
                                label: 'Help',
                                color: const Color(0xFFEB281E),
                                onPressed: _requestHelp,
                                description: 'Call supervisor for assistance',
                                isNarrow: isNarrow,
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
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
}
