class AnalyticsData {
  final int totalSops;
  final int totalTemplates;
  final int sopCreatedThisMonth;
  final int sopUpdatedThisMonth;
  final Map<String, int> sopsByDepartment;
  final Map<String, int> templateUsageCount;
  final List<ActivityItem> recentActivity;
  final List<ChartData> sopCreationTrend;

  AnalyticsData({
    required this.totalSops,
    required this.totalTemplates,
    required this.sopCreatedThisMonth,
    required this.sopUpdatedThisMonth,
    required this.sopsByDepartment,
    required this.templateUsageCount,
    required this.recentActivity,
    required this.sopCreationTrend,
  });
}

class ActivityItem {
  final String id;
  final String title;
  final ActivityType type;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String? sopId;
  final String? sopTitle;

  ActivityItem({
    required this.id,
    required this.title,
    required this.type,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.sopId,
    this.sopTitle,
  });
}

enum ActivityType {
  sopCreated,
  sopUpdated,
  sopDeleted,
  templateCreated,
  templateUsed,
  userLoggedIn,
  userSignedUp,
}

class ChartData {
  final DateTime date;
  final int value;

  ChartData({required this.date, required this.value});
}
