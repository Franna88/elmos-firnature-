import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// A model class representing a SOP Step
class SOPStep {
  final int number;
  final String title;
  final String description;
  final List<String> images;
  final List<String> tools;
  final List<String> materials;
  final List<String> safetyNotes;
  final List<String> qualityCheckpoints;

  SOPStep({
    required this.number,
    required this.title,
    required this.description,
    this.images = const [],
    this.tools = const [],
    this.materials = const [],
    this.safetyNotes = const [],
    this.qualityCheckpoints = const [],
  });
}

/// A model class representing a Standard Operating Procedure (SOP)
class SOPDetail {
  final String id;
  final String title;
  final String category;
  final DateTime lastUpdated;
  final String author;
  final String description;
  final String status;
  final List<SOPStep> steps;

  SOPDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.lastUpdated,
    required this.author,
    required this.description,
    required this.status,
    required this.steps,
  });
}

/// SOP Viewer Screen
///
/// This screen displays the details of a specific SOP with step-by-step instructions.
class SOPViewerScreen extends StatefulWidget {
  final String? sopId;

  const SOPViewerScreen({
    Key? key,
    this.sopId,
  }) : super(key: key);

  @override
  State<SOPViewerScreen> createState() => _SOPViewerScreenState();
}

class _SOPViewerScreenState extends State<SOPViewerScreen> {
  late SOPDetail _sop;
  bool _isLoading = true;
  int _currentStep = 0;
  bool _showSidebar = true;
  late String _sopId;

  @override
  void initState() {
    super.initState();
    _loadSOP();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get sopId from route arguments if not provided directly
    final args = ModalRoute.of(context)?.settings.arguments;
    _sopId = widget.sopId ?? (args is String ? args : 'SOP-001');
  }

