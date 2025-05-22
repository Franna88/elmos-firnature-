import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/sop_model.dart';
import '../../widgets/cross_platform_image.dart';
import '../../../core/theme/app_theme.dart';

class MobileSOPViewerScreen extends StatefulWidget {
  final String sopId;

  const MobileSOPViewerScreen({super.key, required this.sopId});

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

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

    final sopService = Provider.of<SOPService>(context, listen: false);

    try {
      final sop = await sopService.getSopById(widget.sopId);
      if (sop != null) {
        setState(() {
          _sop = sop;
          _isLoading = false;
        });

        // Play animation effect if this was from a QR scan
        if (_isFromQRScan) {
          _animationController.forward();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOP not found'),
              backgroundColor: Colors.red,
            ),
          );
          _navigateBack();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading SOP: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _navigateBack();
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
    final bool isTablet = size.width > 600;

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
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Category: ${_sop.categoryName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Info button to show SOP details
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'SOP Details',
            onPressed: () => _showSOPInfoDialog(context),
          ),
          // Add Edit button if user is logged in and not in anonymous mode
          if (!_isAnonymousAccess)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit SOP',
              onPressed: () {
                // Navigate to the editor screen with the current SOP id
                context.go('/mobile/editor/${widget.sopId}');
              },
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

          // Steps navigation row
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16.0 : 8.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
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
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      )
                    : const SizedBox(width: 48),

                // Step indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step ${_currentStepIndex + 1} of ${_sop.steps.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 18.0 : 16.0,
                      color: Colors.black87,
                    ),
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
                        ),
                      )
                    : const SizedBox(width: 48),
              ],
            ),
          ),

          // Main content with steps
          Expanded(
            child:
                isTablet ? _buildTabletStepContent() : _buildPhoneStepContent(),
          ),
        ],
      ),
    );
  }

  // Tablet-optimized step content with side-by-side layout
  Widget _buildTabletStepContent() {
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

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section (left side)
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTap: () {
                    if (step.imageUrl != null) {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.black.withOpacity(0.9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Center(
                                  child:
                                      _buildStepImageFullscreen(step.imageUrl!),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white, size: 30),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: step.imageUrl != null
                              ? CrossPlatformImage(
                                  imageUrl: step.imageUrl!,
                                  height: double.infinity,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: _buildImageError(),
                                )
                              : Container(
                                  color: Colors.grey[100],
                                  height: double.infinity,
                                  width: double.infinity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "No Image Available",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        // Fullscreen indicator
                        if (step.imageUrl != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
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
                                border: Border.all(color: Colors.blue.shade200),
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
      },
    );
  }

  // Phone-optimized step content with vertical layout - description at top and image below
  Widget _buildPhoneStepContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
            // Image takes up most of the screen
            Expanded(
              flex: 7,
              child: GestureDetector(
                onTap: () {
                  if (step.imageUrl != null) {
                    // Show fullscreen image view
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        insetPadding: EdgeInsets.zero, // Full screen dialog
                        backgroundColor: Colors.black.withOpacity(0.9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Interactive image viewer for zooming and panning
                            InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Center(
                                child:
                                    _buildStepImageFullscreen(step.imageUrl!),
                              ),
                            ),
                            // Close button positioned at the top
                            Positioned(
                              top: 40,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Main image that fills the container
                      if (step.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: CrossPlatformImage(
                              imageUrl: step.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: _buildImageError(),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[100],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No Image Available",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Fullscreen indicator
                      if (step.imageUrl != null)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Details below the image
            Expanded(
              flex: 3,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Instruction
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.instruction,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Help note if available
                              if (step.helpNote != null &&
                                  step.helpNote!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          color: Colors.amber[700], size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          step.helpNote!,
                                          style: TextStyle(
                                            fontSize: 12,
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
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.build,
                                          color: Colors.blue[700], size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Tools: ${step.stepTools.join(', ')}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[800],
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
                    ],
                  ),
                ),
              ),
            ),

            // Complete button for the last step
            if (isLastStep)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate back to main page
                    context.go('/mobile/sops');
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('COMPLETE SOP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Helper method for fullscreen image viewing
  Widget _buildStepImageFullscreen(String imageUrl) {
    return CrossPlatformImage(
      imageUrl: imageUrl,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.7,
      fit: BoxFit.contain,
      errorWidget: _buildImageError(),
    );
  }

  Widget _buildStepImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CrossPlatformImage(
        imageUrl: imageUrl,
        width: MediaQuery.of(context).size.width,
        height: 250,
        fit: BoxFit.contain,
        errorWidget: _buildImageError(),
      ),
    );
  }

  Widget _buildThumbnailImage(String imageUrl) {
    return CrossPlatformImage(
      imageUrl: imageUrl,
      width: 150,
      height: 150,
      fit: BoxFit.contain,
      errorWidget: _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 200,
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
              fontSize: 14,
            ),
          ),
        ],
      ),
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
                context.go('/mobile/editor/${widget.sopId}');
              },
              icon: const Icon(Icons.edit, color: Colors.blue),
              label: const Text(
                'Edit',
                style: TextStyle(color: Colors.blue),
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
