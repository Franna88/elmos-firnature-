import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:alphabet_scroll_view/alphabet_scroll_view.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/qr_code_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../services/platform_specific/scanner_service.dart';
import '../../../services/platform_specific/scanner_service_interface.dart';
import '../../widgets/cross_platform_image.dart';

class MobileSOPsScreen extends StatefulWidget {
  final Map<String, dynamic>? extraParams;

  const MobileSOPsScreen({
    super.key,
    this.extraParams,
  });

  @override
  State<MobileSOPsScreen> createState() => _MobileSOPsScreenState();
}

class _MobileSOPsScreenState extends State<MobileSOPsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _selectedLetter;
  final ScrollController _scrollController = ScrollController();

  // Define a custom alphabet list
  final List<String> _alphabet = const [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#'
  ];

  @override
  void initState() {
    super.initState();

    // Set initial category if provided in navigation params
    if (widget.extraParams != null &&
        widget.extraParams!.containsKey('category')) {
      _selectedCategory = widget.extraParams!['category'] as String;
    }

    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);

    await Future.wait([
      sopService.refreshSOPs(),
      categoryService.refreshCategories(),
    ]);

    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToLetter(String letter, List<SOP> sops) {
    // Get indices of SOPs that start with this letter
    final List<int> matchingIndices = [];
    for (int i = 0; i < sops.length; i++) {
      if (sops[i].title.toUpperCase().startsWith(letter)) {
        matchingIndices.add(i);
      }
    }

    if (matchingIndices.isNotEmpty) {
      setState(() {
        _selectedLetter = letter;
      });

      // Use first matching index
      final int sopIndex = matchingIndices.first;

      // Calculate the approximate scroll position based on card height and padding
      final double itemHeight = 180.0; // Average height of a card
      final double scrollPosition = sopIndex * itemHeight;

      _scrollController.animateTo(scrollPosition,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

      // Show a visual indicator of how many SOPs start with this letter
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(matchingIndices.length > 1
              ? 'Found ${matchingIndices.length} SOPs starting with $letter'
              : 'Scrolled to $letter'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);
    final categoryService = Provider.of<CategoryService>(context);
    final authService = Provider.of<AuthService>(context);

    // Filter SOPs based on search query and category
    List<SOP> filteredSOPs = sopService.searchSOPs(_searchQuery);
    if (_selectedCategory != 'All') {
      filteredSOPs = filteredSOPs
          .where((sop) => sop.categoryName == _selectedCategory)
          .toList();
    }

    // Sort SOPs alphabetically by title for the alphabet index
    filteredSOPs.sort((a, b) => a.title.compareTo(b.title));

    // Get unique categories for filter dropdown
    final categories = [
      'All',
      ...categoryService.categories.map((cat) => cat.name).toSet().toList()
    ];

    // Create AlphaModel list from SOPs for the alphabet scroller
    final List<AlphaModel> alphabetList =
        filteredSOPs.map((sop) => AlphaModel(sop.title)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _selectedCategory == 'All'
            ? const Text("SOPs", style: TextStyle(fontWeight: FontWeight.bold))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("SOPs",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _selectedCategory,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
        centerTitle: true,
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showQRScanner(context),
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.go('/mobile/editor/new');
            },
            tooltip: 'Create New SOP',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/elmos_logo.png',
                    height: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome, ${authService.userName ?? 'User'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authService.userEmail ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('SOPs'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mobile/categories');
              },
            ),
            ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Factory MES'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mes');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            // Version display
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                String version = "Version: ";
                if (snapshot.hasData) {
                  version += "${snapshot.data!.version}";
                } else {
                  version += "Loading...";
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        version,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search SOPs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category filter - updated with more prominent UI
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filter by Category:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 0),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.category,
                        color: _selectedCategory != 'All'
                            ? _getCategoryColor(_selectedCategory)
                            : Colors.grey,
                      ),
                    ),
                    value: _selectedCategory,
                    items: categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: TextStyle(
                            color: category != 'All'
                                ? _getCategoryColor(category)
                                : Colors.black,
                            fontWeight: category == _selectedCategory
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          // Reset letter selection when category changes
                          _selectedLetter = null;
                        });
                      }
                    },
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.arrow_drop_down_circle,
                      color: _selectedCategory != 'All'
                          ? _getCategoryColor(_selectedCategory)
                          : Colors.grey,
                    ),
                  ),
                ),
                if (_selectedCategory != 'All')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(_selectedCategory)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Showing only $_selectedCategory SOPs",
                                style: TextStyle(
                                  color: _getCategoryColor(_selectedCategory),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = 'All';
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: _getCategoryColor(_selectedCategory),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // SOPs list with alphabet scroll
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSOPs.isEmpty
                    ? const Center(child: Text('No SOPs found'))
                    : Row(
                        children: [
                          // Main SOP list
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Determine if we're on a tablet-sized screen
                                final isTablet = constraints.maxWidth > 600;

                                // Calculate number of columns based on width
                                final int crossAxisCount = isTablet
                                    ? (constraints.maxWidth > 900 ? 3 : 2)
                                    : 1;

                                // Use grid for tablet, list for phone
                                return crossAxisCount > 1
                                    ? GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.all(16.0),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          childAspectRatio: 1.4,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: filteredSOPs.length,
                                        itemBuilder: (context, index) {
                                          final sop = filteredSOPs[index];
                                          return _buildSOPCard(context, sop);
                                        },
                                      )
                                    : ListView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.all(16.0),
                                        itemCount: filteredSOPs.length,
                                        itemBuilder: (context, index) {
                                          final sop = filteredSOPs[index];
                                          return _buildSOPCard(context, sop);
                                        },
                                      );
                              },
                            ),
                          ),

                          // Alphabet sidebar
                          Container(
                            width: 40,
                            margin: const EdgeInsets.only(left: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                              ),
                            ),
                            // Ensure the alphabet list fills the available height
                            child: Column(
                              children: [
                                // Index title
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.red[800],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(15),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'A-Z',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                // Alphabet list
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Calculate the height for each letter based on available space
                                      final double itemHeight =
                                          constraints.maxHeight /
                                              _alphabet.length;

                                      return ListView.builder(
                                        // Make the alphabet list static by disabling scrolling
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        // Ensure it always fits the available space
                                        shrinkWrap: true,
                                        itemCount: _alphabet.length,
                                        itemBuilder: (context, index) {
                                          final letter = _alphabet[index];
                                          final bool isSelected =
                                              letter == _selectedLetter;

                                          // Check if any SOPs start with this letter
                                          final bool hasMatch = filteredSOPs
                                              .any((sop) => sop.title
                                                  .toUpperCase()
                                                  .startsWith(letter));

                                          return GestureDetector(
                                            onTap: hasMatch
                                                ? () => _scrollToLetter(
                                                    letter, filteredSOPs)
                                                : null,
                                            child: Container(
                                              height: itemHeight,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.red
                                                        .withOpacity(0.2)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                letter,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: hasMatch
                                                      ? (isSelected
                                                          ? Colors.red
                                                          : Colors.red[700])
                                                      : Colors.grey[400],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
    );
  }

  Widget _buildSOPCard(BuildContext context, SOP sop) {
    // Use the SOP thumbnail if available, otherwise fallback to the first step image
    final String? imageUrl = sop.thumbnailUrl ??
        (sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null);

    // Get category color
    final Color categoryColor =
        _getCategoryColor(sop.categoryName ?? 'Unknown');

    // Check if we're on a tablet
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    // Adjust image height based on device type
    final double imageHeight = isTablet ? 160.0 : 140.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0), // Slightly increased margin
      elevation: 3, // Increased elevation for more prominence
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: () {
          context.go('/mobile/sop/${sop.id}');
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and category badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12.0),
                    topRight: Radius.circular(12.0),
                  ),
                  child: imageUrl != null
                      ? _buildImageFromUrl(imageUrl, height: imageHeight)
                      : Container(
                          width: double.infinity,
                          height: imageHeight,
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 56, // Larger icon
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No Thumbnail",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              )
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, // Increased padding
                      vertical: 6.0, // Increased padding
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      sop.categoryName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0, // Increased font size
                        fontWeight: FontWeight.bold, // Made bold for emphasis
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Title and details
            Padding(
              padding: const EdgeInsets.all(12.0), // Increased padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sop.title,
                    style: TextStyle(
                      fontSize: 18.0, // Increased from smaller size
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0), // Increased spacing
                  Text(
                    sop.description,
                    style: TextStyle(
                      fontSize: 14.0, // Increased from smaller size
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12.0), // Increased spacing

                  // Meta info at the bottom of the card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history,
                              size: 16.0, color: Colors.grey[600]),
                          const SizedBox(width: 4.0),
                          Text(
                            _formatDate(sop.updatedAt),
                            style: TextStyle(
                              fontSize: 13.0, // Increased from smaller size
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered,
                              size: 16.0, color: Colors.grey[600]),
                          const SizedBox(width: 4.0),
                          Text(
                            '${sop.steps.length} steps',
                            style: TextStyle(
                              fontSize: 13.0, // Increased from smaller size
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromUrl(String url, {double height = 140.0}) {
    return CrossPlatformImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'assembly':
        return AppColors.blueAccent;
      case 'finishing':
        return AppColors.greenAccent;
      case 'machinery':
        return AppColors.orangeAccent;
      case 'quality':
        return AppColors.purpleAccent;
      case 'upholstery':
        return Colors.redAccent;
      default:
        return AppColors.primaryRed;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void _showQRScanner(BuildContext context) {
    final sopService = Provider.of<SOPService>(context, listen: false);
    final qrService = sopService.qrCodeService;
    final scannerService = ScannerServiceFactory.getScannerService();

    if (!scannerService.isScanningAvailable()) {
      // Show a message that scanning is not available on this platform
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR scanning is not available on this platform'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    scannerService.showQRScanner(context).then((scannedCode) {
      if (scannedCode != null) {
        final String? sopId = qrService.extractSOPIdFromQRData(scannedCode);

        if (sopId != null) {
          // Provide visual feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('QR code detected! Opening SOP...'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          // Navigate to the SOP page
          context.go('/mobile/sop/$sopId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invalid QR code. This does not appear to be an Elmo\'s Furniture SOP code.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }
}
