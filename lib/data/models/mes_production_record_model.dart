import 'package:cloud_firestore/cloud_firestore.dart';
import '../../mes_tablet/models/production_timer.dart';

enum ProductionStatus {
  inProgress, // Currently being worked on
  onHold, // Paused/suspended - can be resumed later
  completed // Finished and closed
}

class MESProductionRecord {
  final String id;
  final String itemId;
  final String userId;
  final String userName;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalProductionTimeSeconds;
  final int totalInterruptionTimeSeconds;
  final bool isCompleted;
  final ProductionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MESInterruption> interruptions;
  final List<ItemCompletionRecord> itemCompletionRecords;

  MESProductionRecord({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.userName,
    required this.startTime,
    this.endTime,
    required this.totalProductionTimeSeconds,
    required this.totalInterruptionTimeSeconds,
    this.isCompleted = false,
    this.status = ProductionStatus.inProgress,
    required this.createdAt,
    required this.updatedAt,
    required this.interruptions,
    required this.itemCompletionRecords,
  });

  // Create from Firestore document
  factory MESProductionRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<MESInterruption> interruptions = [];
    if (data['interruptions'] != null) {
      for (var item in data['interruptions']) {
        interruptions.add(MESInterruption.fromMap(item));
      }
    }

    List<ItemCompletionRecord> itemCompletionRecords = [];
    if (data['itemCompletionRecords'] != null) {
      for (var item in data['itemCompletionRecords']) {
        // For backwards compatibility, create empty action list if not available
        itemCompletionRecords.add(ItemCompletionRecord.fromMap(item, []));
      }
    }

    return MESProductionRecord(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      totalProductionTimeSeconds: data['totalProductionTimeSeconds'] ?? 0,
      totalInterruptionTimeSeconds: data['totalInterruptionTimeSeconds'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      status: parseProductionStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      interruptions: interruptions,
      itemCompletionRecords: itemCompletionRecords,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'userId': userId,
      'userName': userName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'totalProductionTimeSeconds': totalProductionTimeSeconds,
      'totalInterruptionTimeSeconds': totalInterruptionTimeSeconds,
      'isCompleted': isCompleted,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'interruptions': interruptions.map((i) => i.toMap()).toList(),
      'itemCompletionRecords':
          itemCompletionRecords.map((i) => i.toMap()).toList(),
    };
  }

  // Create a copy with updated values
  MESProductionRecord copyWith({
    DateTime? endTime,
    int? totalProductionTimeSeconds,
    int? totalInterruptionTimeSeconds,
    bool? isCompleted,
    ProductionStatus? status,
    List<MESInterruption>? interruptions,
    List<ItemCompletionRecord>? itemCompletionRecords,
  }) {
    return MESProductionRecord(
      id: id,
      itemId: itemId,
      userId: userId,
      userName: userName,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      totalProductionTimeSeconds:
          totalProductionTimeSeconds ?? this.totalProductionTimeSeconds,
      totalInterruptionTimeSeconds:
          totalInterruptionTimeSeconds ?? this.totalInterruptionTimeSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      interruptions: interruptions ?? this.interruptions,
      itemCompletionRecords:
          itemCompletionRecords ?? this.itemCompletionRecords,
    );
  }

  // Helper method to parse status from Firestore data
  static ProductionStatus parseProductionStatus(dynamic statusData) {
    if (statusData == null) return ProductionStatus.inProgress;

    switch (statusData.toString().toLowerCase()) {
      case 'onhold':
      case 'on_hold':
        return ProductionStatus.onHold;
      case 'completed':
        return ProductionStatus.completed;
      case 'inprogress':
      case 'in_progress':
      default:
        return ProductionStatus.inProgress;
    }
  }
}

class MESInterruption {
  final String typeId;
  final String typeName;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String? notes;

  MESInterruption({
    required this.typeId,
    required this.typeName,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    this.notes,
  });

  // Create from Map
  factory MESInterruption.fromMap(Map<String, dynamic> map) {
    return MESInterruption(
      typeId: map['typeId'] ?? '',
      typeName: map['typeName'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      durationSeconds: map['durationSeconds'] ?? 0,
      notes: map['notes'],
    );
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'typeId': typeId,
      'typeName': typeName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationSeconds': durationSeconds,
      'notes': notes,
    };
  }

  // Create a copy with updated values
  MESInterruption copyWith({
    DateTime? endTime,
    int? durationSeconds,
    String? notes,
  }) {
    return MESInterruption(
      typeId: typeId,
      typeName: typeName,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
    );
  }
}
