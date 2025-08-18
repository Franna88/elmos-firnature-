import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Production data fields
  int _expectedQty = 0;
  int _qtyPerCycle = 0;
  int _finishedQty = 0;
  int _rejectQty = 0;

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
      await mesService.fetchInterruptionTypes(onlyActive: true);
      if (!mounted) return;

      _interruptionTypes = mesService.interruptionTypes
          .where((type) => !type.name.toLowerCase().contains('production'))
          .toList();

      // Load process information to check setup requirements
      await mesService.fetchProcesses(onlyActive: true);
      if (!mounted) return;

      // Load available items for this process
      final mesItems = await mesService.fetchItems(onlyActive: true);
      if (!mounted) return;

      // Filter items for the selected process and convert to FurnitureItem
      final processItems =
          mesItems.where((item) => item.processId == _process!.id).toList();
      _availableItems = processItems
          .map((mesItem) => FurnitureItem(
                id: mesItem.id,
                name: mesItem.name,
                category: mesItem.category ?? 'Uncategorized',
                imageUrl: mesItem.imageUrl,
                estimatedTimeInMinutes: mesItem.estimatedTimeInMinutes,
              ))
          .toList();

      // Process is already set from arguments, no need to find it
      // If we have a selected item, validate it belongs to this process
      if (_selectedItem != null) {
        final mesItem =
            mesItems.firstWhere((item) => item.id == _selectedItem!.id);
        if (mesItem.processId != _process!.id) {
          throw Exception(
              'Selected item does not belong to the selected process');
        }
      }

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

  // Select an action directly (simplified - no popups)
  void _startAction(MESInterruptionType type) {
    setState(() {
      // Stop current action if any
      if (_timer.currentAction != null) {
        _recordActionEnd(_timer.currentAction!);
        _timer.stopAction();
      }

      // Select and start the new action immediately
      _selectedAction = type;
      _timer.startAction(type);
    });

    // Record the start of this action in Firebase
    _recordActionStart(type);

    // Show brief feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${type.name}'),
        duration: const Duration(seconds: 1),
        backgroundColor: _timer.getActionColor(),
      ),
    );
  }

  // Show item selection dialog
  void _showItemSelectionDialog() {
    FurnitureItem? selectedItem =
        _selectedItem; // Pre-select current item if any
    final TextEditingController expectedQtyController =
        TextEditingController(text: _expectedQty.toString());
    final TextEditingController qtyPerCycleController =
        TextEditingController(text: _qtyPerCycle.toString());
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
                        // 1. Selected Item Dropdown
                        _buildFormField(
                          label: 'Selected Item',
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.02,
                                vertical: MediaQuery.of(context).size.height *
                                    0.015), // Responsive padding
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
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
                                                    Text(
                                                      item.name,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 16),
                                                    ),
                                                    Text(
                                                      '${item.estimatedTimeInMinutes} min est.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                onChanged: (FurnitureItem? value) {
                                  setDialogState(() {
                                    selectedItem = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 2. Select Part Dropdown (Coming Soon) - More compact
                        _buildCompactFormField(
                          label: 'Select Part',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.construction,
                                    size: 20, color: Colors.grey.shade400),
                                const SizedBox(width: 12),
                                Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),

                        // Quantity fields in a 2x2 grid - Responsive
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactFormField(
                                label: 'Expected QTY',
                                child: _buildCompactNumberField(
                                    expectedQtyController,
                                    'Expected QTY',
                                    AppColors.primaryBlue),
                              ),
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                            Expanded(
                              child: _buildCompactFormField(
                                label: 'QTY per Cycle',
                                child: _buildCompactNumberField(
                                    qtyPerCycleController,
                                    'QTY per Cycle',
                                    AppColors.greenAccent,
                                    helperText: 'Incremented with "Next"'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.015),
                        // Bottom row: Finished QTY and Reject QTY
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactFormField(
                                label: 'Finished QTY',
                                child: _buildCompactNumberField(
                                    finishedQtyController,
                                    'Finished QTY',
                                    AppColors.greenAccent),
                              ),
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                            Expanded(
                              child: _buildCompactFormField(
                                label: 'Reject QTY',
                                child: _buildCompactNumberField(
                                    rejectQtyController,
                                    'Reject QTY',
                                    AppColors.orangeAccent),
                              ),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.03,
                            vertical: MediaQuery.of(context).size.height *
                                0.015), // Responsive padding
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.height * 0.022,
                            fontWeight: FontWeight.w600), // Responsive text
                      ),
                    ),
                    SizedBox(
                        width: MediaQuery.of(context).size.width *
                            0.02), // Responsive spacing
                    ElevatedButton(
                      onPressed: selectedItem == null
                          ? null
                          : () {
                              _saveItemProductionData(
                                item: selectedItem!,
                                expectedQty:
                                    int.tryParse(expectedQtyController.text) ??
                                        0,
                                qtyPerCycle:
                                    int.tryParse(qtyPerCycleController.text) ??
                                        0,
                                finishedQty:
                                    int.tryParse(finishedQtyController.text) ??
                                        0,
                                rejectQty:
                                    int.tryParse(rejectQtyController.text) ?? 0,
                              );
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.04,
                            vertical: MediaQuery.of(context).size.height *
                                0.018), // Responsive padding
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10), // Responsive radius
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.height * 0.025,
                            fontWeight: FontWeight.bold), // Responsive text
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
                Container(
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

  // Helper method to build compact number input fields
  Widget _buildCompactNumberField(
    TextEditingController controller,
    String title,
    Color iconColor, {
    String? helperText,
  }) {
    return GestureDetector(
      onTap: () => _showCompactNumberPad(controller, title),
      child: Container(
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
    try {
      // Create a new production record for the selected item
      final mesService = Provider.of<MESService>(context, listen: false);
      final record = await mesService.startProductionRecord(
        item.id,
        _user.id,
        _user.name,
      );
      final recordId = record.id;

      setState(() {
        _selectedItem = item;
        _recordId = recordId;
        _secondsRemaining = item.estimatedTimeInMinutes * 60;
        _timer.resetForNewItem(); // Reset timer when selecting new item
        _setupCompleted = false; // Reset setup status

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
        }
      });

      // Close the dialog
      Navigator.of(context).pop();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: ${item.name}'),
          backgroundColor: AppColors.primaryBlue,
        ),
      );

      // Setup is now automatic - no popup required
      // The Setup action is already selected and started above
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting item: $e')),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Production setup saved for ${item.name}'),
          backgroundColor: AppColors.greenAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving production data: $e')),
      );
    }
  }

  // Save production data to Firebase
  Future<void> _saveProductionDataToFirebase({
    required FurnitureItem item,
    required int expectedQty,
    required int qtyPerCycle,
    required int finishedQty,
    required int rejectQty,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create production data document
      final productionData = {
        'itemId': item.id,
        'itemName': item.name,
        'processId': _process?.id,
        'processName': _process?.name,
        'userId': _user.id,
        'userName': _user.name,
        'expectedQty': expectedQty,
        'qtyPerCycle': qtyPerCycle,
        'finishedQty': finishedQty,
        'rejectQty': rejectQty,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      // Save to production_data collection
      await firestore
          .collection('production_data')
          .doc(
              '${_user.id}_${item.id}_${DateTime.now().millisecondsSinceEpoch}')
          .set(productionData);

      print('🔥 Production data saved to Firebase: $productionData');
    } catch (e) {
      print('❌ Error saving production data to Firebase: $e');
      rethrow;
    }
  }

  // Setup dialog removed - actions now switch immediately without popups

  // Record action start in Firebase
  Future<void> _recordActionStart(MESInterruptionType action) async {
    try {
      print('🔥 Recording action START: ${action.name} (ID: ${action.id})');
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
      print(
          '🔥 Recording action END: ${action.name} (Duration: ${_timer.getActionTime()}s)');
      final mesService = Provider.of<MESService>(context, listen: false);
      final now = DateTime.now();

      // Calculate action duration
      final actionDuration = _timer.getActionTime();

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
      // Increment by the configured qty per cycle
      _selectedItem!.completedCount += _qtyPerCycle;
      // Also update finished qty
      _finishedQty += _qtyPerCycle;
    });

    // Save the updated item completion records to the database
    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      await mesService.updateProductionRecord(
        await mesService.getProductionRecord(_recordId!).then(
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
        await mesService.getProductionRecord(_recordId!).then(
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
        await mesService.getProductionRecord(_recordId!).then(
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
        await mesService.getProductionRecord(_recordId!).then(
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
        automaticallyImplyLeading: false,
        title: Text(_selectedItem != null
            ? 'Building: ${_selectedItem!.name}'
            : 'Process: ${_process?.name ?? 'Unknown'} - Select Item'),
        backgroundColor: _timer.mode == ProductionTimerMode.running
            ? _timer.getActionColor() // Use action color when running
            : _timer.mode == ProductionTimerMode.interrupted
                ? AppColors.orangeAccent // Orange for non-productive
                : AppColors.primaryBlue, // Default blue theme
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Process Selection',
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/process_selection',
                arguments: _user);
          },
        ),
        actions: [
          // Home button
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/process_selection',
                  arguments: _user);
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
                          Container(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showItemSelectionDialog,
                              icon: Icon(Icons.inventory_2),
                              label: Text(
                                _selectedItem != null
                                    ? 'Change Item: ${_selectedItem!.name}'
                                    : 'Select Item',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedItem != null
                                    ? AppColors.primaryBlue
                                    : Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
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
                                  SizedBox(
                                      height:
                                          20), // Small top padding instead of centering
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
                              // Next Item button (only show when Production action is selected)
                              if (_selectedAction != null &&
                                  _selectedAction!.name
                                      .toLowerCase()
                                      .contains('production'))
                                Expanded(
                                  child: _buildControlButton(
                                    icon: Icons.add_circle,
                                    label:
                                        'Next +$_qtyPerCycle (${_finishedQty}/${_expectedQty})',
                                    color: AppColors.greenAccent,
                                    onPressed: _nextItem,
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
    final bool isSelected = _selectedAction != null &&
        interruptionType != null &&
        _selectedAction!.id == interruptionType.id;

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
              onPressed: _showItemSelectionDialog,
              icon: const Icon(Icons.inventory_2),
              label: const Text('Select Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
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
}
