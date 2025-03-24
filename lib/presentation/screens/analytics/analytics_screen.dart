import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/analytics_model.dart';
import '../../../data/services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
      await analyticsService.refreshAnalytics();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Charts'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildChartsTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<AnalyticsService>(
      builder: (context, analyticsService, child) {
        final analytics = analyticsService.analyticsData;

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total SOPs',
                        value: analytics.totalSops.toString(),
                        icon: Icons.description,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Templates',
                        value: analytics.totalTemplates.toString(),
                        icon: Icons.category,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Created This Month',
                        value: analytics.sopCreatedThisMonth.toString(),
                        icon: Icons.add_circle_outline,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Updated This Month',
                        value: analytics.sopUpdatedThisMonth.toString(),
                        icon: Icons.update,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent activity preview
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: analytics.recentActivity.length > 5
                        ? 5
                        : analytics.recentActivity.length,
                    itemBuilder: (context, index) {
                      final activity = analytics.recentActivity[index];
                      return ListTile(
                        leading: _getActivityIcon(activity.type),
                        title: Text(activity.title),
                        subtitle: Text(
                          'By ${activity.userName} • ${_formatDateTime(activity.timestamp)}',
                        ),
                        trailing: activity.sopId != null
                            ? IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () {
                                  // Navigate to the SOP
                                  if (activity.sopId != null) {
                                    context.go('/editor/${activity.sopId}');
                                  }
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      _tabController.animateTo(2); // Switch to Activity tab
                    },
                    child: const Text('View All Activity'),
                  ),
                ),
                const SizedBox(height: 24),

                // Department distribution
                Text(
                  'SOPs by Department',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...analytics.sopsByDepartment.entries.map((entry) {
                          final percentage = analytics.totalSops > 0
                              ? (entry.value / analytics.totalSops) * 100
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key),
                                    Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: analytics.totalSops > 0
                                      ? entry.value / analytics.totalSops
                                      : 0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getDepartmentColor(entry.key),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartsTab() {
    return Consumer<AnalyticsService>(
      builder: (context, analyticsService, child) {
        final analytics = analyticsService.analyticsData;

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOP Creation Trend
                Text(
                  'SOP Creation Trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 200,
                      child: _buildChart(analytics.sopCreationTrend),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Template Usage
                Text(
                  'Template Usage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...analytics.templateUsageCount.entries
                            .toList()
                            .sorted((a, b) => b.value.compareTo(a.value))
                            .take(5) // Top 5 templates
                            .map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text('${entry.value} uses'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: analytics.templateUsageCount.values
                                          .fold(0, (a, b) => a + b) >
                                      0
                                      ? entry.value /
                                          analytics.templateUsageCount.values
                                              .reduce((a, b) => a > b ? a : b)
                                      : 0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Activity by Type
                Text(
                  'Activity by Type',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildActivityDistributionChart(analytics.recentActivity),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    return Consumer<AnalyticsService>(
      builder: (context, analyticsService, child) {
        final activities = analyticsService.recentActivities;

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              if (index == 0 || !_isSameDay(activities[index].timestamp, activities[index - 1].timestamp)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _formatDateHeader(activities[index].timestamp),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    _buildActivityItem(activities[index]),
                  ],
                );
              }
              return _buildActivityItem(activities[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _getActivityIcon(activity.type),
        title: Text(activity.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By ${activity.userName}',
            ),
            Text(
              _formatTime(activity.timestamp),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: activity.sopId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  // Navigate to the SOP
                  if (activity.sopId != null) {
                    context.go('/editor/${activity.sopId}');
                  }
                },
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<ChartData> data) {
    // Simple chart implementation
    // In a real app, you would use a chart library like fl_chart
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final barWidth = width / (data.length + 1);

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((item) {
                  final barHeight = item.value > 0
                      ? height * 0.8 * (item.value / maxValue)
                      : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: barHeight,
                            width: barWidth - 4,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: data.map((item) {
                return Expanded(
                  child: Text(
                    DateFormat('MMM').format(item.date),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityDistributionChart(List<ActivityItem> activities) {
    // Count activities by type
    final Map<ActivityType, int> counts = {};
    for (final activity in activities) {
      counts[activity.type] = (counts[activity.type] ?? 0) + 1;
    }

    // Create data for visualization
    final total = counts.values.fold(0, (a, b) => a + b);

    return Column(
      children: ActivityType.values.map((type) {
        final count = counts[type] ?? 0;
        final percentage = total > 0 ? (count / total) * 100 : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _getActivityIcon(type),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_getActivityTypeName(type)),
                        Text('${percentage.toStringAsFixed(1)}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: total > 0 ? count / total : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getActivityTypeColor(type),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Icon _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.sopCreated:
        return const Icon(Icons.add_circle, color: Colors.green);
      case ActivityType.sopUpdated:
        return const Icon(Icons.edit, color: Colors.orange);
      case ActivityType.sopDeleted:
        return const Icon(Icons.delete, color: Colors.red);
      case ActivityType.templateCreated:
        return const Icon(Icons.category, color: Colors.blue);
      case ActivityType.templateUsed:
        return const Icon(Icons.content_copy, color: Colors.purple);
      case ActivityType.userLoggedIn:
        return const Icon(Icons.login, color: Colors.teal);
    }
  }

  Color _getActivityTypeColor(ActivityType type) {
    switch (type) {
      case ActivityType.sopCreated:
        return Colors.green;
      case ActivityType.sopUpdated:
        return Colors.orange;
      case ActivityType.sopDeleted:
        return Colors.red;
      case ActivityType.templateCreated:
        return Colors.blue;
      case ActivityType.templateUsed:
        return Colors.purple;
      case ActivityType.userLoggedIn:
        return Colors.teal;
    }
  }

  String _getActivityTypeName(ActivityType type) {
    switch (type) {
      case ActivityType.sopCreated:
        return 'SOP Created';
      case ActivityType.sopUpdated:
        return 'SOP Updated';
      case ActivityType.sopDeleted:
        return 'SOP Deleted';
      case ActivityType.templateCreated:
        return 'Template Created';
      case ActivityType.templateUsed:
        return 'Template Used';
      case ActivityType.userLoggedIn:
        return 'User Login';
    }
  }

  Color _getDepartmentColor(String department) {
    // Generate a color based on the department name
    final colorValue = department.hashCode % Colors.primaries.length;
    return Colors.primaries[colorValue];
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      return 'Today at ${DateFormat.jm().format(dateTime)}';
    } else if (difference.inDays < 2) {
      return 'Yesterday at ${DateFormat.jm().format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 'Today';
    } else if (dateOnly.isAtSameMomentAs(DateTime(yesterday.year, yesterday.month, yesterday.day))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(dateTime);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

extension ListExtension<T> on List<T> {
  List<T> sorted(int Function(T a, T b) compare) {
    final List<T> result = List<T>.from(this);
    result.sort(compare);
    return result;
  }
} 