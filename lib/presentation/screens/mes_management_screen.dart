import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../data/services/mes_service.dart';
import '../../data/services/sop_service.dart';
import '../../data/models/mes_item_model.dart';
import '../../data/models/mes_process_model.dart';
import '../../data/models/mes_interruption_model.dart';
import '../widgets/cross_platform_image.dart';

class MESManagementScreen extends StatefulWidget {
  const MESManagementScreen({Key? key}) : super(key: key);

  @override
  State<MESManagementScreen> createState() => _MESManagementScreenState();
}

class _MESManagementScreenState extends State<MESManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load all MES data
  Future<void> _loadData() async {
    final mesService = Provider.of<MESService>(context, listen: false);

    try {
      // Load all data in parallel for better performance
      await Future.wait([
        mesService.fetchProcesses(),
        mesService.fetchStations(),
        mesService.fetchItems(),
        mesService.fetchInterruptionTypes(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manufacturing Execution System',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/sops'),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.account_tree),
              text: 'Processes',
            ),
            Tab(
              icon: Icon(Icons.inventory_2),
              text: 'Items',
            ),
            Tab(
              icon: Icon(Icons.pause_circle),
              text: 'Actions',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home (SOPs)',
            onPressed: () => context.go('/sops'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _getAddButtonTooltip(),
            onPressed: () {
              switch (_tabController.index) {
                case 0:
                  _showAddProcessDialog(context);
                  break;
                case 1:
                  _showAddItemDialog(context);
                  break;
                case 2:
                  _showAddInterruptionTypeDialog(context);
                  break;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _ProcessesTab(),
          _ItemsTab(onEditItem: _showEditItemDialog),
          const _InterruptionTypesTab(),
        ],
      ),
    );
  }

  String _getAddButtonTooltip() {
    switch (_tabController.index) {
      case 0:
        return 'Add Process';
      case 1:
        return 'Add Item';
      case 2:
        return 'Add Action Type';
      default:
        return 'Add';
    }
  }

  // Process Management Dialog
  void _showAddProcessDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedStationId;
    bool requiresSetup = false;

    showDialog(
      context: context,
      builder: (context) => Consumer<MESService>(
        builder: (context, mesService, child) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_tree,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Add Process'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Process Name *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Chair Assembly, Wood Finishing',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon:
                                Icon(Icons.build, color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Describe what this process involves',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.description,
                                color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Station',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedStationId,
                          decoration: InputDecoration(
                            hintText: 'Select a station (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.location_on,
                                color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Station'),
                            ),
                            ...mesService
                                .getActiveStations()
                                .map((station) => DropdownMenuItem<String>(
                                      value: station.id,
                                      child: Text(station.name),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedStationId = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (mesService.getActiveStations().isEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddStationDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Station First'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Switch(
                          value: requiresSetup,
                          onChanged: (value) {
                            setState(() {
                              requiresSetup = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Requires Setup',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'If enabled, operators must complete setup before starting production',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a process name')),
                    );
                    return;
                  }

                  try {
                    final station = selectedStationId != null
                        ? mesService.getStationById(selectedStationId!)
                        : null;

                    await mesService.addProcess(
                      nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      stationId: selectedStationId,
                      stationName: station?.name,
                      requiresSetup: requiresSetup,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Process added successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding process: $e')),
                    );
                  }
                },
                child: const Text('Add Process'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Station Management Dialog (Simple)
  void _showAddStationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Add Station'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name *',
                  hintText: 'e.g., Assembly Line 1, CNC Station',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Floor 2, Bay A',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a station name')),
                );
                return;
              }

              try {
                final mesService =
                    Provider.of<MESService>(context, listen: false);
                await mesService.addStation(
                  nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  location: locationController.text.trim().isEmpty
                      ? null
                      : locationController.text.trim(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Station added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding station: $e')),
                );
              }
            },
            child: const Text('Add Station'),
          ),
        ],
      ),
    );
  }

  // Enhanced Item Management Dialog
  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    String? selectedProcessId;
    String? tempImageUrl;
    String? finalImageUrl;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => Consumer<MESService>(
        builder: (context, mesService, child) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Add Production Item'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basic Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Item Name *',
                                hintText: 'e.g., Dining Chair, Coffee Table',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.label),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Detailed description of the item',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Process and Timing Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Process & Timing',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedProcessId,
                              decoration: const InputDecoration(
                                labelText: 'Process *',
                                hintText: 'Select the manufacturing process',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_tree),
                              ),
                              items: mesService
                                  .getActiveProcesses()
                                  .map((process) => DropdownMenuItem<String>(
                                        value: process.id,
                                        child: Text(
                                          process.stationName != null
                                              ? '${process.name} (${process.stationName})'
                                              : process.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedProcessId = value;
                                });
                              },
                            ),
                            if (mesService.getActiveProcesses().isEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _showAddProcessDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Process First'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: timeController,
                              decoration: const InputDecoration(
                                labelText: 'Estimated Time (minutes) *',
                                hintText: 'e.g., 45',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                                suffixText: 'min',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Image',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  if (tempImageUrl != null ||
                                      finalImageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 400,
                                        height: 200,
                                        child: CrossPlatformImage(
                                          imageUrl:
                                              tempImageUrl ?? finalImageUrl!,
                                          width: 400,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No image selected',
                                            style: TextStyle(
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isUploadingImage)
                                    Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                                color: Colors.white),
                                            SizedBox(height: 8),
                                            Text(
                                              'Uploading...',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Select Image'),
                                  onPressed: isUploadingImage
                                      ? null
                                      : () async {
                                          final imageUrl =
                                              await _pickImageWithPreview();
                                          if (imageUrl != null) {
                                            setState(() {
                                              tempImageUrl = imageUrl;
                                            });
                                          }
                                        },
                                ),
                                if (tempImageUrl != null ||
                                    finalImageUrl != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Remove'),
                                    onPressed: isUploadingImage
                                        ? null
                                        : () {
                                            setState(() {
                                              tempImageUrl = null;
                                              finalImageUrl = null;
                                            });
                                          },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isUploadingImage
                    ? null
                    : () async {
                        // Validation
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter an item name')),
                          );
                          return;
                        }

                        if (selectedProcessId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please select a process')),
                          );
                          return;
                        }

                        if (timeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter estimated time')),
                          );
                          return;
                        }

                        final time = int.tryParse(timeController.text.trim());
                        if (time == null || time <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter a valid time in minutes')),
                          );
                          return;
                        }

                        // Upload image if selected
                        if (tempImageUrl != null) {
                          setState(() {
                            isUploadingImage = true;
                          });

                          try {
                            finalImageUrl = await _uploadImageToStorage(
                              tempImageUrl!,
                              'mes_items',
                              DateTime.now().millisecondsSinceEpoch.toString(),
                            );
                          } catch (e) {
                            setState(() {
                              isUploadingImage = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error uploading image: $e')),
                            );
                            return;
                          }

                          setState(() {
                            isUploadingImage = false;
                          });
                        }

                        try {
                          final process =
                              mesService.getProcessById(selectedProcessId!);
                          await mesService.addItem(
                            nameController.text.trim(),
                            selectedProcessId!,
                            time,
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                            imageUrl: finalImageUrl,
                            processName: process?.name,
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Item added successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error adding item: $e')),
                          );
                        }
                      },
                child: const Text('Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Edit Process Dialog
  void _showEditProcessDialog(BuildContext context, MESProcess process) {
    final nameController = TextEditingController(text: process.name);
    final descriptionController =
        TextEditingController(text: process.description ?? '');
    String? selectedStationId = process.stationId;
    bool requiresSetup = process.requiresSetup;

    showDialog(
      context: context,
      builder: (context) => Consumer<MESService>(
        builder: (context, mesService, child) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_tree,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Edit Process'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Process Name *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Chair Assembly, Wood Finishing',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon:
                                Icon(Icons.build, color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Describe what this process involves',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.description,
                                color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Station',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedStationId,
                          decoration: InputDecoration(
                            hintText: 'Select a station (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.location_on,
                                color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Station'),
                            ),
                            ...mesService
                                .getActiveStations()
                                .map((station) => DropdownMenuItem<String>(
                                      value: station.id,
                                      child: Text(station.name),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedStationId = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (mesService.getActiveStations().isEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddStationDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Station First'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Switch(
                          value: requiresSetup,
                          onChanged: (value) {
                            setState(() {
                              requiresSetup = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Requires Setup',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'If enabled, operators must complete setup before starting production',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a process name')),
                    );
                    return;
                  }

                  try {
                    final station = selectedStationId != null
                        ? mesService.getStationById(selectedStationId!)
                        : null;

                    await mesService.updateProcess(
                      process.copyWith(
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        stationId: selectedStationId,
                        stationName: station?.name,
                        requiresSetup: requiresSetup,
                      ),
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Process updated successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating process: $e')),
                    );
                  }
                },
                child: const Text('Update Process'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Edit Item Dialog
  void _showEditItemDialog(BuildContext context, MESItem item) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController =
        TextEditingController(text: item.description ?? '');
    final timeController =
        TextEditingController(text: item.estimatedTimeInMinutes.toString());

    // Handle legacy data - if processId is empty or invalid, set to null
    String? selectedProcessId = item.processId;
    String? tempImageUrl;
    String? finalImageUrl = item.imageUrl;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => Consumer<MESService>(
        builder: (context, mesService, child) => StatefulBuilder(
          builder: (context, setState) {
            // Validate the processId inside the builder where mesService is available
            if (selectedProcessId != null && selectedProcessId!.isNotEmpty) {
              final availableProcesses = mesService.getActiveProcesses();
              final processExists = availableProcesses
                  .any((process) => process.id == selectedProcessId);
              if (!processExists) {
                selectedProcessId =
                    null; // Reset to null if process doesn't exist
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.inventory_2,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Edit Production Item'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basic Information',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Item Name *',
                                  hintText: 'e.g., Dining Chair, Coffee Table',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.label),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Detailed description of the item',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.description),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Process and Timing Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Process & Timing',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedProcessId,
                                decoration: const InputDecoration(
                                  labelText: 'Process *',
                                  hintText: 'Select the manufacturing process',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.account_tree),
                                ),
                                items: mesService
                                    .getActiveProcesses()
                                    .map((process) => DropdownMenuItem<String>(
                                          value: process.id,
                                          child: Text(
                                            process.stationName != null
                                                ? '${process.name} (${process.stationName})'
                                                : process.name,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedProcessId = value;
                                  });
                                },
                              ),
                              if (mesService.getActiveProcesses().isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAddProcessDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Process First'),
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: timeController,
                                decoration: const InputDecoration(
                                  labelText: 'Estimated Time (minutes) *',
                                  hintText: 'e.g., 45',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.timer),
                                  suffixText: 'min',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Image Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Item Image',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  children: [
                                    if (tempImageUrl != null ||
                                        finalImageUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 400,
                                          height: 200,
                                          child: CrossPlatformImage(
                                            imageUrl:
                                                tempImageUrl ?? finalImageUrl!,
                                            width: 400,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    else
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No image selected',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (isUploadingImage)
                                      Container(
                                        color: Colors.black.withOpacity(0.5),
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                  color: Colors.white),
                                              SizedBox(height: 8),
                                              Text(
                                                'Uploading...',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Select Image'),
                                    onPressed: isUploadingImage
                                        ? null
                                        : () async {
                                            final imageUrl =
                                                await _pickImageWithPreview();
                                            if (imageUrl != null) {
                                              setState(() {
                                                tempImageUrl = imageUrl;
                                              });
                                            }
                                          },
                                  ),
                                  if (tempImageUrl != null ||
                                      finalImageUrl != null) ...[
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Remove'),
                                      onPressed: isUploadingImage
                                          ? null
                                          : () {
                                              setState(() {
                                                tempImageUrl = null;
                                                finalImageUrl = null;
                                              });
                                            },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploadingImage
                      ? null
                      : () async {
                          // Validation
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter an item name')),
                            );
                            return;
                          }

                          if (selectedProcessId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please select a process')),
                            );
                            return;
                          }

                          if (timeController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter estimated time')),
                            );
                            return;
                          }

                          final time = int.tryParse(timeController.text.trim());
                          if (time == null || time <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please enter a valid time in minutes')),
                            );
                            return;
                          }

                          // Upload image if selected
                          if (tempImageUrl != null) {
                            setState(() {
                              isUploadingImage = true;
                            });

                            try {
                              finalImageUrl = await _uploadImageToStorage(
                                tempImageUrl!,
                                'mes_items',
                                item.id,
                              );
                            } catch (e) {
                              setState(() {
                                isUploadingImage = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error uploading image: $e')),
                              );
                              return;
                            }

                            setState(() {
                              isUploadingImage = false;
                            });
                          }

                          try {
                            final process =
                                mesService.getProcessById(selectedProcessId!);
                            await mesService.updateItem(
                              item.copyWith(
                                name: nameController.text.trim(),
                                description:
                                    descriptionController.text.trim().isEmpty
                                        ? null
                                        : descriptionController.text.trim(),
                                processId: selectedProcessId!,
                                processName: process?.name,
                                estimatedTimeInMinutes: time,
                                imageUrl: finalImageUrl,
                              ),
                            );

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Item updated successfully')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error updating item: $e')),
                            );
                          }
                        },
                  child: const Text('Update Item'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Interruption Type Dialog
  void _showAddInterruptionTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Color selectedColor = Colors.orange;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.pause_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Add Action Type'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Action Name *',
                    hintText: 'e.g., Break, Maintenance, Material Wait',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe when this action occurs',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Color: ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _showColorPicker(context, selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Icon(
                          Icons.color_lens,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter an action name')),
                  );
                  return;
                }

                try {
                  final mesService =
                      Provider.of<MESService>(context, listen: false);
                  await mesService.addInterruptionType(
                    nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    color:
                        '#${selectedColor.value.toRadixString(16).substring(2)}',
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Action type added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding action type: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Interruption Type Dialog
  void _showEditInterruptionTypeDialog(
      BuildContext context, MESInterruptionType type) {
    final nameController = TextEditingController(text: type.name);
    final descriptionController =
        TextEditingController(text: type.description ?? '');

    // Parse the existing color or use default
    Color selectedColor = Colors.orange;
    if (type.color != null && type.color!.isNotEmpty) {
      try {
        String colorHex = type.color!.replaceAll('#', '');
        if (colorHex.length == 6) {
          colorHex = 'FF$colorHex'; // Add alpha channel
        }
        selectedColor = Color(int.parse(colorHex, radix: 16));
      } catch (e) {
        selectedColor = Colors.orange; // Fallback to default
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.pause_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Edit Action Type'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Action Name *',
                    hintText: 'e.g., Break, Maintenance, Material Wait',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe when this action occurs',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Color: ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _showColorPicker(context, selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Icon(
                          Icons.color_lens,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter an action name')),
                  );
                  return;
                }

                try {
                  final mesService =
                      Provider.of<MESService>(context, listen: false);
                  await mesService.updateInterruptionType(
                    type.copyWith(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      color:
                          '#${selectedColor.value.toRadixString(16).substring(2)}',
                    ),
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Non-value activity type updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Error updating non-value activity type: $e')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Color picker method
  void _showColorPicker(BuildContext context, Color currentColor,
      Function(Color) onColorChanged) {
    final List<Color> predefinedColors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.brown,
      Colors.grey,
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Color'),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: predefinedColors.length,
              itemBuilder: (context, index) {
                final color = predefinedColors[index];
                final isSelected = color.value == currentColor.value;

                return GestureDetector(
                  onTap: () {
                    onColorChanged(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Image picker method
  Future<String?> _pickImageWithPreview() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error in image picking process: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $e')),
      );
      return null;
    }
  }

  // Image upload method
  Future<String?> _uploadImageToStorage(
      String dataUrl, String collection, String itemId) async {
    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      return await sopService.uploadImageFromDataUrl(
          dataUrl, collection, itemId);
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image to storage: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }
}

// Processes Tab Widget
class _ProcessesTab extends StatelessWidget {
  const _ProcessesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (mesService.isLoadingProcesses) {
          return const Center(child: CircularProgressIndicator());
        }

        final processes = mesService.processes;

        if (processes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_tree,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No processes found',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first manufacturing process',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use the + button in the top bar to add your first process',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: processes.length,
          itemBuilder: (context, index) {
            final process = processes[index];
            return _buildProcessCard(context, process, mesService);
          },
        );
      },
    );
  }

  Widget _buildProcessCard(
      BuildContext context, MESProcess process, MESService mesService) {
    final itemCount = mesService.getItemsByProcess(process.id).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Could navigate to process details
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_tree,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          process.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (process.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            process.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Process',
                        onPressed: () {
                          final parentState = context.findAncestorStateOfType<
                              _MESManagementScreenState>();
                          parentState?._showEditProcessDialog(context, process);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          process.isActive
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: process.isActive ? null : Colors.grey,
                        ),
                        tooltip: process.isActive ? 'Deactivate' : 'Activate',
                        onPressed: () {
                          // Toggle status
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Process',
                        color: Colors.red,
                        onPressed: itemCount > 0
                            ? null
                            : () {
                                // Delete functionality
                              },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    Icons.location_on,
                    'Station',
                    process.stationName ?? 'Not assigned',
                    process.stationName != null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    context,
                    Icons.inventory_2,
                    'Items',
                    '$itemCount',
                    itemCount > 0
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(process.isActive),
                  if (process.requiresSetup) ...[
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      context,
                      Icons.build,
                      'Setup',
                      'Required',
                      Colors.blue,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Items Tab Widget
class _ItemsTab extends StatelessWidget {
  final Function(BuildContext, MESItem) onEditItem;

  const _ItemsTab({Key? key, required this.onEditItem}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (mesService.isLoadingItems) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = mesService.items;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No items found',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first production item',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use the + button in the top bar to add your first item',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildItemCard(context, item, mesService);
          },
        );
      },
    );
  }

  Widget _buildItemCard(
      BuildContext context, MESItem item, MESService mesService) {
    final process = mesService.getProcessById(item.processId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Could navigate to item details
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Item Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CrossPlatformImage(
                          imageUrl: item.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.inventory_2,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
              ),
              const SizedBox(width: 20),

              // Item Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (process?.stationName != null)
                          _buildInfoChip(
                            context,
                            Icons.location_on,
                            'Station',
                            process!.stationName!,
                            Colors.orange,
                          ),
                        _buildInfoChip(
                          context,
                          Icons.account_tree,
                          'Process',
                          process?.name ?? 'Unknown',
                          Theme.of(context).colorScheme.primary,
                        ),
                        _buildInfoChip(
                          context,
                          Icons.timer,
                          'Time',
                          '${item.estimatedTimeInMinutes} min',
                          Theme.of(context).colorScheme.secondary,
                        ),
                        _buildStatusChip(item.isActive),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit Item',
                    onPressed: () {
                      onEditItem(context, item);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      item.isActive ? Icons.visibility : Icons.visibility_off,
                      color: item.isActive ? null : Colors.grey,
                    ),
                    tooltip: item.isActive ? 'Deactivate' : 'Activate',
                    onPressed: () {
                      // Toggle status
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete Item',
                    color: Colors.red,
                    onPressed: () {
                      // Delete functionality
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// Interruption Types Tab (Enhanced from original)
class _InterruptionTypesTab extends StatelessWidget {
  const _InterruptionTypesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (mesService.isLoadingInterruptionTypes) {
          return const Center(child: CircularProgressIndicator());
        }

        final types = mesService.interruptionTypes;

        if (types.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pause_circle,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No action types found',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create action types for production tracking',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use the + button in the top bar to add action types',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            return _buildInterruptionCard(context, type);
          },
        );
      },
    );
  }

  Widget _buildInterruptionCard(
      BuildContext context, MESInterruptionType type) {
    // Parse the stored color or use a default
    Color typeColor = Colors.orange; // Default color
    if (type.color != null && type.color!.isNotEmpty) {
      try {
        // Remove the # if present and ensure it's a valid hex
        String colorHex = type.color!.replaceAll('#', '');
        if (colorHex.length == 6) {
          colorHex = 'FF$colorHex'; // Add alpha channel
        }
        typeColor = Color(int.parse(colorHex, radix: 16));
      } catch (e) {
        // If parsing fails, keep the default orange color
        typeColor = Colors.orange;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Could navigate to type details
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pause_circle,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (type.description != null &&
                            type.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            type.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        onPressed: () {
                          final parentState = context.findAncestorStateOfType<
                              _MESManagementScreenState>();
                          parentState?._showEditInterruptionTypeDialog(
                              context, type);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          type.isActive
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: type.isActive ? null : Colors.grey,
                        ),
                        tooltip: type.isActive ? 'Deactivate' : 'Activate',
                        onPressed: () async {
                          try {
                            final mesService =
                                Provider.of<MESService>(context, listen: false);
                            if (type.isActive) {
                              await mesService
                                  .deactivateInterruptionType(type.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('${type.name} deactivated')),
                              );
                            } else {
                              await mesService.updateInterruptionType(
                                type.copyWith(isActive: true),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('${type.name} activated')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error toggling status: $e')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete',
                        color: Colors.red,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Action Type'),
                              content: Text(
                                  'Are you sure you want to delete "${type.name}"? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final mesService =
                                          Provider.of<MESService>(context,
                                              listen: false);
                                      await mesService
                                          .deleteInterruptionType(type.id);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '${type.name} deleted successfully')),
                                      );
                                    } catch (e) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error deleting: $e')),
                                      );
                                    }
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(type.isActive),
                  const SizedBox(width: 8),
                  _buildColorChip(typeColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
