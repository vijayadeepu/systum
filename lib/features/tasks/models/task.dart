import 'package:drift/drift.dart';

import '../../../core/database/database.dart';

const _unset = Object();

/// Editable task content used by create and edit flows.
///
/// Goal and parent relationships are intentionally managed by
/// `TaskRepository` rather than this model. [toCompanion] omits those columns,
/// so editing a task cannot accidentally clear its goal or parent.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.priority = 2,
    this.category,
  });

  factory Task.fromRow(TaskRow row) {
    return Task(
      id: row.id,
      title: row.title,
      description: row.description,
      completed: row.completed,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      dueDate: row.dueDate,
      priority: row.priority,
      category: row.category,
    );
  }

  final String id;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final int priority;
  final String? category;

  Task copyWith({
    String? id,
    String? title,
    Object? description = _unset,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? dueDate = _unset,
    int? priority,
    Object? category = _unset,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description == _unset
          ? this.description
          : description as String?,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
      priority: priority ?? this.priority,
      category: category == _unset ? this.category : category as String?,
    );
  }

  TasksCompanion toCompanion() {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      completed: Value(completed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      dueDate: Value(dueDate),
      priority: Value(priority),
      category: Value(category),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Task &&
            id == other.id &&
            title == other.title &&
            description == other.description &&
            completed == other.completed &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            dueDate == other.dueDate &&
            priority == other.priority &&
            category == other.category;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      completed,
      createdAt,
      updatedAt,
      dueDate,
      priority,
      category,
    );
  }
}
