import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task_hierarchy.dart';

void main() {
  group('TaskHierarchy', () {
    test('an empty collection produces no roots or children', () {
      final hierarchy = TaskHierarchy.fromRows(const []);

      expect(hierarchy.roots, isEmpty);
      expect(hierarchy.childrenOf('missing'), isEmpty);
      expect(hierarchy.hasChildren('missing'), isFalse);
    });

    test('top-level tasks remain roots without children', () {
      final first = _taskRow(id: 'first');
      final second = _taskRow(id: 'second');

      final hierarchy = TaskHierarchy.fromRows([first, second]);

      expect(hierarchy.roots.map((task) => task.id), ['first', 'second']);
      expect(hierarchy.childrenOf('first'), isEmpty);
      expect(hierarchy.hasChildren('first'), isFalse);
    });

    test('children are grouped under their parent in input order', () {
      final parent = _taskRow(id: 'parent');
      final firstChild = _taskRow(id: 'child-1', parentTaskId: parent.id);
      final secondChild = _taskRow(id: 'child-2', parentTaskId: parent.id);
      final otherRoot = _taskRow(id: 'other-root');

      final hierarchy = TaskHierarchy.fromRows([
        parent,
        firstChild,
        otherRoot,
        secondChild,
      ]);

      expect(hierarchy.roots.map((task) => task.id), ['parent', 'other-root']);
      expect(hierarchy.childrenOf(parent.id).map((task) => task.id), [
        'child-1',
        'child-2',
      ]);
      expect(hierarchy.childCountOf(parent.id), 2);
      expect(hierarchy.hasChildren(parent.id), isTrue);
    });

    test('a child with a missing parent is surfaced as a root', () {
      final orphan = _taskRow(id: 'orphan', parentTaskId: 'missing-parent');

      final hierarchy = TaskHierarchy.fromRows([orphan]);

      expect(hierarchy.roots.single.id, 'orphan');
      expect(hierarchy.childrenOf('missing-parent'), isEmpty);
    });

    test('a corrupt nested task is promoted instead of hidden', () {
      final root = _taskRow(id: 'root');
      final child = _taskRow(id: 'child', parentTaskId: root.id);
      final grandchild = _taskRow(id: 'grandchild', parentTaskId: child.id);

      final hierarchy = TaskHierarchy.fromRows([root, child, grandchild]);

      expect(hierarchy.roots.map((task) => task.id), ['root', 'grandchild']);
      expect(hierarchy.childrenOf(root.id).single.id, 'child');
    });

    test('a self-referencing task is a root and not its own child', () {
      final task = _taskRow(id: 'self', parentTaskId: 'self');

      final hierarchy = TaskHierarchy.fromRows([task]);

      expect(hierarchy.roots.single.id, 'self');
      expect(hierarchy.childrenOf('self'), isEmpty);
    });

    test('a cycle does not make tasks unreachable', () {
      final first = _taskRow(id: 'first', parentTaskId: 'second');
      final second = _taskRow(id: 'second', parentTaskId: 'first');

      final hierarchy = TaskHierarchy.fromRows([first, second]);

      expect(hierarchy.roots.map((task) => task.id), ['first', 'second']);
    });
  });
}

TaskRow _taskRow({required String id, String? parentTaskId, String? goalId}) {
  final now = DateTime(2026, 8, 1, 8);
  return TaskRow(
    id: id,
    title: 'Task $id',
    completed: false,
    createdAt: now,
    updatedAt: now,
    priority: 2,
    goalId: goalId,
    parentTaskId: parentTaskId,
  );
}
