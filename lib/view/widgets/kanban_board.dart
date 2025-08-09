import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/task_model.dart';
import '../../providers/task_provider.dart';
import 'task_column.dart';

class KanbanBoard extends ConsumerWidget {
  const KanbanBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskNotifierProvider);

    return tasksAsync.when(
      data: (tasks) {
        final todoTasks = tasks.where((task) => task.status == TaskStatus.todo).toList();
        final inProgressTasks = tasks
            .where((task) => task.status == TaskStatus.inProgress)
            .toList();
        final doneTasks = tasks.where((task) => task.status == TaskStatus.done).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5,
          children: [
            Expanded(
              child: TaskColumn(
                title: 'To Do',
                emoji: '📋',
                tasks: todoTasks,
                status: TaskStatus.todo,
                onTaskMoved: (taskId, newStatus) {
                  ref.read(taskNotifierProvider.notifier).moveTask(taskId, newStatus);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TaskColumn(
                title: 'In Progress',
                emoji: '🔄',
                tasks: inProgressTasks,
                status: TaskStatus.inProgress,
                onTaskMoved: (taskId, newStatus) {
                  ref.read(taskNotifierProvider.notifier).moveTask(taskId, newStatus);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TaskColumn(
                title: 'Done',
                emoji: '✅',
                tasks: doneTasks,
                status: TaskStatus.done,
                onTaskMoved: (taskId, newStatus) {
                  ref.read(taskNotifierProvider.notifier).moveTask(taskId, newStatus);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading tasks: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(taskNotifierProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
