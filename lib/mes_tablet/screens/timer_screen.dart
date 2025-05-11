import 'dart:async';
import 'package:flutter/material.dart';
import '../models/furniture_item.dart';
import '../models/production_timer.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late FurnitureItem _selectedItem;
  late ProductionTimer _timer;
  late int _secondsRemaining;
  
  @override
  void initState() {
    super.initState();
    // Initialize production timer with onTick callback
    _timer = ProductionTimer(onTick: () {
      if (mounted) {
        setState(() {
          // Update remaining time when timer is running
          if (_timer.mode == ProductionTimerMode.running && _secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the selected item from the arguments
    _selectedItem = ModalRoute.of(context)!.settings.arguments as FurnitureItem;
    
    // Initialize remaining time
    _secondsRemaining = _selectedItem.estimatedTimeInMinutes * 60;
  }
  
  @override
  void dispose() {
    // Clean up timer resources
    _timer.dispose();
    super.dispose();
  }
  
  // Start or resume production
  void _startTimer() {
    setState(() {
      _timer.startProduction();
    });
  }
  
  // Pause production
  void _pauseTimer() {
    setState(() {
      _timer.pauseProduction();
    });
  }
  
  // Start a break
  void _startBreak() {
    // Only allow starting a break from running state
    if (_timer.mode == ProductionTimerMode.running) {
      setState(() {
        _timer.startBreak();
      });
      
      _showBreakDialog();
    } else {
      // If not running, show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must start the timer before taking a break'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Start maintenance
  void _startMaintenance() {
    // Only allow starting maintenance from running state
    if (_timer.mode == ProductionTimerMode.running) {
      setState(() {
        _timer.startMaintenance();
      });
      
      _showMaintenanceDialog();
    } else {
      // If not running, show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must start the timer before recording maintenance'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Start prep time
  void _startPrep() {
    setState(() {
      _timer.startPrep();
    });
    
    _showPrepDialog();
  }
  
  // Complete current item
  void _completeItem() {
    setState(() {
      _timer.completeItem();
      _selectedItem.completedCount++;
      
      // Reset the remaining time for the next item
      _secondsRemaining = _selectedItem.estimatedTimeInMinutes * 60;
      
      // Reset the timer for the next item
      _timer.resetForNewItem();
      
      // Show a confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item completed! Ready for next item.'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }
  
  // Show help request dialog
  void _requestHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Request'),
        content: const Text('Your help request has been sent to the supervisor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Show break dialog
  void _showBreakDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BreakDialog(
        onResume: () {
          setState(() {
            _timer.startProduction();
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  
  // Show maintenance dialog
  void _showMaintenanceDialog() {
    final notesController = TextEditingController();
    final partsController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MaintenanceDialog(
        onComplete: () {
          setState(() {
            _timer.startProduction();
            
            // Here we can save the maintenance information
            final maintenanceNotes = notesController.text;
            final replacedParts = partsController.text;
            
            // Show what was recorded (in real app, you'd save this to a database)
            if (maintenanceNotes.isNotEmpty || replacedParts.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 500), () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Maintenance recorded: ${replacedParts.isNotEmpty ? 'Parts replaced: $replacedParts' : ''}'
                      '${maintenanceNotes.isNotEmpty ? ' Notes: $maintenanceNotes' : ''}',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              });
            }
          });
          Navigator.pop(context);
        },
        notesController: notesController,
        partsController: partsController,
      ),
    );
  }
  
  // Show prep time dialog
  void _showPrepDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PrepDialog(
        onComplete: () {
          setState(() {
            _timer.startProduction();
          });
          Navigator.pop(context);
        },
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
    final percent = _secondsRemaining / (_selectedItem.estimatedTimeInMinutes * 60);
    if (percent > 0.5) {
      return Colors.green;
    } else if (percent > 0.25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Get formatted time strings for display
    final productionFormatted = ProductionTimer.formatTime(_timer.getProductionTime());
    final breakFormatted = ProductionTimer.formatTime(_timer.getBreakTime());
    final maintenanceFormatted = ProductionTimer.formatTime(_timer.getMaintenanceTime());
    final prepFormatted = ProductionTimer.formatTime(_timer.getPrepTime());
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Building: ${_selectedItem.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/item_selection');
          },
        ),
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
                                  color: Theme.of(context).colorScheme.primaryContainer,
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
                            _buildStatRow('Production time:', productionFormatted),
                            const SizedBox(height: 8),
                            _buildStatRow('Break time:', breakFormatted),
                            const SizedBox(height: 8),
                            _buildStatRow('Maintenance time:', maintenanceFormatted),
                            const SizedBox(height: 8),
                            _buildStatRow('Preparation time:', prepFormatted),
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
                                          color: _timer.mode == ProductionTimerMode.running
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          productionFormatted,
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
                                          color: _getTimerColor().withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
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
                                  icon: _timer.mode == ProductionTimerMode.running
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  label: _timer.mode == ProductionTimerMode.running
                                      ? 'Pause'
                                      : 'Start',
                                  color: _timer.mode == ProductionTimerMode.running
                                      ? const Color(0xFF2C2C2C)
                                      : const Color(0xFFEB281E),
                                  onPressed: _timer.mode == ProductionTimerMode.running
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
                              onPressed: _startBreak,
                              description: 'Pause production for a break',
                            ),
                            
                            // Maintenance button
                            _buildFullWidthButton(
                              icon: Icons.build,
                              label: 'Maintenance',
                              color: _timer.mode == ProductionTimerMode.running 
                                  ? const Color(0xFF2C2C2C)
                                  : Colors.grey,
                              onPressed: _startMaintenance,
                              description: 'Record equipment maintenance',
                            ),
                            
                            // Prep button
                            _buildFullWidthButton(
                              icon: Icons.assignment,
                              label: 'Prep Time',
                              color: const Color(0xFF2196F3),
                              onPressed: _startPrep,
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
      case ProductionTimerMode.onBreak:
        return 'On Break';
      case ProductionTimerMode.maintenance:
        return 'Maintenance in Progress';
      case ProductionTimerMode.prep:
        return 'Preparation in Progress';
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
}

class _BreakDialog extends StatefulWidget {
  final VoidCallback onResume;

  const _BreakDialog({
    required this.onResume,
  });

  @override
  State<_BreakDialog> createState() => _BreakDialogState();
}

class _BreakDialogState extends State<_BreakDialog> {
  late Timer _timer;
  late int _seconds;
  
  @override
  void initState() {
    super.initState();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB281E).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.coffee,
                    size: 30,
                    color: Color(0xFFEB281E),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Break Time',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEB281E),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Pause message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your production timer is paused while on break.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEB281E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'RESUME WORK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceDialog extends StatefulWidget {
  final VoidCallback onComplete;
  final TextEditingController notesController;
  final TextEditingController partsController;

  const _MaintenanceDialog({
    required this.onComplete,
    required this.notesController,
    required this.partsController,
  });

  @override
  State<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<_MaintenanceDialog> {
  late Timer _timer;
  late int _seconds;
  
  @override
  void initState() {
    super.initState();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB281E).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.build,
                    size: 30,
                    color: Color(0xFFEB281E),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Maintenance in Progress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Timer
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEB281E),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Pause message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your production timer is paused while maintenance is in progress.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Maintenance details form
            const Text(
              'Maintenance Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 16),
            
            // Maintenance notes
            TextField(
              controller: widget.notesController,
              decoration: const InputDecoration(
                labelText: 'Maintenance Notes',
                border: OutlineInputBorder(),
                hintText: 'Enter details about the maintenance performed',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Parts replaced field
            TextField(
              controller: widget.partsController,
              decoration: const InputDecoration(
                labelText: 'Parts Replaced',
                border: OutlineInputBorder(),
                hintText: 'Enter parts separated by commas (e.g., Motor, Belt, Switch)',
                prefixIcon: Icon(Icons.build_circle),
              ),
            ),
            const SizedBox(height: 24),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEB281E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'COMPLETE MAINTENANCE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrepDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const _PrepDialog({
    required this.onComplete,
  });

  @override
  State<_PrepDialog> createState() => _PrepDialogState();
}

class _PrepDialogState extends State<_PrepDialog> {
  late Timer _timer;
  late int _seconds;
  final TextEditingController _notesController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    _notesController.dispose();
    super.dispose();
  }
  
  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment,
                    size: 30,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Preparation Time',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Preparation Notes',
                border: OutlineInputBorder(),
                hintText: 'Enter any notes about your preparation activities',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // Pause message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your production timer is paused while preparation is in progress.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'COMPLETE PREPARATION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 