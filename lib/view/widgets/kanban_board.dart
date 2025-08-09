import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board_project/view/widgets/task_column.dart';

import '../../model/task_model.dart';

class KanbanBoard extends ConsumerWidget {
  const KanbanBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Expanded(
          child: TaskColumn(
            title: 'To Do',
            emoji: '📋',
            tasks: [],
            status: TaskStatus.todo,
            onTaskMoved: (taskId, newStatus) {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TaskColumn(
            title: 'In Progress',
            emoji: '🔄',
            tasks: [],
            status: TaskStatus.inProgress,
            onTaskMoved: (taskId, newStatus) {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TaskColumn(
            title: 'Done',
            emoji: '✅',
            tasks: [],
            status: TaskStatus.done,
            onTaskMoved: (taskId, newStatus) {},
          ),
        ),
      ],
    );
  }
}
