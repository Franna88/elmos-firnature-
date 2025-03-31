class SOP {
  final String id;
  final String title;
  final String description;
  final String department;
  final int revisionNumber;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SOPStep> steps;
  final List<String> tools;
  final List<String> safetyRequirements;
  final List<String> cautions;

  SOP({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.revisionNumber,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.steps,
    required this.tools,
    required this.safetyRequirements,
    required this.cautions,
  });

  SOP copyWith({
    String? id,
    String? title,
    String? description,
    String? department,
    int? revisionNumber,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SOPStep>? steps,
    List<String>? tools,
    List<String>? safetyRequirements,
    List<String>? cautions,
  }) {
    return SOP(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      department: department ?? this.department,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      steps: steps ?? this.steps,
      tools: tools ?? this.tools,
      safetyRequirements: safetyRequirements ?? this.safetyRequirements,
      cautions: cautions ?? this.cautions,
    );
  }
}

class SOPStep {
  final String id;
  final String title;
  final String instruction;
  final String? imageUrl;
  final String? helpNote;
  final String? assignedTo;
  final int? estimatedTime; // in minutes
  final List<String> stepTools; // Tools needed specifically for this step
  final List<String> stepHazards; // Hazards specific to this step

  SOPStep({
    required this.id,
    required this.title,
    required this.instruction,
    this.imageUrl,
    this.helpNote,
    this.assignedTo,
    this.estimatedTime,
    this.stepTools = const [],
    this.stepHazards = const [],
  });

  SOPStep copyWith({
    String? id,
    String? title,
    String? instruction,
    String? imageUrl,
    String? helpNote,
    String? assignedTo,
    int? estimatedTime,
    List<String>? stepTools,
    List<String>? stepHazards,
  }) {
    return SOPStep(
      id: id ?? this.id,
      title: title ?? this.title,
      instruction: instruction ?? this.instruction,
      imageUrl: imageUrl ?? this.imageUrl,
      helpNote: helpNote ?? this.helpNote,
      assignedTo: assignedTo ?? this.assignedTo,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      stepTools: stepTools ?? this.stepTools,
      stepHazards: stepHazards ?? this.stepHazards,
    );
  }
}

class SOPTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? thumbnailUrl;

  SOPTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.thumbnailUrl,
  });

  SOPTemplate copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? thumbnailUrl,
  }) {
    return SOPTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
