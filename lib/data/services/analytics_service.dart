import 'package:flutter/foundation.dart';
import '../models/analytics_model.dart';
import 'auth_service.dart';
import 'sop_service.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AnalyticsService extends ChangeNotifier {
  final SOPService _sopService;
  final AuthService _authService;

  // Firebase services
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  SharedPreferences? _prefs;

  late AnalyticsData _analyticsData;
  List<ActivityItem> _activities = [];

  // Flag to track if we're using local analytics
  bool _usingLocalAnalytics = false;

  // Local analytics data
  final Map<String, int> _localEvents = {};

  bool get usingLocalAnalytics => _usingLocalAnalytics;

  AnalyticsService({
    required SOPService sopService,
    required AuthService authService,
  })  : _sopService = sopService,
        _authService = authService {
    _initialize();

    // Listen for data changes
    _listenForActivityChanges();
  }

  AnalyticsData get analyticsData => _analyticsData;
  List<ActivityItem> get recentActivities => List.unmodifiable(_activities);

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Initialize Firebase services
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;

      // Test if Firebase is working by accessing Firestore
      await _firestore!.collection('test').limit(1).get();

      if (kDebugMode) {
        print('Using Firebase for analytics');
      }

      // Load initial data
      await _loadActivities();
      await _generateAnalyticsData();
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization error in AnalyticsService: $e');
        print('Using local analytics instead');
      }
      _usingLocalAnalytics = true;

      // Load local analytics from shared preferences if available
      _loadLocalEvents();

      // Generate sample data
      _generateSampleActivities();
      _generateFallbackAnalyticsData();
    }
  }

  Future<void> _loadLocalEvents() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final localEventsJson = _prefs!.getString('local_analytics_events');
      if (localEventsJson != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          Map<String, dynamic>.from(
            jsonDecode(localEventsJson) as Map,
          ),
        );

        _localEvents.clear();
        data.forEach((key, value) {
          if (value is int) {
            _localEvents[key] = value;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading local analytics: $e');
      }
    }
  }

  Future<void> _saveLocalEvents() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      await _prefs!
          .setString('local_analytics_events', jsonEncode(_localEvents));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving local analytics: $e');
      }
    }
  }

  void _listenForActivityChanges() {
    if (_usingLocalAnalytics) return;

    final userId = _auth?.currentUser?.uid;
    if (userId == null) return;

    try {
      if (_firestore != null) {
        _firestore!
            .collection('activities')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots()
            .listen((snapshot) {
          _loadActivities();
          _generateAnalyticsData();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error listening for activity changes: $e');
      }
    }
  }

  Future<void> _loadActivities() async {
    if (_usingLocalAnalytics) {
      _generateSampleActivities();
      return;
    }

    try {
      final userId = _auth?.currentUser?.uid;
      if (userId == null) {
        _activities = [];
        notifyListeners();
        return;
      }

      if (_firestore == null) {
        _generateSampleActivities();
        return;
      }

      final snapshot = await _firestore!
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final List<ActivityItem> loadedActivities = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedActivities.add(ActivityItem(
          id: doc.id,
          title: data['title'] ?? '',
          type: _activityTypeFromString(data['type'] ?? ''),
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? '',
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          sopId: data['sopId'],
          sopTitle: data['sopTitle'],
        ));
      }

      _activities = loadedActivities;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading activities: $e');
      }
      // If error loading, generate some sample activities
      _generateSampleActivities();
    }
  }

  ActivityType _activityTypeFromString(String typeString) {
    switch (typeString) {
      case 'sopCreated':
        return ActivityType.sopCreated;
      case 'sopUpdated':
        return ActivityType.sopUpdated;
      case 'sopDeleted':
        return ActivityType.sopDeleted;
      case 'templateCreated':
        return ActivityType.templateCreated;
      case 'templateUsed':
        return ActivityType.templateUsed;
      case 'userLoggedIn':
        return ActivityType.userLoggedIn;
      case 'userSignedUp':
        return ActivityType.userSignedUp;
      default:
        return ActivityType.sopCreated;
    }
  }

  String _activityTypeToString(ActivityType type) {
    switch (type) {
      case ActivityType.sopCreated:
        return 'sopCreated';
      case ActivityType.sopUpdated:
        return 'sopUpdated';
      case ActivityType.sopDeleted:
        return 'sopDeleted';
      case ActivityType.templateCreated:
        return 'templateCreated';
      case ActivityType.templateUsed:
        return 'templateUsed';
      case ActivityType.userLoggedIn:
        return 'userLoggedIn';
      case ActivityType.userSignedUp:
        return 'userSignedUp';
    }
  }

  void _generateSampleActivities() {
    // Generate mock activity data
    final now = DateTime.now();
    final userId = _authService.userId ?? 'user_123';
    final userName = _authService.userName ?? 'User';

    _activities = [];

    // Create some mock activities
    for (int i = 0; i < 10; i++) {
      final sop = i < _sopService.sops.length ? _sopService.sops[i] : null;

      final type = ActivityType.values[i % ActivityType.values.length];
      final daysAgo = i * 2; // Space out activities

      _activities.add(
        ActivityItem(
          id: const Uuid().v4(),
          title: _getActivityTitle(type, sop?.title),
          type: type,
          userId: userId,
          userName: userName,
          timestamp: now.subtract(Duration(days: daysAgo)),
          sopId: sop?.id,
          sopTitle: sop?.title,
        ),
      );
    }

    notifyListeners();
  }

  Future<void> _generateAnalyticsData() async {
    if (_usingLocalAnalytics) {
      _generateFallbackAnalyticsData();
      return;
    }

    try {
      final userId = _auth?.currentUser?.uid;
      if (userId == null) return;

      if (_firestore == null) {
        _generateFallbackAnalyticsData();
        return;
      }

      // Get count of SOPs by department
      final sopsSnapshot = await _firestore!
          .collection('sops')
          .where('createdBy', isEqualTo: userId)
          .get();

      final Map<String, int> deptsCount = {};
      final DateTime now = DateTime.now();
      final DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
      int sopCreatedThisMonth = 0;
      int sopUpdatedThisMonth = 0;

      for (var doc in sopsSnapshot.docs) {
        final data = doc.data();
        final department = data['department'] as String? ?? 'Unknown';
        deptsCount[department] = (deptsCount[department] ?? 0) + 1;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (createdAt != null && createdAt.isAfter(firstDayOfMonth)) {
          sopCreatedThisMonth++;
        }

        if (updatedAt != null &&
            updatedAt.isAfter(firstDayOfMonth) &&
            (createdAt == null || updatedAt.isAfter(createdAt))) {
          sopUpdatedThisMonth++;
        }
      }

      // Generate template usage count
      final Map<String, int> templateUsage = {};

      final templateUsageSnapshot = await _firestore!
          .collection('templateUsage')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in templateUsageSnapshot.docs) {
        final data = doc.data();
        final templateId = data['templateId'] as String? ?? '';
        final templateTitle = data['templateTitle'] as String? ?? 'Unknown';

        templateUsage[templateTitle] = (templateUsage[templateTitle] ?? 0) + 1;
      }

      // If no template usage data, generate sample data
      if (templateUsage.isEmpty) {
        for (final template in _sopService.templates) {
          templateUsage[template.title] = (2 + template.id.hashCode % 10);
        }
      }

      // Generate SOP creation trend
      final List<ChartData> trend = [];

      // Get data for last 12 months
      for (int i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);

        final monthlySOPsSnapshot = await _firestore!
            .collection('sops')
            .where('createdBy', isEqualTo: userId)
            .where('createdAt', isGreaterThanOrEqualTo: month)
            .where('createdAt', isLessThan: nextMonth)
            .get();

        trend.add(
          ChartData(
            date: month,
            value: monthlySOPsSnapshot.docs.length,
          ),
        );
      }

      // Reverse to get chronological order
      trend.sort((a, b) => a.date.compareTo(b.date));

      // Create analytics data
      _analyticsData = AnalyticsData(
        totalSops: sopsSnapshot.docs.length,
        totalTemplates: _sopService.templates.length,
        sopCreatedThisMonth: sopCreatedThisMonth,
        sopUpdatedThisMonth: sopUpdatedThisMonth,
        sopsByDepartment: deptsCount,
        templateUsageCount: templateUsage,
        recentActivity: _activities,
        sopCreationTrend: trend,
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error generating analytics data: $e');
      }

      // Generate fallback data
      _generateFallbackAnalyticsData();
    }
  }

  void _generateFallbackAnalyticsData() {
    // Generate department distribution
    final Map<String, int> deptsCount = {};
    for (final sop in _sopService.sops) {
      deptsCount[sop.categoryName ?? 'Unknown'] =
          (deptsCount[sop.categoryName ?? 'Unknown'] ?? 0) + 1;
    }

    // Generate template usage
    final Map<String, int> templateUsage = {};
    for (final template in _sopService.templates) {
      templateUsage[template.title] = (templateUsage[template.title] ?? 0) +
          (2 + template.id.hashCode % 10); // Random usage count
    }

    // Generate SOP creation trend
    final now = DateTime.now();
    final List<ChartData> trend = [];
    for (int i = 0; i < 12; i++) {
      trend.add(
        ChartData(
          date: DateTime(now.year, now.month - i),
          value: 5 + (i * 7) % 10, // Random creation count
        ),
      );
    }

    // Reverse to get chronological order
    trend.sort((a, b) => a.date.compareTo(b.date));

    // Create analytics data
    _analyticsData = AnalyticsData(
      totalSops: _sopService.sops.length,
      totalTemplates: _sopService.templates.length,
      sopCreatedThisMonth: 3,
      sopUpdatedThisMonth: 7,
      sopsByDepartment: deptsCount,
      templateUsageCount: templateUsage,
      recentActivity: _activities,
      sopCreationTrend: trend,
    );

    notifyListeners();
  }

  Future<void> recordActivity(ActivityType type,
      {String? sopId, String? sopTitle}) async {
    final now = DateTime.now();
    final userId = _auth?.currentUser?.uid;
    final userName = _authService.userName ?? 'User';

    if (userId == null) return;

    final activity = ActivityItem(
      id: const Uuid().v4(),
      title: _getActivityTitle(type, sopTitle),
      type: type,
      userId: userId,
      userName: userName,
      timestamp: now,
      sopId: sopId,
      sopTitle: sopTitle,
    );

    try {
      // Save to Firestore if available
      if (!_usingLocalAnalytics && _firestore != null) {
        await _firestore!.collection('activities').doc(activity.id).set({
          'title': activity.title,
          'type': _activityTypeToString(activity.type),
          'userId': activity.userId,
          'userName': activity.userName,
          'timestamp': Timestamp.fromDate(activity.timestamp),
          'sopId': activity.sopId,
          'sopTitle': activity.sopTitle,
        });

        // Record template usage if applicable
        if (type == ActivityType.templateUsed && sopId != null) {
          await _firestore!.collection('templateUsage').add({
            'userId': userId,
            'templateId': sopId,
            'templateTitle': sopTitle,
            'timestamp': Timestamp.fromDate(now),
          });
        }
      }

      // Update local list for immediate UI update
      _activities.insert(0, activity);
      if (_activities.length > 50) {
        _activities.removeLast();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error recording activity: $e');
      }
    }
  }

  String _getActivityTitle(ActivityType type, String? sopTitle) {
    final String sopName = sopTitle ?? 'a SOP';

    switch (type) {
      case ActivityType.sopCreated:
        return 'Created $sopName';
      case ActivityType.sopUpdated:
        return 'Updated $sopName';
      case ActivityType.sopDeleted:
        return 'Deleted $sopName';
      case ActivityType.templateCreated:
        return 'Created a new template';
      case ActivityType.templateUsed:
        return 'Used a template to create $sopName';
      case ActivityType.userLoggedIn:
        return 'Logged in to the system';
      case ActivityType.userSignedUp:
        return 'Signed up to the system';
    }
  }

  Future<void> refreshAnalytics() async {
    await _loadActivities();
    await _generateAnalyticsData();
  }

  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    if (_usingLocalAnalytics) {
      // Store event locally
      _localEvents[name] = (_localEvents[name] ?? 0) + 1;

      // Add parameters to event name if present
      if (parameters != null && parameters.isNotEmpty) {
        parameters.forEach((key, value) {
          final paramKey = '${name}_$key';
          if (value is int) {
            _localEvents[paramKey] = (_localEvents[paramKey] ?? 0) + value;
          } else {
            _localEvents[paramKey] = (_localEvents[paramKey] ?? 0) + 1;
          }
        });
      }

      // Save to shared preferences
      await _saveLocalEvents();

      if (kDebugMode) {
        print('Local analytics event logged: $name');
        if (parameters != null) {
          print('Parameters: $parameters');
        }
      }
      return;
    }

    try {
      // Log to Firestore for custom analytics dashboard
      if (_firestore != null) {
        final userId = _auth?.currentUser?.uid;
        if (userId != null) {
          final eventData = {
            'userId': userId,
            'eventName': name,
            'timestamp': FieldValue.serverTimestamp(),
            'parameters': parameters,
          };

          await _firestore!.collection('analytics_events').add(eventData);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging analytics event: $e');
      }

      // Fall back to local analytics if Firebase fails
      if (!_usingLocalAnalytics) {
        _usingLocalAnalytics = true;
        await logEvent(name, parameters: parameters);
      }
    }
  }

  Future<void> logLogin({String? loginMethod}) async {
    await logEvent('login', parameters: {'method': loginMethod ?? 'email'});
  }

  Future<void> logSignUp({String? signUpMethod}) async {
    await logEvent('sign_up', parameters: {'method': signUpMethod ?? 'email'});
  }

  Future<void> logScreenView(String screenName) async {
    await logEvent('screen_view', parameters: {'screen_name': screenName});
  }

  Future<void> logSOPCreated(String sopId, String sopTitle) async {
    await logEvent('sop_created', parameters: {
      'sop_id': sopId,
      'sop_title': sopTitle,
    });
  }

  Future<void> logSOPEdited(String sopId, String sopTitle) async {
    await logEvent('sop_edited', parameters: {
      'sop_id': sopId,
      'sop_title': sopTitle,
    });
  }

  Future<void> logSOPDeleted(String sopId, String sopTitle) async {
    await logEvent('sop_deleted', parameters: {
      'sop_id': sopId,
      'sop_title': sopTitle,
    });
  }

  Future<void> logUserAction(String action,
      {Map<String, dynamic>? details}) async {
    await logEvent('user_action', parameters: {
      'action': action,
      ...?details,
    });
  }

  Future<void> setUserProperty(String name, String value) async {
    if (_usingLocalAnalytics) {
      // Store user property locally
      final propertyKey = 'user_property_$name';
      _localEvents[propertyKey] = value.hashCode;
      await _saveLocalEvents();

      if (kDebugMode) {
        print('Local user property set: $name = $value');
      }
    }
  }

  Future<void> setUserId(String userId) async {
    if (_usingLocalAnalytics) {
      await setUserProperty('user_id', userId);
    }
  }

  Map<String, int> getLocalEventCounts() {
    return Map.unmodifiable(_localEvents);
  }
}
