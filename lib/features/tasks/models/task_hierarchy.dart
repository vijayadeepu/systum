import '../../../core/database/database.dart';

/// A read-only, one-level view over the flat task collection.
///
/// The provider keeps a single flat list of tasks so it cannot diverge from
/// the database. This projection is rebuilt from that list whenever the list
/// changes and is only used for rendering.
class TaskHierarchy {
  factory TaskHierarchy.fromRows(Iterable<TaskRow> rows) {
    final allRows = List<TaskRow>.unmodifiable(rows);

    final roots = <TaskRow>[];
    final childrenByParentId = <String, List<TaskRow>>{};

    // Only top-level tasks are valid parents. Rows with a missing or
    // self-referencing parent are surfaced as roots rather than hidden.
    for (final row in allRows) {
      final parentId = row.parentTaskId;
      if (parentId == null || parentId == row.id) {
        roots.add(row);
      }
    }

    final rootIds = {for (final root in roots) root.id};
    final assignedChildIds = <String>{};

    for (final row in allRows) {
      final parentId = row.parentTaskId;
      if (parentId == null ||
          parentId == row.id ||
          !rootIds.contains(parentId)) {
        continue;
      }

      childrenByParentId.putIfAbsent(parentId, () => []).add(row);
      assignedChildIds.add(row.id);
    }

    // Corrupt or unexpectedly nested rows are promoted so no task can become
    // unreachable in the UI. The repository still prevents such data.
    for (final row in allRows) {
      if (row.parentTaskId == null || assignedChildIds.contains(row.id)) {
        continue;
      }
      if (!rootIds.contains(row.id)) {
        roots.add(row);
      }
    }

    return TaskHierarchy._(List<TaskRow>.unmodifiable(roots), {
      for (final entry in childrenByParentId.entries)
        entry.key: List<TaskRow>.unmodifiable(entry.value),
    });
  }

  const TaskHierarchy._(this.roots, this._childrenByParentId);

  final List<TaskRow> roots;
  final Map<String, List<TaskRow>> _childrenByParentId;

  List<TaskRow> childrenOf(String parentId) {
    return _childrenByParentId[parentId] ?? const [];
  }

  int childCountOf(String parentId) => childrenOf(parentId).length;

  bool hasChildren(String parentId) =>
      _childrenByParentId.containsKey(parentId);
}
