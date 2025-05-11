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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left panel - Item info and completed count
            Expanded(
              flex: 2,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item info
                      Row(
                        children: [
                          // Placeholder for actual image
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                _getIconForCategory(_selectedItem.category),
                                size: 36,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedItem.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Category: ${_selectedItem.category}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Est. time: ${_selectedItem.estimatedTimeInMinutes} min',
                                  style: TextStyle(
                                    fontSize: 14,
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
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Completed Items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
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
                                  style: const TextStyle(
                                    fontSize: 24,
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
                      const Text(
                        'Session Statistics',
                        style: TextStyle(
                          fontSize: 16,
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

            const SizedBox(width: 16),

            // Center panel - Timer and main controls
            Expanded(
              flex: 4,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Clock - Vertical layout for smaller screens
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Current time
                                  Column(
                                    children: [
                                      const Text(
                                        'Current Time',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: 280,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
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
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 25),

                                  // Estimated time remaining
                                  Column(
                                    children: [
                                      const Text(
                                        'Time Remaining',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: 280,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _getTimerColor().withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatTimeRemaining(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 48,
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
                        height: 80,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Start/Pause
                              Expanded(
                                child: _buildControlButton(
                                  icon:
                                      _timer.mode == ProductionTimerMode.running
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                  label:
                                      _timer.mode == ProductionTimerMode.running
                                          ? 'Pause'
                                          : 'Start',
                                  color:
                                      _timer.mode == ProductionTimerMode.running
                                          ? const Color(0xFF2C2C2C)
                                          : const Color(0xFFEB281E),
                                  onPressed:
                                      _timer.mode == ProductionTimerMode.running
                                          ? _pauseTimer
                                          : _startTimer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Complete
                              Expanded(
                                child: _buildControlButton(
                                  icon: Icons.check,
                                  label: 'Complete',
                                  color: const Color(0xFF2C2C2C),
                                  onPressed: _completeItem,
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

            const SizedBox(width: 16),

            // Right panel - Additional controls
            Expanded(
              flex: 2,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Additional Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Break button
                            _buildFullWidthButton(
                              icon: Icons.coffee,
                              label: 'Take a Break',
                              color: _timer.mode == ProductionTimerMode.running
                                  ? const Color(0xFF2C2C2C)
                                  : Colors.grey,
                              onPressed: () =>
                                  _startInterruption(_interruptionTypes[0]),
                              description: 'Pause production for a break',
                            ),

                            // Maintenance button
                            _buildFullWidthButton(
                              icon: Icons.build,
                              label: 'Maintenance',
                              color: _timer.mode == ProductionTimerMode.running
                                  ? const Color(0xFF2C2C2C)
                                  : Colors.grey,
                              onPressed: () =>
                                  _startInterruption(_interruptionTypes[1]),
                              description: 'Record equipment maintenance',
                            ),

                            // Prep button
                            _buildFullWidthButton(
                              icon: Icons.assignment,
                              label: 'Prep Time',
                              color: const Color(0xFF2196F3),
                              onPressed: () =>
                                  _startInterruption(_interruptionTypes[2]),
                              description: 'Track material preparation',
                            ),

                            // Help button
                            _buildFullWidthButton(
                              icon: Icons.help_outline,
                              label: 'Request Help',
                              color: const Color(0xFFEB281E),
                              onPressed: _requestHelp,
                              description: 'Call supervisor for assistance',
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
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
  }) {
    return SizedBox(
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
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
