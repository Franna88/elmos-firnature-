import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../data/services/print_service.dart';
import 'package:image_network/image_network.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/cross_platform_image.dart';
import '../../widgets/app_scaffold.dart';
import '../sop_editor/sop_editor_screen.dart';
import '../../../data/services/category_service.dart';

class MobileSOPViewerScreen extends StatefulWidget {
  final String sopId;
  final int? initialStepIndex;

  const MobileSOPViewerScreen({
    super.key,
    required this.sopId,
    this.initialStepIndex,
  });

  @override
  State<MobileSOPViewerScreen> createState() => _MobileSOPViewerScreenState();
}

class _MobileSOPViewerScreenState extends State<MobileSOPViewerScreen>
    with SingleTickerProviderStateMixin {
  late SOP _sop;
  bool _isLoading = true;
  int _currentStepIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  bool _isFromQRScan = false;
  bool _isAnonymousAccess = false;
  bool _initialized = false;
  final PrintService _printService = PrintService();

  @override
  void initState() {
    super.initState();
    // Initialize with the provided step index if available
    _currentStepIndex = widget.initialStepIndex ?? 0;
    _pageController = PageController(initialPage: _currentStepIndex);

    // Initialize animation controller for QR scan effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;

      // Check if this SOP was accessed via QR code scan - safely done in didChangeDependencies
      final route = ModalRoute.of(context)?.settings.name ?? '';
      _isFromQRScan = route.contains('/sop/') && !route.contains('/editor/');

      // Check if this is anonymous access - safely done in didChangeDependencies
      final authService = Provider.of<AuthService>(context, listen: false);
      _isAnonymousAccess = !authService.isLoggedIn;

      // Load the SOP after dependencies are available
      _loadSOP();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      final sop = sopService.getSopById(widget.sopId);

      if (sop == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOP not found'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        });
        return;
      }

      setState(() {
        _sop = sop;
        _isLoading = false;
      });

      // Preload all images for this SOP to improve viewing experience
      sopService.preloadSOPImages(sop.id).then((_) {
        // if (kDebugMode) {
        //   print('All SOP images preloaded successfully');
        // }
      });

      // Play animation effect if this was accessed via QR code
      if (_isFromQRScan) {
        _animationController.forward();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading SOP: $e');
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading SOP: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        });
      }
    }
  }

  // Helper method to navigate back based on authentication state
  void _navigateBack() {
    if (_isAnonymousAccess) {
      // If accessed anonymously, go to login
      context.go('/login');
    } else {
      // If logged in, go to mobile SOPs list
      context.go('/mobile/sops');
    }
  }

  // Method to launch YouTube video URL
  Future<void> _launchYoutubeVideo() async {
    if (_sop.youtubeUrl != null && _sop.youtubeUrl!.isNotEmpty) {
      final Uri url = Uri.parse(_sop.youtubeUrl!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch video URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    // Consider both screen size and orientation for layout decision
    final bool isTablet = size.width > 600;
    // Use tablet layout only for landscape orientation on tablets
    final bool useTabletLayout =
        isTablet && orientation == Orientation.landscape;

    final imageHeight = isTablet ? 320.0 : 220.0;
    final imageWidth = isTablet ? 400.0 : double.infinity;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading SOP details...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              _navigateBack();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sop.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _sop.categoryName ?? 'Uncategorized',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: IconButton(
              icon: const Icon(Icons.info_outline, size: 20 * 0.85),
              tooltip: 'SOP Details',
              onPressed: () => _showSOPInfoDialog(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: IconButton(
              icon: const Icon(Icons.print, size: 24 * 0.85),
              tooltip: 'Print SOP',
              onPressed: () {
                final categoryService =
                    Provider.of<CategoryService>(context, listen: false);
                _printService.printSOP(context, _sop, categoryService);
              },
            ),
          ),
          if (!_isAnonymousAccess)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: IconButton(
                icon: const Icon(Icons.edit, size: 24 * 0.85),
                tooltip: 'Edit SOP',
                onPressed: () {
                  context.go(
                      '/mobile/editor/${widget.sopId}?stepIndex=$_currentStepIndex');
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Only show video button if available
          if (_sop.youtubeUrl != null && _sop.youtubeUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryBlue.withOpacity(0.05),
              child: ElevatedButton.icon(
                onPressed: _launchYoutubeVideo,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Watch Video Tutorial'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16.0 : 12.0,
                    vertical: isTablet ? 12.0 : 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

          // Progress indicator
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16.0 : 8.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                // Step progress indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentStepIndex + 1) / _sop.steps.length,
                    backgroundColor: Colors.grey[200],
                    color: AppColors.primaryBlue,
                    minHeight: 6,
                  ),
                ),

                const SizedBox(height: 10),

                // Navigation controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous button
                    _currentStepIndex > 0
                        ? ElevatedButton.icon(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            label: const Text('PREV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        : const SizedBox(width: 48),

                    // Step counter
                    Text(
                      'Step ${_currentStepIndex + 1} of ${_sop.steps.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),

                    // Next button
                    _currentStepIndex < _sop.steps.length - 1
                        ? ElevatedButton.icon(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            label: const Text('NEXT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),

          // Main content with steps
          Expanded(
            child: useTabletLayout
                ? _buildTabletStepContent()
                : _buildPhoneStepContent(),
          ),
        ],
      ),
    );
  }

  // Tablet-optimized step content with responsive layout
  Widget _buildTabletStepContent() {
    // Check orientation
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final imageHeight = isTablet ? 350.0 : 220.0;
    final imageWidth = isTablet ? 450.0 : double.infinity;

    return PageView.builder(
      controller: _pageController,
      itemCount: _sop.steps.length,
      onPageChanged: (index) {
        setState(() {
          _currentStepIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final step = _sop.steps[index];
        final isLastStep = index == _sop.steps.length - 1;

        // Use different layouts based on orientation
        if (isLandscape) {
          // LANDSCAPE: Side-by-side layout but with cleaner image display
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section (left side) - Use CrossPlatformImage as in desktop
                Expanded(
                  flex: 8,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    child: Container(
                      height: imageHeight,
                      width: imageWidth,
                      child: step.imageUrl != null
                          ? CrossPlatformImage(
                              imageUrl: step.imageUrl!,
                              fit: BoxFit.contain,
                              height: imageHeight,
                              errorWidget: Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 12.0),

                // Instructions section (right side) - Reduced flex to 2 (from 4)
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step number indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Step ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Title
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Main instruction
                            Text(
                              step.instruction,
                              style: const TextStyle(
                                fontSize: 15.0,
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),

                            // Help note if available
                            if (step.helpNote != null &&
                                step.helpNote!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.lightbulb,
                                            color: Colors.amber[700], size: 14),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Helpful Tip",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      step.helpNote!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.amber[900],
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Tools if available
                            if (step.stepTools.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.build,
                                            color: Colors.blue[700], size: 14),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Required Tools",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: step.stepTools.map((tool) {
                                        return Chip(
                                          label: Text(tool),
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                              color: Colors.blue.shade300),
                                          labelStyle: TextStyle(
                                            color: Colors.blue[800],
                                            fontSize: 11,
                                          ),
                                          padding: EdgeInsets.zero,
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Complete button
                            if (isLastStep) ...[
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.go('/mobile/sops');
                                  },
                                  icon:
                                      const Icon(Icons.check_circle, size: 18),
                                  label: const Text('COMPLETE SOP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(160, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 4,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // PORTRAIT: Side-by-side layout (original implementation)
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section (left side) - Use CrossPlatformImage as in desktop
                Expanded(
                  flex: 6,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    child: Container(
                      height: 400,
                      width: 450,
                      child: step.imageUrl != null
                          ? Center(
                              child: CrossPlatformImage(
                                imageUrl: step.imageUrl!,
                                fit: BoxFit.cover,
                                width: 450,
                                height: 400,
                                errorWidget: Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 24.0),

                // Instructions section (right side)
                Expanded(
                  flex: 4,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with step number
                            Container(
                              padding: const EdgeInsets.only(bottom: 16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Main instruction
                            Text(
                              step.instruction,
                              style: const TextStyle(
                                fontSize: 18.0,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),

                            // Help note if available
                            if (step.helpNote != null &&
                                step.helpNote!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.lightbulb,
                                            color: Colors.amber[700]),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Helpful Tip",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      step.helpNote!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.amber[900],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Tools if available
                            if (step.stepTools.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.build,
                                            color: Colors.blue[700]),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Required Tools",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: step.stepTools.map((tool) {
                                        return Chip(
                                          label: Text(tool),
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                              color: Colors.blue.shade300),
                                          labelStyle: TextStyle(
                                            color: Colors.blue[800],
                                            fontSize: 14,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Complete button (tablet only shows this on the instruction card)
                            if (isLastStep) ...[
                              const SizedBox(height: 40),
                              ElevatedButton.icon(
                                onPressed: () {
                                  context.go('/mobile/sops');
                                },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('COMPLETE SOP'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  // Vertical layout (image on top, text below) - used for portrait mode on all devices
  Widget _buildPhoneStepContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600; // Is tablet in portrait mode

    return PageView.builder(
      controller: _pageController,
      itemCount: _sop.steps.length,
      onPageChanged: (index) {
        setState(() {
          _currentStepIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final step = _sop.steps[index];
        final isLastStep = index == _sop.steps.length - 1;

        return Column(
          children: [
            // Step number indicator
            Padding(
              padding: EdgeInsets.only(
                top: isLargeScreen ? 16.0 : 8.0,
                bottom: isLargeScreen ? 16.0 : 8.0,
                left: isLargeScreen ? 24.0 : 16.0,
                right: isLargeScreen ? 24.0 : 16.0,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 16.0 : 12.0,
                  vertical: isLargeScreen ? 6.0 : 4.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(isLargeScreen ? 20.0 : 16.0),
                  border:
                      Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: Text(
                  'Step ${index + 1} - ${step.title}',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: isLargeScreen ? 16.0 : 14.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Image takes up most of the screen (phone view) - Use CrossPlatformImage as in desktop
            Expanded(
              flex: 6,
              child: Card(
                margin: EdgeInsets.fromLTRB(
                  isLargeScreen ? 24.0 : 16.0,
                  4.0,
                  isLargeScreen ? 24.0 : 16.0,
                  isLargeScreen ? 16.0 : 8.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(isLargeScreen ? 16.0 : 12.0),
                ),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: Container(
                  height: 370,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: step.imageUrl != null
                      ? CrossPlatformImage(
                          imageUrl: step.imageUrl!,
                          fit: BoxFit.contain,
                          height: 330,
                          width: 330,
                          errorWidget: Container(
                            color: Colors.grey[100],
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Details below the image
            Expanded(
              flex: 4,
              child: Card(
                margin: EdgeInsets.fromLTRB(
                  isLargeScreen ? 24.0 : 16.0,
                  0,
                  isLargeScreen ? 24.0 : 16.0,
                  isLargeScreen ? 24.0 : 16.0,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(isLargeScreen ? 16.0 : 12.0),
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instruction
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.instruction,
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 18.0 : 15.0,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isLargeScreen ? 16.0 : 12.0),

                              // Help note if available
                              if (step.helpNote != null &&
                                  step.helpNote!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.all(
                                      isLargeScreen ? 12.0 : 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(
                                        isLargeScreen ? 12.0 : 8.0),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          color: Colors.amber[700],
                                          size: isLargeScreen ? 18.0 : 14.0),
                                      SizedBox(
                                          width: isLargeScreen ? 12.0 : 8.0),
                                      Expanded(
                                        child: Text(
                                          step.helpNote!,
                                          style: TextStyle(
                                            fontSize:
                                                isLargeScreen ? 16.0 : 13.0,
                                            color: Colors.amber[900],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Tools if available
                              if (step.stepTools.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(
                                      top: isLargeScreen ? 8.0 : 4.0),
                                  padding: EdgeInsets.all(
                                      isLargeScreen ? 12.0 : 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(
                                        isLargeScreen ? 12.0 : 8.0),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.build,
                                              color: Colors.blue[700],
                                              size:
                                                  isLargeScreen ? 18.0 : 14.0),
                                          SizedBox(
                                              width:
                                                  isLargeScreen ? 12.0 : 8.0),
                                          Text(
                                            "Required Tools:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  isLargeScreen ? 16.0 : 13.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: isLargeScreen ? 8.0 : 6.0),
                                      Wrap(
                                        spacing: isLargeScreen ? 8.0 : 6.0,
                                        runSpacing: isLargeScreen ? 8.0 : 6.0,
                                        children: step.stepTools.map((tool) {
                                          return Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    isLargeScreen ? 12.0 : 8.0,
                                                vertical:
                                                    isLargeScreen ? 4.0 : 2.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      isLargeScreen
                                                          ? 16.0
                                                          : 12.0),
                                              border: Border.all(
                                                  color: Colors.blue.shade300),
                                            ),
                                            child: Text(
                                              tool,
                                              style: TextStyle(
                                                fontSize:
                                                    isLargeScreen ? 14.0 : 12.0,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
              ),
            ),

            // Complete button for the last step
            if (isLastStep)
              Padding(
                padding: EdgeInsets.fromLTRB(isLargeScreen ? 24.0 : 16.0, 0,
                    isLargeScreen ? 24.0 : 16.0, isLargeScreen ? 24.0 : 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate back to main page
                    context.go('/mobile/sops');
                  },
                  icon: Icon(Icons.check_circle,
                      size: isLargeScreen ? 24.0 : 20.0),
                  label: Text(
                    'COMPLETE SOP',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16.0 : 14.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize:
                        Size(double.infinity, isLargeScreen ? 56.0 : 48.0),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(isLargeScreen ? 16.0 : 12.0),
                    ),
                    elevation: 4,
                    padding: EdgeInsets.symmetric(
                        vertical: isLargeScreen ? 16.0 : 12.0),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOP Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Title', _sop.title),
              _buildInfoRow('Description', _sop.description),
              _buildInfoRow('Category', _sop.categoryName ?? 'Uncategorized'),
              _buildInfoRow('Revision', _sop.revisionNumber.toString()),
              _buildInfoRow('Created By', _sop.createdBy),
              _buildInfoRow('Created', _formatDate(_sop.createdAt)),
              _buildInfoRow('Last Updated', _formatDate(_sop.updatedAt)),

              // Display YouTube video information if available
              if (_sop.youtubeUrl != null && _sop.youtubeUrl!.isNotEmpty) ...[
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Video Tutorial Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(),
              const Text(
                'Required Tools:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.tools.map((tool) {
                  return Chip(
                    label: Text(tool),
                    backgroundColor: Colors.blue[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.blue[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Safety Requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.safetyRequirements.map((safety) {
                  return Chip(
                    label: Text(safety),
                    backgroundColor: Colors.red[50],
                    labelStyle: TextStyle(fontSize: 12, color: Colors.red[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cautions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.cautions.map((caution) {
                  return Chip(
                    label: Text(caution),
                    backgroundColor: Colors.amber[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.amber[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),

              // Show custom sections
              if (_sop.customSectionContent.isNotEmpty) ...[
                for (final entry in _sop.customSectionContent.entries)
                  if (entry.value.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${entry.key}:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: entry.value.map((item) {
                        return Chip(
                          label: Text(item),
                          backgroundColor: Colors.purple[50],
                          labelStyle: TextStyle(
                              fontSize: 12, color: Colors.purple[800]),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!_isAnonymousAccess)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go(
                    '/mobile/editor/${widget.sopId}?stepIndex=$_currentStepIndex');
              },
              icon: const Icon(Icons.edit, color: Colors.blue),
              label: const Text(
                'Edit',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final categoryService =
                  Provider.of<CategoryService>(context, listen: false);
              _printService.printSOP(context, _sop, categoryService);
            },
            icon: const Icon(Icons.print, color: Colors.purple),
            label: const Text(
              'Print',
              style: TextStyle(color: Colors.purple),
            ),
          ),
          if (_sop.youtubeUrl != null && _sop.youtubeUrl!.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchYoutubeVideo();
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.red),
              label: const Text(
                'Watch Video',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
