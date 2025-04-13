import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import '../../../data/services/sop_service.dart';
import '../../../data/services/print_service.dart';
import '../../../data/models/sop_model.dart';
import '../../widgets/sop_viewer.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import '../../../data/services/category_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SOPEditorScreen extends StatefulWidget {
  final String sopId;

  const SOPEditorScreen({super.key, required this.sopId});

  @override
  State<SOPEditorScreen> createState() => _SOPEditorScreenState();
}

class _SOPEditorScreenState extends State<SOPEditorScreen> {
  late SOP _sop;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _printService = PrintService();

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _loadSOP();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      if (widget.sopId == 'new') {
        // Schedule the creation of a new SOP after the current build phase is complete
        // This prevents the "setState during build" error
        Future.microtask(() async {
          final newSop = await sopService.createSop(
            '',
            '',
            '', // Empty categoryId - will be selected by user
          );

          if (mounted) {
            setState(() {
              _sop = newSop;
              // Initialize controllers with empty strings
              _titleController = TextEditingController();
              _descriptionController = TextEditingController();
              // No need for department controller as we'll use a dropdown
              _isLoading = false;
              _isEditing = true;
            });
          }
        });
        return; // Exit early, the microtask will handle the rest
      } else {
        // Load existing SOP
        final existingSop = sopService.getSopById(widget.sopId);
        if (existingSop == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SOP not found')),
            );
            context.go('/');
            return;
          }
        }
        _sop = existingSop!;
      }

      // Initialize controllers
      _titleController = TextEditingController(text: _sop.title);
      _descriptionController = TextEditingController(text: _sop.description);
      // No need for department controller as we'll use a dropdown

      setState(() {
        _isLoading = false;
        _isEditing = widget.sopId == 'new';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading SOP: $e')),
        );
        context.go('/');
      }
    }
  }

  Future<void> _saveSOP() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final sopService = Provider.of<SOPService>(context, listen: false);
        final categoryService =
            Provider.of<CategoryService>(context, listen: false);

        // Find the category name for the selected categoryId
        String? categoryName;
        if (_sop.categoryId.isNotEmpty) {
          final category = categoryService.getCategoryById(_sop.categoryId);
          if (category != null) {
            categoryName = category.name;
          }
        }

        // Update SOP with form values
        final updatedSop = _sop.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          categoryName: categoryName,
          updatedAt: DateTime.now(),
        );

        // Save to Firebase
        await sopService.updateSop(updatedSop);

        // Explicitly refresh SOPs to ensure data consistency
        await sopService.refreshSOPs();

        setState(() {
          _sop = updatedSop;
          _isLoading = false;
          _isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOP saved successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving SOP: $e')),
          );
        }
      }
    }
  }

  // Add a new method to update SOP locally without saving to Firebase
  Future<void> _updateSOPLocally(SOP updatedSop) async {
    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      // Update the SOP locally only
      await sopService.updateSopLocally(updatedSop);

      setState(() {
        _sop = updatedSop;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating SOP: $e')),
        );
      }
    }
  }

  // Method to handle printing
  void _printSOP() {
    _printService.printSOP(context, _sop);
  }

  // Method to download QR code
  Future<void> _downloadQRCode() async {
    if (kIsWeb) {
      // For web, we create and download a PNG file
      final sopService = Provider.of<SOPService>(context, listen: false);
      final qrBytes =
          await sopService.qrCodeService.generateQRImageBytes(_sop.id, 400);

      if (qrBytes != null) {
        final base64 = base64Encode(qrBytes);
        final dataUrl = 'data:image/png;base64,$base64';

        // Create a link and trigger download
        final anchor = html.AnchorElement(href: dataUrl)
          ..setAttribute(
              'download', '${_sop.title.replaceAll(' ', '_')}_QR_Code.png')
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code downloaded')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to generate QR code'),
              backgroundColor: Colors.red),
        );
      }
    } else {
      // For mobile platforms, we would handle it differently
      // This requires a path_provider package to save to device storage
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('QR Code download only available on web platform')),
      );
    }
  }

  // Method to show QR code in a dialog
  void _showQRCodeDialog(BuildContext context) {
    final sopService = Provider.of<SOPService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOP QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this QR code with the mobile app to view this SOP on a mobile device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  sopService.qrCodeService.generateQRWidget(_sop.id, size: 200),
            ),
            const SizedBox(height: 8),
            Text('SOP ID: ${_sop.id}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Download QR code
              Navigator.pop(context);
              _downloadQRCode();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Check if there are any unsaved changes before navigating back
            if (_isEditing && _hasUnsavedChanges()) {
              _showUnsavedChangesDialog(context);
            } else {
              context.go('/sops');
            }
          },
        ),
        title: _isLoading
            ? const Text('Loading...')
            : Text(_isEditing ? 'Edit SOP' : _sop.title),
        actions: [
          if (!_isLoading) // Only show these actions when not loading
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveSOP();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _isLoading
                ? null
                : () {
                    // Show QR code dialog
                    _showQRCodeDialog(context);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading
                ? null
                : () {
                    // Print functionality
                    _printSOP();
                  },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_pdf') {
                // Export to PDF
                _printSOP();
              } else if (value == 'share') {
                // Share SOP
              } else if (value == 'duplicate') {
                // Duplicate SOP
              } else if (value == 'delete') {
                // Delete SOP
                _showDeleteConfirmationDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'export_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Export to PDF'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share SOP'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'duplicate',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Duplicate'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? _buildSOPEditor()
              : SOPViewer(
                  sop: _sop,
                  onPrint: _printSOP,
                  onDownloadQRCode: _downloadQRCode),
    );
  }

  Widget _buildSOPEditor() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Toolbar for editing SOP
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save SOP'),
                  onPressed: _saveSOP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Step'),
                  onPressed: _showAddStepDialog,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Items',
                  onSelected: (value) {
                    if (value == 'tool') {
                      _showAddItemDialog('Tool', (item) {
                        setState(() {
                          final updatedTools = List<String>.from(_sop.tools)
                            ..add(item);
                          _sop = _sop.copyWith(tools: updatedTools);
                        });
                      });
                    } else if (value == 'safety') {
                      _showAddItemDialog('Safety Requirement', (item) {
                        setState(() {
                          final updatedSafety =
                              List<String>.from(_sop.safetyRequirements)
                                ..add(item);
                          _sop =
                              _sop.copyWith(safetyRequirements: updatedSafety);
                        });
                      });
                    } else if (value == 'caution') {
                      _showAddItemDialog('Caution', (item) {
                        setState(() {
                          final updatedCautions =
                              List<String>.from(_sop.cautions)..add(item);
                          _sop = _sop.copyWith(cautions: updatedCautions);
                        });
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'tool',
                      child: Row(
                        children: [
                          Icon(Icons.build, size: 18),
                          SizedBox(width: 8),
                          Text('Add Tool'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'safety',
                      child: Row(
                        children: [
                          Icon(Icons.security, size: 18),
                          SizedBox(width: 8),
                          Text('Add Safety Requirement'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'caution',
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 18),
                          SizedBox(width: 8),
                          Text('Add Caution'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main content with side navigation
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left navigation bar for steps
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic info section in sidebar
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // Replace this TextFormField with a Category dropdown
                            Consumer<CategoryService>(
                              builder: (context, categoryService, child) {
                                final categories = categoryService.categories;

                                // If there are no categories, display a message instead of dropdown
                                if (categories.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning,
                                                size: 16, color: Colors.orange),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'No categories defined. Please add categories in Settings.',
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                context.go('/settings');
                                              },
                                              child:
                                                  const Text('Go to Settings'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _sop.categoryId.isNotEmpty &&
                                          categories.any(
                                              (c) => c.id == _sop.categoryId)
                                      ? _sop.categoryId
                                      : null,
                                  items: categories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category.id,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                  category.color),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(category.name),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a category';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _sop = _sop.copyWith(categoryId: value);

                                        // Update categoryName as well
                                        final category = categoryService
                                            .getCategoryById(value);
                                        if (category != null) {
                                          _sop = _sop.copyWith(
                                              categoryName: category.name);
                                        }
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Steps header with add button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Steps',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, size: 20),
                              tooltip: 'Add Step',
                              onPressed: _showAddStepDialog,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),

                      // Steps list
                      Expanded(
                        child: _sop.steps.isEmpty
                            ? Center(
                                child: Text(
                                  'No steps yet.\nClick + to add steps.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.only(top: 4),
                                itemCount: _sop.steps.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (oldIndex < newIndex) {
                                      newIndex -= 1;
                                    }
                                    final SOPStep item =
                                        _sop.steps.removeAt(oldIndex);
                                    _sop.steps.insert(newIndex, item);
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final step = _sop.steps[index];
                                  return Padding(
                                    key: Key(step.id),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 2.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          child: Text('${index + 1}'),
                                        ),
                                        title: Text(
                                          step.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _showEditStepDialog(
                                                      step, index),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () {
                                                setState(() {
                                                  final updatedSteps =
                                                      List<SOPStep>.from(
                                                          _sop.steps)
                                                        ..removeAt(index);
                                                  _sop = _sop.copyWith(
                                                      steps: updatedSteps);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            _showEditStepDialog(step, index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: DefaultTabController(
                    length: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          tabs: const [
                            Tab(text: 'Description'),
                            Tab(text: 'Tools'),
                            Tab(text: 'Safety'),
                            Tab(text: 'Cautions'),
                          ],
                          labelColor: Theme.of(context).colorScheme.primary,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Description Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SOP Description',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _descriptionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Description',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 5,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Additional Information',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Revision:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(_sop.revisionNumber
                                                          .toString()),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Created By:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(_sop.createdBy),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Created:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(_formatDate(
                                                          _sop.createdAt)),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Last Updated:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(_formatDate(
                                                          _sop.updatedAt)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_sop.steps.isNotEmpty) ...[
                                      Text(
                                        'Step Preview',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStepPreview(_sop.steps),
                                    ],
                                  ],
                                ),
                              ),

                              // Tools Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tools and Equipment',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Tool'),
                                          onPressed: () {
                                            _showAddItemDialog('Tool', (item) {
                                              setState(() {
                                                final updatedTools =
                                                    List<String>.from(
                                                        _sop.tools)
                                                      ..add(item);
                                                _sop = _sop.copyWith(
                                                    tools: updatedTools);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: _sop.tools.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No tools or equipment specified. Add tools to complete your SOP.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  for (int i = 0;
                                                      i < _sop.tools.length;
                                                      i++)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons.build,
                                                              size: 16),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                              child: Text(_sop
                                                                  .tools[i])),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.delete,
                                                                size: 16),
                                                            onPressed: () {
                                                              setState(() {
                                                                final updatedTools =
                                                                    List<String>.from(
                                                                        _sop
                                                                            .tools)
                                                                      ..removeAt(
                                                                          i);
                                                                _sop = _sop
                                                                    .copyWith(
                                                                        tools:
                                                                            updatedTools);
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Safety Requirements Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Safety Requirements',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Requirement'),
                                          onPressed: () {
                                            _showAddItemDialog(
                                                'Safety Requirement', (item) {
                                              setState(() {
                                                final updatedSafety =
                                                    List<String>.from(
                                                        _sop.safetyRequirements)
                                                      ..add(item);
                                                _sop = _sop.copyWith(
                                                    safetyRequirements:
                                                        updatedSafety);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: _sop.safetyRequirements.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No safety requirements specified. Add safety requirements to ensure safe operation.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  for (int i = 0;
                                                      i <
                                                          _sop.safetyRequirements
                                                              .length;
                                                      i++)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons.security,
                                                              size: 16,
                                                              color:
                                                                  Colors.red),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                              child: Text(
                                                                  _sop.safetyRequirements[
                                                                      i])),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.delete,
                                                                size: 16),
                                                            onPressed: () {
                                                              setState(() {
                                                                final updatedSafety = List<
                                                                        String>.from(
                                                                    _sop.safetyRequirements)
                                                                  ..removeAt(i);
                                                                _sop = _sop.copyWith(
                                                                    safetyRequirements:
                                                                        updatedSafety);
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Cautions Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Cautions and Limitations',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Caution'),
                                          onPressed: () {
                                            _showAddItemDialog('Caution',
                                                (item) {
                                              setState(() {
                                                final updatedCautions =
                                                    List<String>.from(
                                                        _sop.cautions)
                                                      ..add(item);
                                                _sop = _sop.copyWith(
                                                    cautions: updatedCautions);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: _sop.cautions.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No cautions or limitations specified. Add cautions to warn about potential issues.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  for (int i = 0;
                                                      i < _sop.cautions.length;
                                                      i++)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons.warning,
                                                              size: 16,
                                                              color: Colors
                                                                  .orange),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                              child: Text(
                                                                  _sop.cautions[
                                                                      i])),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.delete,
                                                                size: 16),
                                                            onPressed: () {
                                                              setState(() {
                                                                final updatedCautions = List<
                                                                        String>.from(
                                                                    _sop.cautions)
                                                                  ..removeAt(i);
                                                                _sop = _sop.copyWith(
                                                                    cautions:
                                                                        updatedCautions);
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build a preview of the steps in a compact format
  Widget _buildStepPreview(List<SOPStep> steps) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[i].instruction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showEditStepDialog(steps[i], i),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void _showAddStepDialog() {
    final titleController = TextEditingController();
    final instructionController = TextEditingController();
    final helpNoteController = TextEditingController();
    final assignedToController = TextEditingController();
    final estimatedTimeController = TextEditingController();
    String? imageUrl;
    List<String> stepTools = [];
    List<String> stepHazards = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Add New Step',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Two-column layout for main content
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column - Basic info and instruction
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title field
                                    TextField(
                                      controller: titleController,
                                      decoration: InputDecoration(
                                        labelText: 'Step Title',
                                        hintText:
                                            'Enter a clear, descriptive title',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.title,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Instructions field
                                    TextField(
                                      controller: instructionController,
                                      decoration: InputDecoration(
                                        labelText: 'Instructions',
                                        hintText:
                                            'Describe what to do in this step',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        alignLabelWithHint: true,
                                        prefixIcon: Icon(Icons.description,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                      maxLines: 4,
                                    ),
                                    const SizedBox(height: 16),

                                    // Help note field
                                    TextField(
                                      controller: helpNoteController,
                                      decoration: InputDecoration(
                                        labelText: 'Help Note (Optional)',
                                        hintText:
                                            'Add helpful tips or additional information',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.help_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 16),

                                    // Additional details in a row
                                    Row(
                                      children: [
                                        // Assigned to field
                                        Expanded(
                                          child: TextField(
                                            controller: assignedToController,
                                            decoration: InputDecoration(
                                              labelText: 'Assigned To',
                                              hintText: 'Person or role',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                ),
                                              ),
                                              prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                              filled: true,
                                              fillColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLowest,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Estimated time field
                                        Expanded(
                                          child: TextField(
                                            controller: estimatedTimeController,
                                            decoration: InputDecoration(
                                              labelText: 'Est. Time (mins)',
                                              hintText: 'Duration',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                ),
                                              ),
                                              prefixIcon: Icon(
                                                  Icons.timer_outlined,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                              filled: true,
                                              fillColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLowest,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 24),

                              // Right column - Image and attachments
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image section
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      elevation: 0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Step Image',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 12),

                                            // Image preview
                                            if (imageUrl != null) ...[
                                              Container(
                                                height: 160,
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    _buildStepImage(
                                                        imageUrl, context),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.fullscreen,
                                                              color:
                                                                  Colors.white,
                                                              size: 20),
                                                          onPressed: () {
                                                            // Show full-size image dialog
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      Dialog(
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    AppBar(
                                                                      title: const Text(
                                                                          'Image Preview'),
                                                                      leading:
                                                                          IconButton(
                                                                        icon: const Icon(
                                                                            Icons.close),
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.pop(context),
                                                                      ),
                                                                    ),
                                                                    Flexible(
                                                                      child:
                                                                          InteractiveViewer(
                                                                        child: _buildStepImage(
                                                                            imageUrl,
                                                                            context),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          iconSize: 20,
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4),
                                                          constraints:
                                                              const BoxConstraints(),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ] else ...[
                                              Container(
                                                height: 160,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLowest,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.image_outlined,
                                                          size: 40,
                                                          color: Colors.grey),
                                                      SizedBox(height: 8),
                                                      Text('No image selected',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            // Image buttons
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                        Icons.photo_camera,
                                                        size: 18),
                                                    label: Text(imageUrl == null
                                                        ? 'Add Image'
                                                        : 'Change'),
                                                    onPressed: () async {
                                                      final stepId = DateTime
                                                              .now()
                                                          .millisecondsSinceEpoch
                                                          .toString();
                                                      final url =
                                                          await _pickAndUploadImage(
                                                              context,
                                                              _sop.id,
                                                              stepId);
                                                      if (url != null) {
                                                        setState(() {
                                                          imageUrl = url;
                                                        });
                                                      }
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFBB2222),
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 8,
                                                          horizontal: 12),
                                                    ),
                                                  ),
                                                ),
                                                if (imageUrl != null) ...[
                                                  const SizedBox(width: 8),
                                                  OutlinedButton.icon(
                                                    icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18),
                                                    label: const Text('Remove'),
                                                    onPressed: () {
                                                      setState(() {
                                                        imageUrl = null;
                                                      });
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                      side: const BorderSide(
                                                          color: Colors.red),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 8,
                                                          horizontal: 12),
                                                    ),
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
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Tools and hazards sections in tabs
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.3),
                              ),
                            ),
                            elevation: 0,
                            child: Column(
                              children: [
                                DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    children: [
                                      TabBar(
                                        dividerColor: Colors.transparent,
                                        tabs: [
                                          Tab(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.build,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                                const SizedBox(width: 8),
                                                const Text('Tools Needed'),
                                              ],
                                            ),
                                          ),
                                          Tab(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.warning,
                                                    color: Colors.orange),
                                                const SizedBox(width: 8),
                                                const Text(
                                                    'Hazards & Warnings'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        labelColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        unselectedLabelColor: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        indicatorColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      Container(
                                        height: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      ),
                                      SizedBox(
                                        height: 200,
                                        child: TabBarView(
                                          children: [
                                            // Tools tab
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Step-Specific Tools',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium,
                                                      ),
                                                      ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons.add,
                                                            size: 18),
                                                        label: const Text(
                                                            'Add Tool'),
                                                        onPressed: () {
                                                          _showAddItemToListDialog(
                                                              'Tool', (tool) {
                                                            setState(() {
                                                              stepTools
                                                                  .add(tool);
                                                            });
                                                          });
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          foregroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                    child: stepTools.isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              'No tools specified for this step',
                                                              style: TextStyle(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .outline),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            itemCount: stepTools
                                                                .length,
                                                            separatorBuilder: (_,
                                                                    __) =>
                                                                const Divider(
                                                                    height: 1),
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              return ListTile(
                                                                dense: true,
                                                                leading:
                                                                    const Icon(
                                                                        Icons
                                                                            .build,
                                                                        size:
                                                                            20),
                                                                title: Text(
                                                                    stepTools[
                                                                        index]),
                                                                trailing:
                                                                    IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .delete_outline,
                                                                      size: 20),
                                                                  onPressed:
                                                                      () {
                                                                    setState(
                                                                        () {
                                                                      stepTools
                                                                          .removeAt(
                                                                              index);
                                                                    });
                                                                  },
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Hazards tab
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Step-Specific Hazards',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium,
                                                      ),
                                                      FilledButton.tonalIcon(
                                                        icon: const Icon(
                                                            Icons.add,
                                                            size: 18),
                                                        label: const Text(
                                                            'Add Hazard'),
                                                        onPressed: () {
                                                          _showAddItemToListDialog(
                                                              'Hazard',
                                                              (hazard) {
                                                            setState(() {
                                                              stepHazards
                                                                  .add(hazard);
                                                            });
                                                          });
                                                        },
                                                        style: FilledButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.orange
                                                                  .shade100,
                                                          foregroundColor:
                                                              Colors.orange
                                                                  .shade900,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                    child: stepHazards.isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              'No hazards specified for this step',
                                                              style: TextStyle(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .outline),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            itemCount:
                                                                stepHazards
                                                                    .length,
                                                            separatorBuilder: (_,
                                                                    __) =>
                                                                const Divider(
                                                                    height: 1),
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              return ListTile(
                                                                dense: true,
                                                                leading: const Icon(
                                                                    Icons
                                                                        .warning,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .orange),
                                                                title: Text(
                                                                    stepHazards[
                                                                        index]),
                                                                trailing:
                                                                    IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .delete_outline,
                                                                      size: 20),
                                                                  onPressed:
                                                                      () {
                                                                    setState(
                                                                        () {
                                                                      stepHazards
                                                                          .removeAt(
                                                                              index);
                                                                    });
                                                                  },
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

                // Bottom action buttons
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Step',
                            style: TextStyle(fontSize: 14)),
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              instructionController.text.isNotEmpty) {
                            final newStep = SOPStep(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              title: titleController.text,
                              instruction: instructionController.text,
                              imageUrl: imageUrl,
                              helpNote: helpNoteController.text.isNotEmpty
                                  ? helpNoteController.text
                                  : null,
                              assignedTo: assignedToController.text.isNotEmpty
                                  ? assignedToController.text
                                  : null,
                              estimatedTime: estimatedTimeController
                                      .text.isNotEmpty
                                  ? int.tryParse(estimatedTimeController.text)
                                  : null,
                              stepTools: stepTools,
                              stepHazards: stepHazards,
                            );

                            final updatedSteps = List<SOPStep>.from(_sop.steps)
                              ..add(newStep);
                            final updatedSop =
                                _sop.copyWith(steps: updatedSteps);

                            // Update locally without saving to Firebase
                            _updateSOPLocally(updatedSop);

                            Navigator.pop(context);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFBB2222),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
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

  // Helper method to add an item to a list
  void _showAddItemToListDialog(String itemType, Function(String) onAdd) {
    final itemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $itemType'),
        content: TextField(
          controller: itemController,
          decoration: InputDecoration(
            labelText: itemType,
            border: OutlineInputBorder(),
            hintText: 'Enter $itemType name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (itemController.text.isNotEmpty) {
                onAdd(itemController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(String itemType, Function(String) onAdd) {
    final itemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $itemType'),
        content: TextField(
          controller: itemController,
          decoration: InputDecoration(
            labelText: itemType,
            border: OutlineInputBorder(),
            hintText: 'Enter $itemType name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (itemController.text.isNotEmpty) {
                onAdd(itemController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SOP'),
        content: const Text(
            'Are you sure you want to delete this SOP? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              try {
                final sopService =
                    Provider.of<SOPService>(context, listen: false);
                await sopService.deleteSop(_sop.id);

                // Explicitly refresh the SOP list
                await sopService.refreshSOPs();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOP deleted successfully')),
                  );
                  context.go('/sops');
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting SOP: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditStepDialog(SOPStep step, int index) {
    final titleController = TextEditingController(text: step.title);
    final instructionController = TextEditingController(text: step.instruction);
    final helpNoteController = TextEditingController(text: step.helpNote ?? '');
    final assignedToController =
        TextEditingController(text: step.assignedTo ?? '');
    final estimatedTimeController = TextEditingController(
      text: step.estimatedTime != null ? step.estimatedTime.toString() : '',
    );
    String? imageUrl = step.imageUrl;
    List<String> stepTools = List<String>.from(step.stepTools);
    List<String> stepHazards = List<String>.from(step.stepHazards);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog header with step number and actions
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: Text('${index + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Edit Step',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Two-column layout for main content
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column - Basic info and instruction
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title field
                                    TextField(
                                      controller: titleController,
                                      decoration: InputDecoration(
                                        labelText: 'Step Title',
                                        hintText:
                                            'Enter a clear, descriptive title',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.title,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Instructions field
                                    TextField(
                                      controller: instructionController,
                                      decoration: InputDecoration(
                                        labelText: 'Instructions',
                                        hintText:
                                            'Describe what to do in this step',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        alignLabelWithHint: true,
                                        prefixIcon: Icon(Icons.description,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                      maxLines: 4,
                                    ),
                                    const SizedBox(height: 16),

                                    // Help note field
                                    TextField(
                                      controller: helpNoteController,
                                      decoration: InputDecoration(
                                        labelText: 'Help Note (Optional)',
                                        hintText:
                                            'Add helpful tips or additional information',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.help_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 16),

                                    // Additional details in a row
                                    Row(
                                      children: [
                                        // Assigned to field
                                        Expanded(
                                          child: TextField(
                                            controller: assignedToController,
                                            decoration: InputDecoration(
                                              labelText: 'Assigned To',
                                              hintText: 'Person or role',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                ),
                                              ),
                                              prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                              filled: true,
                                              fillColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLowest,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Estimated time field
                                        Expanded(
                                          child: TextField(
                                            controller: estimatedTimeController,
                                            decoration: InputDecoration(
                                              labelText: 'Est. Time (mins)',
                                              hintText: 'Duration',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                ),
                                              ),
                                              prefixIcon: Icon(
                                                  Icons.timer_outlined,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                              filled: true,
                                              fillColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLowest,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 24),

                              // Right column - Image and attachments
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image section
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      elevation: 0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Step Image',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 12),

                                            // Image preview
                                            if (imageUrl != null) ...[
                                              Container(
                                                height: 160,
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    _buildStepImage(
                                                        imageUrl, context),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.fullscreen,
                                                              color:
                                                                  Colors.white,
                                                              size: 20),
                                                          onPressed: () {
                                                            // Show full-size image dialog
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      Dialog(
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    AppBar(
                                                                      title: const Text(
                                                                          'Image Preview'),
                                                                      leading:
                                                                          IconButton(
                                                                        icon: const Icon(
                                                                            Icons.close),
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.pop(context),
                                                                      ),
                                                                    ),
                                                                    Flexible(
                                                                      child:
                                                                          InteractiveViewer(
                                                                        child: _buildStepImage(
                                                                            imageUrl,
                                                                            context),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          iconSize: 20,
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4),
                                                          constraints:
                                                              const BoxConstraints(),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ] else ...[
                                              Container(
                                                height: 160,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLowest,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.image_outlined,
                                                          size: 40,
                                                          color: Colors.grey),
                                                      SizedBox(height: 8),
                                                      Text('No image selected',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            // Image buttons
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                        Icons.photo_camera,
                                                        size: 18),
                                                    label: Text(imageUrl == null
                                                        ? 'Add Image'
                                                        : 'Change'),
                                                    onPressed: () async {
                                                      final stepId = DateTime
                                                              .now()
                                                          .millisecondsSinceEpoch
                                                          .toString();
                                                      final url =
                                                          await _pickAndUploadImage(
                                                              context,
                                                              _sop.id,
                                                              stepId);
                                                      if (url != null) {
                                                        setState(() {
                                                          imageUrl = url;
                                                        });
                                                      }
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFBB2222),
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 8,
                                                          horizontal: 12),
                                                    ),
                                                  ),
                                                ),
                                                if (imageUrl != null) ...[
                                                  const SizedBox(width: 8),
                                                  OutlinedButton.icon(
                                                    icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18),
                                                    label: const Text('Remove'),
                                                    onPressed: () {
                                                      setState(() {
                                                        imageUrl = null;
                                                      });
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                      side: const BorderSide(
                                                          color: Colors.red),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 8,
                                                          horizontal: 12),
                                                    ),
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
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Tools and hazards sections in tabs
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.3),
                              ),
                            ),
                            elevation: 0,
                            child: Column(
                              children: [
                                DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    children: [
                                      TabBar(
                                        dividerColor: Colors.transparent,
                                        tabs: [
                                          Tab(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.build,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                                const SizedBox(width: 8),
                                                const Text('Tools Needed'),
                                              ],
                                            ),
                                          ),
                                          Tab(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.warning,
                                                    color: Colors.orange),
                                                const SizedBox(width: 8),
                                                const Text(
                                                    'Hazards & Warnings'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        labelColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        unselectedLabelColor: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        indicatorColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      Container(
                                        height: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      ),
                                      SizedBox(
                                        height: 200,
                                        child: TabBarView(
                                          children: [
                                            // Tools tab
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Step-Specific Tools',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium,
                                                      ),
                                                      ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons.add,
                                                            size: 18),
                                                        label: const Text(
                                                            'Add Tool'),
                                                        onPressed: () {
                                                          _showAddItemToListDialog(
                                                              'Tool', (tool) {
                                                            setState(() {
                                                              stepTools
                                                                  .add(tool);
                                                            });
                                                          });
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          foregroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                    child: stepTools.isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              'No tools specified for this step',
                                                              style: TextStyle(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .outline),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            itemCount: stepTools
                                                                .length,
                                                            separatorBuilder: (_,
                                                                    __) =>
                                                                const Divider(
                                                                    height: 1),
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              return ListTile(
                                                                dense: true,
                                                                leading:
                                                                    const Icon(
                                                                        Icons
                                                                            .build,
                                                                        size:
                                                                            20),
                                                                title: Text(
                                                                    stepTools[
                                                                        index]),
                                                                trailing:
                                                                    IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .delete_outline,
                                                                      size: 20),
                                                                  onPressed:
                                                                      () {
                                                                    setState(
                                                                        () {
                                                                      stepTools
                                                                          .removeAt(
                                                                              index);
                                                                    });
                                                                  },
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Hazards tab
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Step-Specific Hazards',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium,
                                                      ),
                                                      FilledButton.tonalIcon(
                                                        icon: const Icon(
                                                            Icons.add,
                                                            size: 18),
                                                        label: const Text(
                                                            'Add Hazard'),
                                                        onPressed: () {
                                                          _showAddItemToListDialog(
                                                              'Hazard',
                                                              (hazard) {
                                                            setState(() {
                                                              stepHazards
                                                                  .add(hazard);
                                                            });
                                                          });
                                                        },
                                                        style: FilledButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.orange
                                                                  .shade100,
                                                          foregroundColor:
                                                              Colors.orange
                                                                  .shade900,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                    child: stepHazards.isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              'No hazards specified for this step',
                                                              style: TextStyle(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .outline),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            itemCount:
                                                                stepHazards
                                                                    .length,
                                                            separatorBuilder: (_,
                                                                    __) =>
                                                                const Divider(
                                                                    height: 1),
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              return ListTile(
                                                                dense: true,
                                                                leading: const Icon(
                                                                    Icons
                                                                        .warning,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .orange),
                                                                title: Text(
                                                                    stepHazards[
                                                                        index]),
                                                                trailing:
                                                                    IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .delete_outline,
                                                                      size: 20),
                                                                  onPressed:
                                                                      () {
                                                                    setState(
                                                                        () {
                                                                      stepHazards
                                                                          .removeAt(
                                                                              index);
                                                                    });
                                                                  },
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

                // Bottom action buttons
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save Changes',
                            style: TextStyle(fontSize: 14)),
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              instructionController.text.isNotEmpty) {
                            final updatedStep = step.copyWith(
                              title: titleController.text,
                              instruction: instructionController.text,
                              imageUrl: imageUrl,
                              helpNote: helpNoteController.text.isNotEmpty
                                  ? helpNoteController.text
                                  : null,
                              assignedTo: assignedToController.text.isNotEmpty
                                  ? assignedToController.text
                                  : null,
                              estimatedTime: estimatedTimeController
                                      .text.isNotEmpty
                                  ? int.tryParse(estimatedTimeController.text)
                                  : null,
                              stepTools: stepTools,
                              stepHazards: stepHazards,
                            );

                            final updatedSteps = List<SOPStep>.from(_sop.steps);
                            updatedSteps[index] = updatedStep;
                            final updatedSop =
                                _sop.copyWith(steps: updatedSteps);

                            // Update locally without saving to Firebase
                            _updateSOPLocally(updatedSop);

                            Navigator.pop(context);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFBB2222),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
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

  Widget _buildStepImage(String? imageUrl, BuildContext context) {
    if (imageUrl == null) return Container();

    // Common image container with constraints
    Widget buildConstrainedImage(Widget imageWidget) {
      return Container(
        constraints: const BoxConstraints(
          maxHeight: 200,
          minHeight: 120,
        ),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageWidget,
      );
    }

    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return buildConstrainedImage(
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImageError(),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              return frame != null ? child : _buildImageLoading();
            },
          ),
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return buildConstrainedImage(
        Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            return frame != null ? child : _buildImageLoading();
          },
        ),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return buildConstrainedImage(
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildImageLoading(
              progress: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            );
          },
        ),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 36,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Image could not be loaded',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLoading({double? progress}) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress != null)
              CircularProgressIndicator(value: progress)
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Loading image...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAndUploadImage(
      BuildContext context, String sopId, String stepId) async {
    try {
      // Use file picker to pick an image
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return null;
      }

      final PlatformFile file = result.files.first;
      final sopService = Provider.of<SOPService>(context, listen: false);

      // If we're in local data mode, just create a data URL
      if (sopService.usingLocalData && file.bytes != null) {
        final base64 = base64Encode(file.bytes!);
        final extension = file.extension?.toLowerCase() ?? 'jpg';
        final dataUrl = 'data:image/$extension;base64,$base64';
        return dataUrl;
      }

      // For web, handle file.bytes
      if (file.bytes != null) {
        try {
          // On web, we'll use a workaround since we can't directly create a File
          // Instead, we'll create a data URL and pass it to the service
          final base64 = base64Encode(file.bytes!);
          final extension = file.extension?.toLowerCase() ?? 'jpg';
          final dataUrl = 'data:image/$extension;base64,$base64';

          if (kIsWeb) {
            // In web mode, we'll use this directly
            return dataUrl;
          } else {
            // This is a fallback that shouldn't happen - web detected but not using kIsWeb
            return 'assets/images/placeholder.png';
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing web image: $e');
          }
          // Return a placeholder as fallback
          return 'assets/images/placeholder.png';
        }
      }
      // For mobile platforms with file.path
      else if (file.path != null) {
        try {
          final uploadedUrl =
              await sopService.uploadImage(File(file.path!), sopId, stepId);
          return uploadedUrl;
        } catch (e) {
          if (kDebugMode) {
            print('Error uploading image from path: $e');
          }
          return 'assets/images/placeholder.png';
        }
      }

      // If we reach here, something went wrong but we have a fallback
      return 'assets/images/placeholder.png';
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

  void _showUnsavedChangesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to save before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              // Discard changes and navigate back
              Navigator.pop(context);
              context.go('/sops');
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              // Close dialog and stay on the editor page
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save changes and navigate back
              Navigator.pop(context);
              await _saveSOP();
              if (mounted) {
                context.go('/sops');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _hasUnsavedChanges() {
    return _titleController.text != _sop.title ||
        _descriptionController.text != _sop.description;
  }

  // Color utility method for category colors
  Color _getCategoryColor(String? colorString) {
    if (colorString == null || !colorString.startsWith('#')) {
      return Colors.grey; // Default color
    }

    try {
      // Parse hex color string (e.g., "#FF0000" for red)
      String hex = colorString.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha if not present
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey; // Return default if parsing fails
    }
  }
}
