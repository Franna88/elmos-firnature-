import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
// Conditionally import dart:html for web and stub for other platforms
import '../../../utils/html_stub.dart' if (dart.library.html) 'dart:html'
    as html;
import '../../../data/services/print_service.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../data/models/category_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/sop_viewer.dart';
import '../../widgets/cross_platform_image.dart'; // Import CrossPlatformImage
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

class SOPEditorScreen extends StatefulWidget {
  final String sopId;
  final int? initialStepIndex;

  const SOPEditorScreen({
    super.key,
    required this.sopId,
    this.initialStepIndex,
  });

  @override
  State<SOPEditorScreen> createState() => _SOPEditorScreenState();
}

class _SOPEditorScreenState extends State<SOPEditorScreen>
    with TickerProviderStateMixin {
  late SOP _sop;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _printService = PrintService();
  final uuid = Uuid(); // Initialize Uuid instance here
  final _storage = FirebaseStorage.instance;

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController
      _youtubeUrlController; // Added for YouTube URL support

  late TabController _tabController;
  List<Widget> _tabs = [
    const Tab(text: 'Basic Info'),
    const Tab(text: 'Description'),
    const Tab(text: 'Tools'),
    const Tab(text: 'Safety'),
    const Tab(text: 'Cautions'),
    const Tab(text: 'Steps'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSOP().then((_) {
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
      );

      // If we have a category, update the tabs accordingly
      if (_sop.categoryId.isNotEmpty) {
        final categoryService =
            Provider.of<CategoryService>(context, listen: false);
        final category = categoryService.getCategoryById(_sop.categoryId);
        if (category != null) {
          _updateVisibleTabsForCategory(category);
        }
      }

      // If initialStepIndex is provided, navigate to the Steps tab and open the step editor
      if (widget.initialStepIndex != null &&
          widget.initialStepIndex! >= 0 &&
          _sop.steps.isNotEmpty &&
          widget.initialStepIndex! < _sop.steps.length) {
        // Select the Steps tab (index 5)
        _tabController.animateTo(5);

        // Schedule the step editor to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final step = _sop.steps[widget.initialStepIndex!];
          _showEditStepDialog(step, widget.initialStepIndex!);
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(
      () {
        _isLoading = true;
      },
    );

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
              _youtubeUrlController = TextEditingController();
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
      _youtubeUrlController =
          TextEditingController(text: _sop.youtubeUrl ?? '');
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
          thumbnailUrl: _sop.thumbnailUrl, // Preserve the thumbnail URL
          youtubeUrl: _youtubeUrlController.text.isEmpty
              ? null
              : _youtubeUrlController.text, // Save YouTube URL
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
  Future<void> _updateSOPLocally([SOP? updatedSop]) async {
    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      // Use passed SOP if available, otherwise create a new one with current values
      final newSop = updatedSop ??
          _sop.copyWith(
            title: _titleController.text,
            description: _descriptionController.text,
            youtubeUrl: _youtubeUrlController.text.isEmpty
                ? null
                : _youtubeUrlController.text,
          );

      // Update the SOP locally only
      await sopService.updateSopLocally(newSop);

      setState(() {
        _sop = newSop;
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
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    _printService.printSOP(context, _sop, categoryService);
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
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: Color(0xFFBB2222)),
            const SizedBox(width: 8),
            const Text('SOP QR Code'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This QR code provides direct access to this SOP when scanned.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'When team members scan this with the mobile app, they will immediately access this exact SOP, allowing them to follow steps and procedures on-site.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: sopService.qrCodeService
                    .generateQRWidget(_sop.id, size: 200),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SOP ID: ${_sop.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recommended Uses:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.print, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Print and attach to relevant equipment or workstations'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.book, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Add to procedure manuals and documentation'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.folder, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Include in training materials for quick reference'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download for Printing'),
            onPressed: () {
              // Download QR code
              Navigator.pop(context);
              _downloadQRCode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBB2222),
              foregroundColor: Colors.white,
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
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
            : Row(
                children: [
                  Text(_isEditing ? 'Edit SOP' : _sop.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (!_isLoading && !_isEditing)
                    Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rev ${_sop.revisionNumber}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
        actions: [
          if (!_isLoading) // Only show these actions when not loading
            IconButton(
              icon:
                  Icon(_isEditing ? Icons.save_outlined : Icons.edit_outlined),
              tooltip: _isEditing ? 'Save SOP' : 'Edit SOP',
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
            icon: const Icon(Icons.qr_code_outlined),
            tooltip: 'Show QR Code',
            onPressed: _isLoading
                ? null
                : () {
                    // Show QR code dialog
                    _showQRCodeDialog(context);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print SOP',
            onPressed: _isLoading
                ? null
                : () {
                    // Print functionality
                    _printSOP();
                  },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
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
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Export to PDF'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('Share SOP'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'duplicate',
                child: ListTile(
                  leading: Icon(Icons.copy_outlined),
                  title: Text('Duplicate'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outlined, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
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
                  onDownloadQRCode: _downloadQRCode,
                  onEditStep: _editStepFromViewer,
                ),
    );
  }

  Widget _buildSOPEditor() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Main toolbar with edit actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                // Edit panel label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note,
                          size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Editing',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // SOP title indicator
                Expanded(
                  child: Text(
                    _sop.title.isNotEmpty ? _sop.title : 'New SOP',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),

                // Add step button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Step'),
                  onPressed: _showAddStepDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),

                // Add items dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 16),
                        const SizedBox(width: 6),
                        const Text('Add Items',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                    tooltip: 'Add Items',
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.borderColor),
                    ),
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
                            _sop = _sop.copyWith(
                                safetyRequirements: updatedSafety);
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
                      PopupMenuItem(
                        value: 'tool',
                        child: Row(
                          children: [
                            Icon(Icons.build,
                                size: 18, color: AppColors.primaryBlue),
                            const SizedBox(width: 12),
                            const Text('Add Tool'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'safety',
                        child: Row(
                          children: [
                            Icon(Icons.security,
                                size: 18, color: AppColors.greenAccent),
                            const SizedBox(width: 12),
                            const Text('Add Safety Requirement'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'caution',
                        child: Row(
                          children: [
                            Icon(Icons.warning,
                                size: 18, color: AppColors.orangeAccent),
                            const SizedBox(width: 12),
                            const Text('Add Caution'),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  width: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      right: BorderSide(
                          color: AppColors.borderColor.withOpacity(0.5)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact steps header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.borderColor.withOpacity(0.5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.format_list_numbered,
                                size: 14,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Steps (${_sop.steps.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outlined,
                                color: AppColors.accentTeal,
                                size: 18,
                              ),
                              tooltip: 'Add Step',
                              onPressed: _showAddStepDialog,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),

                      // Steps list
                      Expanded(
                        child: _sop.steps.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_task_outlined,
                                        size: 40,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No steps added yet',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click + to add your first step',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Step'),
                                      onPressed: _showAddStepDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accentTeal,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.only(top: 8),
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
                                  return Card(
                                    key: Key(step.id),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(
                                        color: AppColors.borderColor
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: AppColors.primaryBlue,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                            tileColor: Colors.white,
                                            dense: true,
                                            leading: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              step.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                            subtitle: Text(
                                              step.instruction,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (step.estimatedTime != null)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 1),
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .primaryBlue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      _formatTime(
                                                          step.estimatedTime!),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .primaryBlue,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                if (step.imageUrl != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 2),
                                                    padding:
                                                        const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .accentTeal
                                                          .withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.photo_outlined,
                                                      size: 10,
                                                      color:
                                                          AppColors.accentTeal,
                                                    ),
                                                  ),
                                                SizedBox(
                                                  width: 40,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      InkWell(
                                                        onTap: () =>
                                                            _showEditStepDialog(
                                                                step, index),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4.0),
                                                          child: Icon(
                                                            Icons.edit_outlined,
                                                            size: 14,
                                                            color: AppColors
                                                                .primaryBlue,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            final updatedSteps =
                                                                List<SOPStep>.from(
                                                                    _sop.steps)
                                                                  ..removeAt(
                                                                      index);
                                                            _sop = _sop.copyWith(
                                                                steps:
                                                                    updatedSteps);
                                                          });
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4.0),
                                                          child: Icon(
                                                            Icons
                                                                .delete_outlined,
                                                            size: 14,
                                                            color: Colors
                                                                .red.shade400,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () => _showEditStepDialog(
                                                step, index),
                                          ),
                                          if (step.imageUrl != null)
                                            Container(
                                              height: 120,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    color: AppColors.borderColor
                                                        .withOpacity(0.5),
                                                  ),
                                                ),
                                              ),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CrossPlatformImage(
                                                    key: ValueKey(
                                                        'step-nav-image-${step.imageUrl}'),
                                                    imageUrl: step.imageUrl!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                  Positioned(
                                                    bottom: 8,
                                                    right: 8,
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _showFullSizeImageDialog(
                                                              context,
                                                              step.imageUrl!),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(6),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.4),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Icon(
                                                          Icons.fullscreen,
                                                          color: Colors.white,
                                                          size: 16,
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
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom section header
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'SOP Contents',
                                  style: TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _tabController.index == 0
                                        ? 'Editing Basic Info'
                                        : (_tabController.index == 5
                                            ? 'Editing Steps'
                                            : 'Editing Details'),
                                    style: TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      size: 14,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Complete all required sections',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // Tabs navigation
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(color: AppColors.borderColor),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          tabs: _tabs,
                          isScrollable: true,
                          labelColor: AppColors.primaryBlue,
                          unselectedLabelColor: AppColors.textMedium,
                          indicatorColor: AppColors.primaryBlue,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          dividerColor: Colors.transparent,
                        ),
                      ),

                      // Tab content area with shadow
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: TabBarView(
                              controller: _tabController,
                              children: _buildTabViews(),
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
    final estimatedHoursController = TextEditingController(text: '0');
    final estimatedMinutesController = TextEditingController(text: '0');
    final estimatedSecondsController = TextEditingController(text: '0');

    String? imageUrl;
    bool isUploadingImage = false;
    String? tempImageUrl; // Temporary URL for preview during upload
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
                        child: Text('${_sop.steps.length + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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

                                        // Estimated time fields (hours, minutes, seconds)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Estimated Time',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // Hours
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedHoursController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Hours',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Minutes
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedMinutesController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Mins',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Seconds
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedSecondsController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Secs',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
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
                                            if (imageUrl != null ||
                                                tempImageUrl != null) ...[
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
                                                        tempImageUrl ??
                                                            imageUrl!,
                                                        context),
                                                    if (isUploadingImage)
                                                      Container(
                                                        color: Colors.black
                                                            .withOpacity(0.5),
                                                        child: const Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              CircularProgressIndicator(
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                              ),
                                                              SizedBox(
                                                                  height: 8),
                                                              Text(
                                                                'Uploading...',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
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
                                                            _showFullSizeImageDialog(
                                                                context,
                                                                tempImageUrl ??
                                                                    imageUrl!);
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
                                                child: isUploadingImage
                                                    ? const Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            CircularProgressIndicator(),
                                                            SizedBox(height: 8),
                                                            Text(
                                                                'Uploading image...',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey)),
                                                          ],
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .image_outlined,
                                                                size: 40,
                                                                color: Colors
                                                                    .grey),
                                                            SizedBox(height: 8),
                                                            Text(
                                                                'No image selected',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey)),
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
                                                    icon: isUploadingImage
                                                        ? const SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                          Color>(
                                                                      Colors
                                                                          .white),
                                                            ),
                                                          )
                                                        : const Icon(
                                                            Icons.photo_camera,
                                                            size: 18),
                                                    label: Text(imageUrl == null
                                                        ? 'Add Image'
                                                        : 'Change'),
                                                    onPressed: isUploadingImage
                                                        ? null
                                                        : () async {
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
                                                    onPressed: isUploadingImage
                                                        ? null
                                                        : () {
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
                          // Validate required fields
                          if (titleController.text.trim().isEmpty ||
                              instructionController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please fill in title and instructions'),
                              ),
                            );
                            return;
                          }

                          // Calculate total time in seconds
                          int hours = int.tryParse(
                                  estimatedHoursController.text.trim()) ??
                              0;
                          int minutes = int.tryParse(
                                  estimatedMinutesController.text.trim()) ??
                              0;
                          int seconds = int.tryParse(
                                  estimatedSecondsController.text.trim()) ??
                              0;

                          int totalSeconds =
                              (hours * 3600) + (minutes * 60) + seconds;

                          if (kDebugMode) {
                            print('Step image URL: $imageUrl');
                          }

                          // Create the new step
                          final newStep = SOPStep(
                            id: uuid.v4(),
                            title: titleController.text.trim(),
                            instruction: instructionController.text.trim(),
                            imageUrl: imageUrl,
                            helpNote: helpNoteController.text.trim().isNotEmpty
                                ? helpNoteController.text.trim()
                                : null,
                            assignedTo:
                                assignedToController.text.trim().isNotEmpty
                                    ? assignedToController.text.trim()
                                    : null,
                            estimatedTime:
                                totalSeconds > 0 ? totalSeconds : null,
                            stepTools: stepTools,
                            stepHazards: stepHazards,
                          );

                          if (kDebugMode) {
                            print(
                                'Created step with ID: ${newStep.id}, Image URL: ${newStep.imageUrl}');
                            print('Step tools: ${newStep.stepTools}');
                            print('Step hazards: ${newStep.stepHazards}');
                          }

                          // Add the step to the SOP
                          final updatedSteps = List<SOPStep>.from(_sop.steps)
                            ..add(newStep);
                          final updatedSop = _sop.copyWith(steps: updatedSteps);

                          // Update locally without saving to Firebase
                          _updateSOPLocally(updatedSop);

                          if (kDebugMode) {
                            print(
                                'SOP updated locally with ${updatedSop.steps.length} steps');
                            print(
                                'Last step image URL: ${updatedSop.steps.last.imageUrl}');
                          }

                          Navigator.pop(context);
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

    // Replace single time controller with three separate controllers & initialize them
    final estimatedHoursController = TextEditingController(text: '0');
    final estimatedMinutesController = TextEditingController(text: '0');
    final estimatedSecondsController = TextEditingController(text: '0');

    // Parse existing time in seconds into hours, minutes, seconds
    if (step.estimatedTime != null) {
      int totalSeconds = step.estimatedTime!;
      int hours = totalSeconds ~/ 3600;
      int minutes = (totalSeconds % 3600) ~/ 60;
      int seconds = totalSeconds % 60;

      estimatedHoursController.text = hours.toString();
      estimatedMinutesController.text = minutes.toString();
      estimatedSecondsController.text = seconds.toString();
    }

    String? imageUrl = step.imageUrl;
    bool isUploadingImage = false;
    String? tempImageUrl; // Temporary URL for preview during upload
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

                                        // Estimated time fields (hours, minutes, seconds)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Estimated Time',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // Hours
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedHoursController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Hours',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Minutes
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedMinutesController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Mins',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Seconds
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          estimatedSecondsController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Secs',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          borderSide:
                                                              BorderSide(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12),
                                                        filled: true,
                                                        fillColor: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .surfaceContainerLowest,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
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
                                            if (imageUrl != null ||
                                                tempImageUrl != null) ...[
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
                                                        tempImageUrl ??
                                                            imageUrl!,
                                                        context),
                                                    if (isUploadingImage)
                                                      Container(
                                                        color: Colors.black
                                                            .withOpacity(0.5),
                                                        child: const Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              CircularProgressIndicator(
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                              ),
                                                              SizedBox(
                                                                  height: 8),
                                                              Text(
                                                                'Uploading...',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
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
                                                            _showFullSizeImageDialog(
                                                                context,
                                                                tempImageUrl ??
                                                                    imageUrl!);
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
                                                child: isUploadingImage
                                                    ? const Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            CircularProgressIndicator(),
                                                            SizedBox(height: 8),
                                                            Text(
                                                                'Uploading image...',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey)),
                                                          ],
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .image_outlined,
                                                                size: 40,
                                                                color: Colors
                                                                    .grey),
                                                            SizedBox(height: 8),
                                                            Text(
                                                                'No image selected',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey)),
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
                                                    icon: isUploadingImage
                                                        ? const SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                          Color>(
                                                                      Colors
                                                                          .white),
                                                            ),
                                                          )
                                                        : const Icon(
                                                            Icons.photo_camera,
                                                            size: 18),
                                                    label: Text(imageUrl == null
                                                        ? 'Add Image'
                                                        : 'Change'),
                                                    onPressed: isUploadingImage
                                                        ? null
                                                        : () async {
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
                                                    onPressed: isUploadingImage
                                                        ? null
                                                        : () {
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
                              estimatedTime: _calculateTotalSeconds(
                                estimatedHoursController.text,
                                estimatedMinutesController.text,
                                estimatedSecondsController.text,
                              ),
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

    // Common image container with constraints, adjusted for mobile
    Widget buildConstrainedImage(Widget imageWidget) {
      return GestureDetector(
        onTap: () {
          // Show full-size image dialog optimized for mobile when tapped
          _showFullSizeImageDialog(context, imageUrl);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            minHeight: 100,
            maxHeight: 300,
          ),
          child: imageWidget,
        ),
      );
    }

    // Use CrossPlatformImage for all image types
    return buildConstrainedImage(
      CrossPlatformImage(
        imageUrl: imageUrl,
        width: 500,
        height: 300,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Image could not be loaded',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageLoading({double? progress}) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading image...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickAndUploadImage(
      BuildContext context, String sopId, String stepId) async {
    try {
      // Use ImagePicker for web
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final sopService = Provider.of<SOPService>(context, listen: false);

        // For web, encode as a data URL
        if (kIsWeb) {
          final String imageUrl =
              'data:image/jpeg;base64,${base64Encode(imageBytes)}';

          // Upload the data URL to Firebase Storage
          // This will ensure the URL is stored even for web
          return await sopService.uploadImageFromDataUrl(
              imageUrl, sopId, stepId);
        }
        // For native platforms - convert to a data URL and upload to Firebase Storage
        else {
          // Convert to data URL format
          final String dataUrl =
              'data:image/jpeg;base64,${base64Encode(imageBytes)}';

          // Use the SOP service to upload the image to Firebase Storage
          final String? uploadedUrl =
              await sopService.uploadImageFromDataUrl(dataUrl, sopId, stepId);

          if (kDebugMode) {
            print('Native image uploaded successfully: $uploadedUrl');
          }

          return uploadedUrl;
        }
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

  // Helper method to calculate total seconds from hours, minutes, seconds
  int? _calculateTotalSeconds(
      String hoursStr, String minutesStr, String secondsStr) {
    try {
      int hours = int.tryParse(hoursStr) ?? 0;
      int minutes = int.tryParse(minutesStr) ?? 0;
      int seconds = int.tryParse(secondsStr) ?? 0;

      // Convert to total seconds
      int totalSeconds = (hours * 3600) + (minutes * 60) + seconds;

      // If all values are 0, return null
      if (totalSeconds == 0) {
        return null;
      }

      return totalSeconds;
    } catch (e) {
      return null;
    }
  }

  // Helper method to format time in HH:MM:SS format
  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    String hourStr = hours > 0 ? '${hours}h ' : '';
    String minStr = minutes > 0 ? '${minutes}m ' : '';
    String secStr = seconds > 0 ? '${seconds}s' : '';

    // If all are zero, show 0s
    if (hours == 0 && minutes == 0 && seconds == 0) {
      return '0s';
    }

    return '$hourStr$minStr$secStr'.trim();
  }

  // Add a step to the SOP
  void _addStepToSOP() {
    final titleController = TextEditingController();
    final instructionController = TextEditingController();
    final helpNoteController = TextEditingController();
    final assignedToController = TextEditingController();
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    final secondsController = TextEditingController(text: '0');

    String? imageUrl;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: Text(
                          (this._sop.steps.length + 1).toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step basic info
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Step Title',
                              border: OutlineInputBorder(),
                              hintText: 'Enter a clear title for this step',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: instructionController,
                            decoration: const InputDecoration(
                              labelText: 'Step Instructions',
                              border: OutlineInputBorder(),
                              hintText:
                                  'Provide detailed instructions for this step',
                            ),
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: helpNoteController,
                            decoration: const InputDecoration(
                              labelText: 'Help Note (Optional)',
                              border: OutlineInputBorder(),
                              hintText:
                                  'Add any helpful notes, tips, or additional context',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: assignedToController,
                            decoration: const InputDecoration(
                              labelText: 'Assigned To (Optional)',
                              border: OutlineInputBorder(),
                              hintText: 'Specify a role or person responsible',
                            ),
                          ),

                          // Step completion time
                          const SizedBox(height: 16),
                          Text(
                            'Estimated Completion Time',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Hours TextField
                              Expanded(
                                child: TextField(
                                  controller: hoursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hours',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Minutes TextField
                              Expanded(
                                child: TextField(
                                  controller: minutesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Minutes',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Seconds TextField
                              Expanded(
                                child: TextField(
                                  controller: secondsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Seconds',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),

                          // Step image
                          const SizedBox(height: 16),
                          Text(
                            'Step Image',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (imageUrl != null)
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _displayImage(
                                imageUrl,
                              ),
                            )
                          else
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_outlined,
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No image added',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final stepId = DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString();
                                  final url = await _pickAndUploadImage(
                                      context, _sop.id, stepId);
                                  if (url != null) {
                                    setState(() {
                                      imageUrl = url;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.image),
                                label: Text(imageUrl != null
                                    ? 'Change Image'
                                    : 'Add Image'),
                              ),
                              if (imageUrl != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      imageUrl = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove Image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          // Validate required fields
                          if (titleController.text.trim().isEmpty ||
                              instructionController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please fill in title and instructions'),
                              ),
                            );
                            return;
                          }

                          // Calculate total time in seconds
                          int hours =
                              int.tryParse(hoursController.text.trim()) ?? 0;
                          int minutes =
                              int.tryParse(minutesController.text.trim()) ?? 0;
                          int seconds =
                              int.tryParse(secondsController.text.trim()) ?? 0;

                          int totalSeconds =
                              (hours * 3600) + (minutes * 60) + seconds;

                          if (kDebugMode) {
                            print('Step image URL: $imageUrl');
                          }

                          // Create the new step
                          final newStep = SOPStep(
                            id: uuid.v4(),
                            title: titleController.text.trim(),
                            instruction: instructionController.text.trim(),
                            imageUrl: imageUrl,
                            helpNote: helpNoteController.text.trim().isNotEmpty
                                ? helpNoteController.text.trim()
                                : null,
                            assignedTo:
                                assignedToController.text.trim().isNotEmpty
                                    ? assignedToController.text.trim()
                                    : null,
                            estimatedTime:
                                totalSeconds > 0 ? totalSeconds : null,
                            stepTools: const [], // Use empty list for tools
                            stepHazards: const [], // Use empty list for hazards
                          );

                          if (kDebugMode) {
                            print(
                                'Created step with ID: ${newStep.id}, Image URL: ${newStep.imageUrl}');
                          }

                          // Add the step to the SOP
                          final updatedSteps = List<SOPStep>.from(_sop.steps)
                            ..add(newStep);
                          final updatedSop = _sop.copyWith(steps: updatedSteps);

                          // Update locally without saving to Firebase
                          _updateSOPLocally(updatedSop);

                          if (kDebugMode) {
                            print(
                                'SOP updated locally with ${updatedSop.steps.length} steps');
                            print(
                                'Last step image URL: ${updatedSop.steps.last.imageUrl}');
                          }

                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Step'),
                      ),
                    ],
                  ),
                ],
              ),
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

  // Upload thumbnail image for the SOP
  Future<void> _uploadSOPThumbnail(String sopId) async {
    if (kDebugMode) {
      print('Starting thumbnail upload process for SOP: $sopId');
    }

    try {
      // Use ImagePicker for web
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        if (kDebugMode) {
          print('Image selected, reading bytes...');
        }

        setState(() {
          _isLoading = true;
        });

        final Uint8List imageBytes = await image.readAsBytes();
        if (kDebugMode) {
          print('Image bytes read: ${imageBytes.length} bytes');
        }

        // For web, encode as a data URL
        if (kIsWeb) {
          if (kDebugMode) {
            print('Running in web mode, preparing data URL');
          }

          final String imageUrl =
              'data:image/jpeg;base64,${base64Encode(imageBytes)}';

          if (kDebugMode) {
            print('Data URL created, updating SOP with new thumbnail URL');
            // Print first 50 characters to verify format
            print('URL start: ${imageUrl.substring(0, 50)}...');
          }

          // Update the SOP with the new thumbnail URL
          final updatedSop = _sop.copyWith(thumbnailUrl: imageUrl);

          // Update locally
          await _updateSOPLocally(updatedSop);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thumbnail uploaded successfully')),
          );
        }
        // For native platforms - just use a placeholder for now
        else {
          if (kDebugMode) {
            print('Running in native mode, using placeholder');
          }

          final updatedSop =
              _sop.copyWith(thumbnailUrl: 'assets/images/placeholder.png');
          await _updateSOPLocally(updatedSop);
        }
      } else {
        if (kDebugMode) {
          print('No image selected by user');
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (kDebugMode) {
        print('Error in thumbnail upload process: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading thumbnail: $e')),
      );
    }
  }

  // Update visible tabs based on category settings
  void _updateVisibleTabsForCategory(Category category) {
    // Always show the basic info and steps tabs
    final Map<String, bool> requiredSections = category.categorySettings;

    // Determine which tabs should be visible
    List<Widget> newTabs = [
      const Tab(text: 'Basic Info'),
      const Tab(text: 'Description'),
    ];

    // Add conditional tabs based on category settings
    if (requiredSections['tools'] == true) {
      newTabs.add(const Tab(text: 'Tools'));
    }

    if (requiredSections['safety'] == true) {
      newTabs.add(const Tab(text: 'Safety'));
    }

    if (requiredSections['cautions'] == true) {
      newTabs.add(const Tab(text: 'Cautions'));
    }

    // Add custom section tabs
    for (final customSection in category.customSections) {
      newTabs.add(Tab(text: customSection));
    }

    // Steps tab is always included
    newTabs.add(const Tab(text: 'Steps'));

    // Update the tab controller
    setState(() {
      _tabController.dispose();
      _tabController = TabController(
        length: newTabs.length,
        vsync: this,
        initialIndex: 0,
      );
      _tabs = newTabs;
    });
  }

  // Validate YouTube URL
  bool _isValidYoutubeUrl(String url) {
    // Simple validation to check if the URL contains youtube.com or youtu.be
    return url.contains('youtube.com/') || url.contains('youtu.be/');
  }

  // Generate a QR code for YouTube URL
  Widget? _generateYouTubeQRCode() {
    if (_youtubeUrlController.text.isEmpty) {
      return null;
    }

    // Check if it's a valid YouTube URL
    if (!_isValidYoutubeUrl(_youtubeUrlController.text)) {
      return null;
    }

    return QrImageView(
      data: _youtubeUrlController.text,
      version: QrVersions.auto,
      size: 150.0,
      backgroundColor: Colors.white,
    );
  }

  // Helper function to display images, handling different URL types properly
  Widget _displayImage(String? imageUrl, {double? width, double? height}) {
    if (imageUrl == null) return Container();

    return CrossPlatformImage(
      imageUrl: imageUrl,
      width: width ?? 200,
      height: height ?? 150,
      fit: BoxFit.cover,
    );
  }

  // Helper method to build all tab views
  List<Widget> _buildTabViews() {
    List<Widget> tabViews = [
      // Basic Info Tab
      _buildBasicInfoTab(),

      // Description Tab
      _buildDescriptionTab(),
    ];

    // Add conditional tabs based on category settings
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    final category = categoryService.getCategoryById(_sop.categoryId);

    if (category != null) {
      // Add standard conditional tabs
      if (category.categorySettings['tools'] == true) {
        tabViews.add(_buildToolsTab());
      }

      if (category.categorySettings['safety'] == true) {
        tabViews.add(_buildSafetyTab());
      }

      if (category.categorySettings['cautions'] == true) {
        tabViews.add(_buildCautionsTab());
      }

      // Add custom section tabs
      for (final customSection in category.customSections) {
        tabViews.add(_buildCustomSectionTab(customSection));
      }
    }

    // Steps Tab - always included
    tabViews.add(_buildStepsTab());

    return tabViews;
  }

  // Basic Info Tab
  Widget _buildBasicInfoTab() {
    final categoryService = Provider.of<CategoryService>(context);
    final categories = categoryService.categories;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderColor.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      Text(
                        'Basic Information',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      'Define the core details of this Standard Operating Procedure',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Category dropdown with enhanced styling
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department/Category',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: AppColors.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: AppColors.borderColor),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            helperText:
                                'Select the department or category for this SOP',
                            prefixIcon: Icon(Icons.category_outlined,
                                color: AppColors.accentTeal),
                          ),
                          value:
                              _sop.categoryId.isEmpty ? null : _sop.categoryId,
                          items: categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
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
                                final category =
                                    categoryService.getCategoryById(value);
                                if (category != null) {
                                  _sop = _sop.copyWith(
                                      categoryName: category.name);

                                  // Update tab controller to match required sections
                                  _updateVisibleTabsForCategory(category);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title field with enhanced styling
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOP Title',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: AppColors.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: AppColors.borderColor),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            helperText:
                                'Enter a descriptive title for this SOP',
                            prefixIcon:
                                Icon(Icons.title, color: AppColors.primaryBlue),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SOP Thumbnail section
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderColor.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, color: AppColors.accentTeal),
                      const SizedBox(width: 12),
                      Text(
                        'SOP Thumbnail',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      'Add an image that represents the end product or result of this SOP',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Thumbnail image or placeholder with improved styling
                  Center(
                    child: GestureDetector(
                      onTap: () => _uploadSOPThumbnail(_sop.id),
                      child: Container(
                        width: 350,
                        height: 200,
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                          maxHeight: 200,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.borderColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: _sop.thumbnailUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _displayImage(
                                  _sop.thumbnailUrl,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: AppColors.accentTeal,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Click to add thumbnail',
                                    style: TextStyle(
                                      color: AppColors.textMedium,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recommended size: 1200 x 800 pixels',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12,
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

          const SizedBox(height: 24),

          // YouTube URL field with better styling
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderColor.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.smart_display, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        'Supplementary Video',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      'Add a link to a YouTube video related to this SOP',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: TextFormField(
                      controller: _youtubeUrlController,
                      decoration: InputDecoration(
                        labelText: 'YouTube URL',
                        hintText: 'https://youtube.com/watch?v=...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.borderColor),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        helperText: 'Enter a YouTube URL (optional)',
                        prefixIcon: Icon(Icons.link, color: Colors.red),
                      ),
                    ),
                  ),

                  // YouTube QR code preview
                  if (_generateYouTubeQRCode() != null) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'YouTube QR Code',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _generateYouTubeQRCode(),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan to watch video',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Description Tab
  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOP Description',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              helperText: 'Provide a detailed description of this SOP',
            ),
            maxLines: 10,
          ),
        ],
      ),
    );
  }

  // Tools Tab
  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tools & Equipment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'List all tools and equipment required for this SOP',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Add tool button
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Add Tool',
                    border: OutlineInputBorder(),
                    hintText: 'Enter tool name',
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        final updatedTools = List<String>.from(_sop.tools)
                          ..add(value);
                        _sop = _sop.copyWith(tools: updatedTools);
                      });
                      // Clear the text field by setting the value to empty
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add Tool',
                          border: OutlineInputBorder(),
                          hintText: 'Enter tool name',
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () {
                  _showAddItemToListDialog('Tool', (item) {
                    setState(() {
                      final updatedTools = List<String>.from(_sop.tools)
                        ..add(item);
                      _sop = _sop.copyWith(tools: updatedTools);
                    });
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // List of tools
          if (_sop.tools.isEmpty)
            const Center(
              child: Text(
                'No tools added yet',
                style:
                    TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sop.tools.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.build),
                    title: Text(_sop.tools[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () {
                        setState(() {
                          final updatedTools = List<String>.from(_sop.tools)
                            ..removeAt(index);
                          _sop = _sop.copyWith(tools: updatedTools);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Safety Tab
  Widget _buildSafetyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety Requirements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'List all safety requirements and PPE needed for this SOP',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Add safety requirement button
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Add Safety Requirement',
                    border: OutlineInputBorder(),
                    hintText: 'Enter safety requirement',
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        final updatedSafety =
                            List<String>.from(_sop.safetyRequirements)
                              ..add(value);
                        _sop = _sop.copyWith(safetyRequirements: updatedSafety);
                      });
                      // Clear the text field
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add Safety Requirement',
                          border: OutlineInputBorder(),
                          hintText: 'Enter safety requirement',
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () {
                  _showAddItemToListDialog('Safety Requirement', (item) {
                    setState(() {
                      final updatedSafety =
                          List<String>.from(_sop.safetyRequirements)..add(item);
                      _sop = _sop.copyWith(safetyRequirements: updatedSafety);
                    });
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // List of safety requirements
          if (_sop.safetyRequirements.isEmpty)
            const Center(
              child: Text(
                'No safety requirements added yet',
                style:
                    TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sop.safetyRequirements.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.security),
                    title: Text(_sop.safetyRequirements[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () {
                        setState(() {
                          final updatedSafety =
                              List<String>.from(_sop.safetyRequirements)
                                ..removeAt(index);
                          _sop =
                              _sop.copyWith(safetyRequirements: updatedSafety);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Cautions Tab
  Widget _buildCautionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cautions & Warnings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'List all cautions and warnings for this SOP',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Add caution button
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Add Caution',
                    border: OutlineInputBorder(),
                    hintText: 'Enter caution or warning',
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        final updatedCautions = List<String>.from(_sop.cautions)
                          ..add(value);
                        _sop = _sop.copyWith(cautions: updatedCautions);
                      });
                      // Clear the text field
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add Caution',
                          border: OutlineInputBorder(),
                          hintText: 'Enter caution or warning',
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () {
                  _showAddItemToListDialog('Caution', (item) {
                    setState(() {
                      final updatedCautions = List<String>.from(_sop.cautions)
                        ..add(item);
                      _sop = _sop.copyWith(cautions: updatedCautions);
                    });
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // List of cautions
          if (_sop.cautions.isEmpty)
            const Center(
              child: Text(
                'No cautions added yet',
                style:
                    TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sop.cautions.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(_sop.cautions[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () {
                        setState(() {
                          final updatedCautions =
                              List<String>.from(_sop.cautions)..removeAt(index);
                          _sop = _sop.copyWith(cautions: updatedCautions);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Steps Tab
  Widget _buildStepsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SOP Steps',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Step'),
                onPressed: _showAddStepDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _sop.steps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No steps added yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Step'),
                          onPressed: _showAddStepDialog,
                        ),
                      ],
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
                        final SOPStep item = _sop.steps.removeAt(oldIndex);
                        _sop.steps.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final step = _sop.steps[index];
                      return Card(
                        key: Key(step.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(step.title),
                          subtitle: Text(
                            step.instruction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (step.imageUrl != null)
                                const Icon(Icons.image,
                                    size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              if (step.estimatedTime != null)
                                Text(
                                  _formatTime(step.estimatedTime!),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showEditStepDialog(step, index),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    final updatedSteps =
                                        List<SOPStep>.from(_sop.steps)
                                          ..removeAt(index);
                                    _sop = _sop.copyWith(steps: updatedSteps);
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () => _showEditStepDialog(step, index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Custom section tab builder
  Widget _buildCustomSectionTab(String sectionName) {
    // Get the list of items for this custom section
    List<String> items = _sop.customSectionContent[sectionName] ?? [];

    // Controller for adding new items
    final TextEditingController controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sectionName:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Add $sectionName Item',
                    hintText: 'Enter a new item',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _addCustomSectionItem(sectionName, value);
                      controller.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _addCustomSectionItem(sectionName, controller.text);
                    controller.clear();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No $sectionName items added yet',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _removeCustomSectionItem(sectionName, item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Add item to custom section
  void _addCustomSectionItem(String sectionName, String item) {
    setState(() {
      if (!_sop.customSectionContent.containsKey(sectionName)) {
        _sop = _sop.copyWith(
          customSectionContent: {
            ..._sop.customSectionContent,
            sectionName: [item],
          },
        );
      } else {
        final updatedItems =
            List<String>.from(_sop.customSectionContent[sectionName]!);
        updatedItems.add(item);

        final updatedContent =
            Map<String, List<String>>.from(_sop.customSectionContent);
        updatedContent[sectionName] = updatedItems;

        _sop = _sop.copyWith(customSectionContent: updatedContent);
      }
    });
  }

  // Remove item from custom section
  void _removeCustomSectionItem(String sectionName, String item) {
    setState(() {
      if (_sop.customSectionContent.containsKey(sectionName)) {
        final updatedItems =
            List<String>.from(_sop.customSectionContent[sectionName]!);
        updatedItems.remove(item);

        final updatedContent =
            Map<String, List<String>>.from(_sop.customSectionContent);
        updatedContent[sectionName] = updatedItems;

        _sop = _sop.copyWith(customSectionContent: updatedContent);
      }
    });
  }

  // Fix the error by ensuring imageUrl is non-null
  void _showFullSizeImageDialog(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CrossPlatformImage(
                  imageUrl: imageUrl,
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.8,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to handle step edit requests from the SOPViewer
  void _editStepFromViewer(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _sop.steps.length) {
      setState(() {
        _isEditing = true;
        // Select the Steps tab
        _tabController.animateTo(5);
      });

      // Schedule the step editor to open after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final step = _sop.steps[stepIndex];
        _showEditStepDialog(step, stepIndex);
      });
    }
  }
}
