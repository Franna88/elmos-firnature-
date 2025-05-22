import 'package:flutter/material.dart';
import 'design_system/design_system.dart';

/// A sample page that demonstrates the design system components.
class SamplePage extends StatefulWidget {
  const SamplePage({Key? key}) : super(key: key);

  @override
  State<SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends State<SamplePage> {
  int _selectedSidebarIndex = 0;
  String _searchQuery = '';

  // Sample sidebar items
  final List<AppSidebarItem> _sidebarItems = [
    AppSidebarItem(
      label: 'Dashboard',
      icon: Icons.dashboard,
    ),
    AppSidebarItem(
      label: 'SOPs',
      icon: Icons.description,
      badge: '5',
    ),
    AppSidebarItem(
      label: 'Production',
      icon: Icons.precision_manufacturing,
    ),
    AppSidebarItem(
      label: 'Users',
      icon: Icons.people,
    ),
    AppSidebarItem(
      label: 'Media',
      icon: Icons.perm_media,
    ),
    AppSidebarItem(
      label: 'Settings',
      icon: Icons.settings,
    ),
  ];

  // Sample header actions
  final List<AppHeaderAction> _headerActions = [
    AppHeaderAction(
      icon: Icons.notifications,
      label: 'Notifications',
      onPressed: () {},
    ),
    AppHeaderAction(
      icon: Icons.help_outline,
      label: 'Help',
      onPressed: () {},
    ),
    AppHeaderAction(
      icon: Icons.account_circle,
      label: 'Profile',
      onPressed: () {},
      showAsButton: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Elmos Furniture',
      sidebarItems: _sidebarItems,
      selectedSidebarIndex: _selectedSidebarIndex,
      onSidebarItemSelected: (index) {
        setState(() {
          _selectedSidebarIndex = index;
        });
      },
      actions: _headerActions,
      sidebarHeader: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'ELMOS',
          style: AppTypography.headingLarge(color: AppColors.primary),
          textAlign: TextAlign.center,
        ),
      ),
      showSearchBar: true,
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show different content based on selected sidebar item
    switch (_selectedSidebarIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildSOPsContent();
      default:
        return Center(
          child: Text(
            'Content for ${_sidebarItems[_selectedSidebarIndex].label}',
            style: AppTypography.headingLarge(),
          ),
        );
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: AppTypography.displaySmall(),
          ),
          SizedBox(height: 24),

          // Stats cards row
          ResponsiveBuilder(
            builder: (context, screenSize) {
              // Determine the layout based on screen size
              if (screenSize == ScreenSize.mobile) {
                return Column(
                  children: _buildStatCards(),
                );
              } else {
                return Row(
                  children: _buildStatCards()
                      .map((card) => Expanded(child: card))
                      .toList(),
                );
              }
            },
          ),

          SizedBox(height: 24),

          // Recent SOPs section
          AppCard(
            header: AppCardHeader(
              title: 'Recent SOPs',
              action: AppButton(
                label: 'View All',
                variant: ButtonVariant.tertiary,
                onPressed: () {},
              ),
            ),
            content: Column(
              children: [
                ListTile(
                  title: Text('Furniture Assembly Procedure',
                      style: AppTypography.bodyLarge()),
                  subtitle: Text('Updated 2 days ago',
                      style: AppTypography.bodySmall()),
                  leading: Icon(Icons.description, color: AppColors.primary),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(),
                ListTile(
                  title: Text('Quality Control Checklist',
                      style: AppTypography.bodyLarge()),
                  subtitle: Text('Updated 3 days ago',
                      style: AppTypography.bodySmall()),
                  leading: Icon(Icons.description, color: AppColors.primary),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(),
                ListTile(
                  title: Text('Material Handling Guidelines',
                      style: AppTypography.bodyLarge()),
                  subtitle: Text('Updated 1 week ago',
                      style: AppTypography.bodySmall()),
                  leading: Icon(Icons.description, color: AppColors.primary),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Form example
          AppCard(
            header: AppCardHeader(title: 'Quick Actions'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'SOP Title',
                  placeholder: 'Enter SOP title',
                  required: true,
                ),
                SizedBox(height: 16),
                AppTextField(
                  label: 'Description',
                  placeholder: 'Enter description',
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Category',
                        placeholder: 'Select category',
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        label: 'Priority',
                        placeholder: 'Select priority',
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Cancel',
                      variant: ButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    SizedBox(width: 16),
                    AppButton(
                      label: 'Create SOP',
                      variant: ButtonVariant.primary,
                      onPressed: () {},
                      leadingIcon: Icons.add,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatCards() {
    return [
      AppCard(
        margin: EdgeInsets.all(8),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total SOPs', style: AppTypography.labelLarge()),
                Icon(Icons.description, color: AppColors.primary),
              ],
            ),
            SizedBox(height: 8),
            Text('128', style: AppTypography.displayMedium()),
            SizedBox(height: 8),
            Text('12 added this month',
                style: AppTypography.bodySmall(color: AppColors.success)),
          ],
        ),
      ),
      AppCard(
        margin: EdgeInsets.all(8),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Users', style: AppTypography.labelLarge()),
                Icon(Icons.people, color: AppColors.secondary),
              ],
            ),
            SizedBox(height: 8),
            Text('45', style: AppTypography.displayMedium()),
            SizedBox(height: 8),
            Text('5 new users this week',
                style: AppTypography.bodySmall(color: AppColors.success)),
          ],
        ),
      ),
      AppCard(
        margin: EdgeInsets.all(8),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Production Status', style: AppTypography.labelLarge()),
                Icon(Icons.precision_manufacturing, color: AppColors.accent),
              ],
            ),
            SizedBox(height: 8),
            Text('Active',
                style: AppTypography.displayMedium(color: AppColors.success)),
            SizedBox(height: 8),
            Text('All systems operational', style: AppTypography.bodySmall()),
          ],
        ),
      ),
    ];
  }

  Widget _buildSOPsContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Standard Operating Procedures',
            style: AppTypography.displaySmall(),
          ),
          SizedBox(height: 24),

          // Filters row
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  placeholder: 'Search SOPs',
                  prefixIcon: Icon(Icons.search),
                  variant: TextFieldVariant.filled,
                ),
              ),
              SizedBox(width: 16),
              AppButton(
                label: 'Filter',
                variant: ButtonVariant.secondary,
                onPressed: () {},
                leadingIcon: Icons.filter_list,
              ),
              SizedBox(width: 16),
              AppButton(
                label: 'New SOP',
                variant: ButtonVariant.primary,
                onPressed: () {},
                leadingIcon: Icons.add,
              ),
            ],
          ),

          SizedBox(height: 24),

          // SOPs grid
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            largeDesktopColumns: 4,
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              8,
              (index) => AppCard(
                onTap: () {},
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SOP #${1001 + index}',
                            style: AppTypography.labelMedium(
                                color: AppColors.textTertiary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.star,
                          color: index % 3 == 0
                              ? AppColors.warning
                              : AppColors.grey200,
                          size: 20,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Furniture Assembly Procedure ${index + 1}',
                      style: AppTypography.headingSmall(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This SOP outlines the step-by-step process for assembling furniture items safely and efficiently.',
                      style: AppTypography.bodySmall(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Assembly',
                            style: AppTypography.labelSmall(),
                          ),
                        ),
                        Text(
                          'Updated 2d ago',
                          style: AppTypography.caption(
                              color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
