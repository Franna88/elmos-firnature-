import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for production items used in the timer system
/// This extends the MES system for production tracking
class ProductionItem {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int estimatedTimeInMinutes;
  final int qtyPerCycle;
  final int finishedQty;
  final int targetQty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionItem({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.estimatedTimeInMinutes,
    this.qtyPerCycle = 1,
    this.finishedQty = 0,
    this.targetQty = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory ProductionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductionItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      estimatedTimeInMinutes: data['estimatedTimeInMinutes'] ?? 0,
      qtyPerCycle: data['qtyPerCycle'] ?? 1,
      finishedQty: data['finishedQty'] ?? 0,
      targetQty: data['targetQty'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'estimatedTimeInMinutes': estimatedTimeInMinutes,
      'qtyPerCycle': qtyPerCycle,
      'finishedQty': finishedQty,
      'targetQty': targetQty,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with updated fields
  ProductionItem copyWith({
    String? name,
    String? description,
    String? imageUrl,
    int? estimatedTimeInMinutes,
    int? qtyPerCycle,
    int? finishedQty,
    int? targetQty,
    bool? isActive,
  }) {
    return ProductionItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      estimatedTimeInMinutes:
          estimatedTimeInMinutes ?? this.estimatedTimeInMinutes,
      qtyPerCycle: qtyPerCycle ?? this.qtyPerCycle,
      finishedQty: finishedQty ?? this.finishedQty,
      targetQty: targetQty ?? this.targetQty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert from MESItem for compatibility
  factory ProductionItem.fromMESItem(dynamic mesItem) {
    return ProductionItem(
      id: mesItem.id,
      name: mesItem.name,
      description: mesItem.description,
      imageUrl: mesItem.imageUrl,
      estimatedTimeInMinutes: mesItem.estimatedTimeInMinutes,
      qtyPerCycle: 1, // Default value
      finishedQty: 0, // Default value
      targetQty: 0, // Default value
      isActive: mesItem.isActive,
      createdAt: mesItem.createdAt,
      updatedAt: mesItem.updatedAt,
    );
  }
}

/// Timer action types for production tracking
enum TimerActionType {
  setup('Setup'),
  jobComplete('Job Complete'),
  shutdown('Shutdown'),
  counting('Counting'),
  production('Production');

  const TimerActionType(this.displayName);
  final String displayName;
}

/// Model for tracking timer action states
class TimerActionState {
  final TimerActionType type;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isActive;

  TimerActionState({
    required this.type,
    this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.isActive = false,
  });

  // Create a copy with updated fields
  TimerActionState copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    bool? isActive,
  }) {
    return TimerActionState(
      type: type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isActive: isActive ?? this.isActive,
    );
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'isActive': isActive,
    };
  }

  // Create from map
  factory TimerActionState.fromMap(Map<String, dynamic> map) {
    return TimerActionState(
      type: TimerActionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TimerActionType.setup,
      ),
      startTime:
          map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      durationSeconds: map['durationSeconds'] ?? 0,
      isActive: map['isActive'] ?? false,
    );
  }
}

/// Model for production session tracking
class ProductionSession {
  final String id;
  final String? itemId;
  final String? itemName;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<TimerActionType, TimerActionState> actionStates;
  final int cycleCount;
  final bool isActive;

  ProductionSession({
    required this.id,
    this.itemId,
    this.itemName,
    required this.startTime,
    this.endTime,
    Map<TimerActionType, TimerActionState>? actionStates,
    this.cycleCount = 0,
    this.isActive = true,
  }) : actionStates = actionStates ?? _createDefaultActionStates();

  // Create default action states
  static Map<TimerActionType, TimerActionState> _createDefaultActionStates() {
    return {
      for (TimerActionType type in TimerActionType.values)
        type: TimerActionState(type: type),
    };
  }

  // Create a copy with updated fields
  ProductionSession copyWith({
    String? itemId,
    String? itemName,
    DateTime? endTime,
    Map<TimerActionType, TimerActionState>? actionStates,
    int? cycleCount,
    bool? isActive,
  }) {
    return ProductionSession(
      id: id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      actionStates: actionStates ?? this.actionStates,
      cycleCount: cycleCount ?? this.cycleCount,
      isActive: isActive ?? this.isActive,
    );
  }

  // Get current active action
  TimerActionType? get currentActiveAction {
    for (var entry in actionStates.entries) {
      if (entry.value.isActive) {
        return entry.key;
      }
    }
    return null;
  }

  // Get total session time
  int get totalSessionTimeSeconds {
    if (endTime != null) {
      return endTime!.difference(startTime).inSeconds;
    }
    return DateTime.now().difference(startTime).inSeconds;
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'actionStates': actionStates.map(
        (key, value) => MapEntry(key.name, value.toMap()),
      ),
      'cycleCount': cycleCount,
      'isActive': isActive,
    };
  }

  // Create from map
  factory ProductionSession.fromMap(Map<String, dynamic> map) {
    Map<TimerActionType, TimerActionState> actionStates = {};
    if (map['actionStates'] != null) {
      for (var entry in (map['actionStates'] as Map<String, dynamic>).entries) {
        final type = TimerActionType.values.firstWhere(
          (e) => e.name == entry.key,
          orElse: () => TimerActionType.setup,
        );
        actionStates[type] = TimerActionState.fromMap(entry.value);
      }
    } else {
      actionStates = _createDefaultActionStates();
    }

    return ProductionSession(
      id: map['id'] ?? '',
      itemId: map['itemId'],
      itemName: map['itemName'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      actionStates: actionStates,
      cycleCount: map['cycleCount'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }
}
