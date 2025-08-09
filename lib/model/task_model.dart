import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { todo, inProgress, done }

extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  String get emoji {
    switch (this) {
      case TaskStatus.todo:
        return '📋';
      case TaskStatus.inProgress:
        return '🔄';
      case TaskStatus.done:
        return '✅';
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final String assignedTo;
  final DateTime updatedAt;
  final String updatedBy;
  final List<String> attachments;
  final bool isSynced;
  final bool hasConflict;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.updatedAt,
    required this.updatedBy,
    this.attachments = const [],
    this.isSynced = true,
    this.hasConflict = false,
    required this.createdAt,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    String? assignedTo,
    DateTime? updatedAt,
    String? updatedBy,
    List<String>? attachments,
    bool? isSynced,
    bool? hasConflict,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      attachments: attachments ?? this.attachments,
      isSynced: isSynced ?? this.isSynced,
      hasConflict: hasConflict ?? this.hasConflict,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'assignedTo': assignedTo,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
      'attachments': attachments,
      'isSynced': isSynced,
      'hasConflict': hasConflict,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime updatedAt;
    if (json['updatedAt'] is Timestamp) {
      updatedAt = (json['updatedAt'] as Timestamp).toDate();
    } else {
      updatedAt = DateTime.now();
    }

    DateTime createdAt;
    if (json['createdAt'] is Timestamp) {
      createdAt = (json['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.todo,
      ),
      assignedTo: json['assignedTo'] as String,
      updatedAt: updatedAt,
      updatedBy: json['updatedBy'] as String,
      attachments: List<String>.from(json['attachments'] ?? []),
      isSynced: json['isSynced'] as bool? ?? true,
      hasConflict: json['hasConflict'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  factory TaskModel.create({
    required String title,
    required String description,
    required String assignedTo,
    required String updatedBy,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      status: TaskStatus.todo,
      assignedTo: assignedTo,
      updatedAt: now,
      updatedBy: updatedBy,
      attachments: [],
      isSynced: false,
      createdAt: now,
    );
  }
}