  // Simulates loading the SOP data
  Future<void> _loadSOP() async {
    // In a real app, this would fetch data from an API or database
    await Future.delayed(const Duration(milliseconds: 800));

    // Sample data for demonstration
    _sop = SOPDetail(
      id: _sopId,
      title: 'Assembly of Chair Model A',
      category: 'Assembly',
      lastUpdated: DateTime(2023, 10, 15),
      author: 'John Smith',
      description:
          'This SOP outlines the step-by-step process for assembling the Model A chair. Follow each step carefully to ensure proper assembly and quality standards.',
      status: 'Published',
      steps: [
        SOPStep(
          number: 1,
          title: 'Prepare Components',
          description:
              'Gather all required components and tools. Verify that all parts are present and undamaged before beginning assembly.',
          images: ['chair_components.jpg'],
          tools: ['Screwdriver', 'Allen wrench', 'Rubber mallet'],
          materials: [
            'Chair base',
            'Seat cushion',
            'Backrest',
            '4 legs',
            '8 screws (M6)',
            '4 washers'
          ],
          safetyNotes: [
            'Wear protective gloves when handling metal components',
            'Keep small parts away from children'
          ],
        ),
        SOPStep(
          number: 2,
          title: 'Attach Legs to Base',
          description:
              'Position the chair base upside down on a clean, flat surface. Align each leg with the corresponding socket on the base. Insert and hand-tighten screws with washers.',
          images: ['attach_legs.jpg'],
          tools: ['Screwdriver'],
          materials: ['Chair base', '4 legs', '4 screws (M6)', '4 washers'],
          qualityCheckpoints: [
            'Legs should be firmly attached with no wobbling',
            'All screws should be flush with the surface'
          ],
        ),
        SOPStep(
          number: 3,
          title: 'Secure Legs',
          description:
              'Using the screwdriver, fully tighten all screws in a diagonal pattern (similar to tightening lug nuts on a car wheel). This ensures even pressure distribution.',
          images: ['tighten_screws.jpg'],
          tools: ['Screwdriver'],
          qualityCheckpoints: [
            'Screws should be tight but not over-tightened',
            'Chair should sit level on flat surface'
          ],
        ),
        SOPStep(
          number: 4,
          title: 'Attach Backrest to Base',
          description:
              'Position the backrest against the rear of the chair base, aligning the mounting holes. Insert the remaining 4 screws and hand-tighten.',
          images: ['attach_backrest.jpg'],
          tools: ['Screwdriver'],
          materials: ['Backrest', '4 screws (M6)'],
        ),
        SOPStep(
          number: 5,
          title: 'Secure Backrest',
          description:
              'Fully tighten the backrest screws in an alternating pattern to ensure even pressure distribution.',
          images: ['secure_backrest.jpg'],
          tools: ['Screwdriver'],
          qualityCheckpoints: [
            'Backrest should be firmly attached with no movement',
            'Alignment should be centered and straight'
          ],
        ),
        SOPStep(
          number: 6,
          title: 'Install Seat Cushion',
          description:
              'Place the seat cushion on the chair base, aligning the attachment points. Press firmly until you hear the cushion click into place.',
          images: ['install_cushion.jpg'],
          materials: ['Seat cushion'],
          qualityCheckpoints: [
            'Cushion should be securely attached on all sides',
            'No gaps should be visible between cushion and base'
          ],
        ),
        SOPStep(
          number: 7,
          title: 'Final Inspection',
          description:
              'Inspect the fully assembled chair for quality and functionality. Test the chair by applying pressure to the seat and backrest.',
          images: ['final_inspection.jpg'],
          qualityCheckpoints: [
            'Chair should be stable on a flat surface with no wobbling',
            'All components should be securely attached',
            'No visible defects, scratches, or damage',
            'Chair should support weight without creaking or movement'
          ],
          safetyNotes: ['Ensure chair can support at least 250 lbs (113 kg)'],
        ),
      ],
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _nextStep() {
    if (_currentStep < _sop.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _sop.steps.length) {
      setState(() {
        _currentStep = stepIndex;
      });
    }
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    final isSmallScreen = ResponsiveBreakpoints.of(context).isSmallScreen;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
            title: Text('Loading SOP...',
                style: appTheme.typography.headingSmall)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sop.title, style: appTheme.typography.headingSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Print functionality
            },
            tooltip: 'Print SOP',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              // Export to PDF functionality
            },
            tooltip: 'Export to PDF',
          ),
          IconButton(
            icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
            onPressed: _toggleSidebar,
            tooltip: _showSidebar ? 'Hide Steps' : 'Show Steps',
          ),
        ],
      ),
      body: Row(
        children: [
          // Steps sidebar
          if (_showSidebar && !isSmallScreen)
            SizedBox(
              width: 250,
              child: _buildStepsSidebar(),
            ),

          // Main content area
          Expanded(
            child: _buildStepContent(),
          ),
        ],
      ),
      // Bottom navigation for mobile
      bottomNavigationBar: isSmallScreen ? _buildMobileNavigation() : null,
      // Floating sidebar toggle for mobile
      floatingActionButton: isSmallScreen && !_showSidebar
          ? FloatingActionButton(
              onPressed: _toggleSidebar,
              child: const Icon(Icons.menu),
              tooltip: 'Show Steps',
            )
          : null,
      // Drawer for mobile
      drawer: isSmallScreen && _showSidebar
          ? Drawer(
              child: _buildStepsSidebar(),
            )
          : null,
    );
  }

  Widget _buildStepsSidebar() {
    final appTheme = AppTheme.of(context);

    return Container(
      color: appTheme.colors.surfaceLightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SOP Info header
          Container(
            padding: const EdgeInsets.all(16),
            color: appTheme.colors.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sop.title,
                  style: appTheme.typography.headingSmall.copyWith(
                    color: appTheme.colors.whiteColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_sop.id}',
                  style: appTheme.typography.labelMedium.copyWith(
                    color: appTheme.colors.whiteColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Steps list
          Expanded(
            child: ListView.builder(
              itemCount: _sop.steps.length,
              itemBuilder: (context, index) {
                final step = _sop.steps[index];
                final isActive = index == _currentStep;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? appTheme.colors.primaryColor
                        : appTheme.colors.grey200Color,
                    foregroundColor: isActive
                        ? appTheme.colors.whiteColor
                        : appTheme.colors.textPrimaryColor,
                    child: Text('${step.number}'),
                  ),
                  title: Text(
                    step.title,
                    style: isActive
                        ? appTheme.typography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: appTheme.colors.primaryColor,
                          )
                        : appTheme.typography.labelLarge,
                  ),
                  selected: isActive,
                  onTap: () => _goToStep(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final appTheme = AppTheme.of(context);
    final currentStep = _sop.steps[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: appTheme.colors.primaryColor,
                foregroundColor: appTheme.colors.whiteColor,
                radius: 24,
                child: Text(
                  '${currentStep.number}',
                  style: appTheme.typography.headingSmall.copyWith(
                    color: appTheme.colors.whiteColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  currentStep.title,
                  style: appTheme.typography.headingLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Step description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: appTheme.typography.subtitle1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentStep.description,
                    style: appTheme.typography.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Step images
          if (currentStep.images.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reference Images',
                      style: appTheme.typography.subtitle1,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: currentStep.images.length,
                        itemBuilder: (context, index) {
                          // In a real app, this would load actual images
                          return Container(
                            width: 300,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: appTheme.colors.grey200Color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                currentStep.images[index],
                                style: appTheme.typography.bodyMedium,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tools and materials
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tools
              if (currentStep.tools.isNotEmpty)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tools Required',
                            style: appTheme.typography.subtitle1,
                          ),
                          const SizedBox(height: 8),
                          ...currentStep.tools.map((tool) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.handyman,
                                        color: appTheme.colors.accentColor),
                                    const SizedBox(width: 8),
                                    Text(tool,
                                        style: appTheme.typography.bodyMedium),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),

              if (currentStep.tools.isNotEmpty &&
                  currentStep.materials.isNotEmpty)
                const SizedBox(width: 16),

              // Materials
              if (currentStep.materials.isNotEmpty)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Materials Required',
                            style: appTheme.typography.subtitle1,
                          ),
                          const SizedBox(height: 8),
                          ...currentStep.materials.map((material) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2,
                                        color: appTheme.colors.secondaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(material,
                                          style:
                                              appTheme.typography.bodyMedium),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Safety notes
          if (currentStep.safetyNotes.isNotEmpty) ...[
            Card(
              color: appTheme.colors.warningColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: appTheme.colors.warningColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Safety Notes',
                          style: appTheme.typography.subtitle1.copyWith(
                            color: appTheme.colors.warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...currentStep.safetyNotes.map((note) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: appTheme.typography.bodyMedium),
                              Expanded(
                                child: Text(note,
                                    style: appTheme.typography.bodyMedium),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quality checkpoints
          if (currentStep.qualityCheckpoints.isNotEmpty) ...[
            Card(
              color: appTheme.colors.successColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: appTheme.colors.successColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quality Checkpoints',
                          style: appTheme.typography.subtitle1.copyWith(
                            color: appTheme.colors.successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...currentStep.qualityCheckpoints
                        .map((checkpoint) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: appTheme.colors.successColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(checkpoint,
                                        style: appTheme.typography.bodyMedium),
                                  ),
                                ],
                              ),
                            )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Step navigation
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentStep > 0 ? _previousStep : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.colors.secondaryColor,
                  ),
                ),
                Text(
                  'Step ${_currentStep + 1} of ${_sop.steps.length}',
                  style: appTheme.typography.labelLarge,
                ),
                ElevatedButton.icon(
                  onPressed:
                      _currentStep < _sop.steps.length - 1 ? _nextStep : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next Step'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavigation() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentStep > 0 ? _previousStep : null,
            tooltip: 'Previous Step',
          ),
          Text('Step ${_currentStep + 1} of ${_sop.steps.length}'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentStep < _sop.steps.length - 1 ? _nextStep : null,
            tooltip: 'Next Step',
          ),
        ],
      ),
    );
  }
}
