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
          // Search bar and category filter in the same row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Check if we're on a tablet or a phone
                final bool isTablet = constraints.maxWidth > 600;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar - takes more space
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show label for both tablet and phone, but smaller on phones
                          Text(
                            "Search:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 14.0 : 12.0,
                            ),
                          ),
                          SizedBox(height: isTablet ? 4.0 : 2.0),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search SOPs...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12.0),

                    // Category filter dropdown - takes less space
                    Expanded(
                      flex: isTablet ? 2 : 3, // Give more space on phones
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show label for both tablet and phone, but smaller on phones
                          Text(
                            "Category:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 14.0 : 12.0,
                            ),
                          ),
                          SizedBox(height: isTablet ? 4.0 : 2.0),
                          Container(
                            height: 48, // Match the search bar height
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.grey.shade50,
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 16.0 : 8.0,
                                    vertical: 0),
                                border: InputBorder.none,
                                prefixIcon: Icon(
                                  Icons.category,
                                  color: _selectedCategory != 'All'
                                      ? _getCategoryColorByName(
                                          _selectedCategory, categoryService)
                                      : Colors.grey,
                                  size: isTablet ? 24 : 20,
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
                                          ? _getCategoryColorByName(
                                              category, categoryService)
                                          : Colors.black,
                                      fontWeight: category == _selectedCategory
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: isTablet ? 14 : 13,
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
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              isDense: !isTablet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Show selected category chip if not All
          if (_selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColorByName(
                              _selectedCategory, categoryService)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getCategoryColorByName(
                                _selectedCategory, categoryService)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category,
                          size: 16,
                          color: _getCategoryColorByName(
                              _selectedCategory, categoryService),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedCategory,
                          style: TextStyle(
                            color: _getCategoryColorByName(
                                _selectedCategory, categoryService),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                            color: _getCategoryColorByName(
                                _selectedCategory, categoryService),
                          ),
                        )
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
    // Use the SOP thumbnail if available, otherwise fallback to first step image
    final String? imageUrl = sop.thumbnailUrl ??
        (sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null);

    // Get category color from the actual category data
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    final Color categoryColor =
        _getCategoryColor(sop.categoryId, categoryService);

    // Check if we're on a tablet
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    // Adjust image height based on device type
    final double imageHeight = isTablet ? 160.0 : 120.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // Show a loading indicator
          final sopService = Provider.of<SOPService>(context, listen: false);

          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      Text('Loading images...'),
                    ],
                  ),
                ),
              );
            },
          );

          // Preload all images for this SOP before navigating
          await sopService.forcePreloadSOP(sop.id);

          // Close the dialog after preloading is complete
          if (context.mounted) {
            Navigator.of(context).pop();

            // Now navigate to the SOP viewer
            context.go('/mobile/sop/${sop.id}');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category header at the top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sop.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rev ${sop.revisionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image section
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: imageUrl != null
                  ? CrossPlatformImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: _buildImageError(),
                    )
                  : _buildImageError(),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "Category | : ${sop.categoryName ?? "Unknown"}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF4A5363),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description (if available)
                  if (sop.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sop.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Stats in a row
                  Row(
                    children: [
                      const Icon(
                        Icons.format_list_numbered,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sop.steps.length} steps',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(sop.updatedAt),
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
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

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 24,
          color: AppColors.textLight.withOpacity(0.5),
        ),
      ),
    );
  }

  Color _getCategoryColor(String categoryId, CategoryService categoryService) {
    // Default to a shade of blue if category is empty
    if (categoryId.isEmpty) {
      return AppColors.primaryBlue;
    }

    // Look up the category and get its color
    final category = categoryService.getCategoryById(categoryId);
    if (category != null &&
        category.color != null &&
        category.color!.startsWith('#')) {
      try {
        // Parse hex color string to Color object
        return Color(int.parse('FF${category.color!.substring(1)}', radix: 16));
      } catch (e) {
        // If parsing fails, fall back to default
        return AppColors.primaryBlue;
      }
    }

    // Fallback to a default color if category is not found or has no color
    return AppColors.primaryBlue;
  }

  // Helper method to get category color by name (for the dropdown interface)
  Color _getCategoryColorByName(
      String categoryName, CategoryService categoryService) {
    if (categoryName == 'All') {
      return Colors.grey;
    }

    // Find category by name
    final category = categoryService.categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () =>
          categoryService.categories.first, // fallback to first category
    );

    return _getCategoryColor(category.id, categoryService);
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
