import 'package:flutter/material.dart';
import 'package:kanban_board_project/model/task_model.dart';
import 'task_card.dart';

class TaskColumn extends StatelessWidget {
  final String title;
  final String emoji;
  final List<TaskModel> tasks;
  final TaskStatus status;
  final Function(String, TaskStatus) onTaskMoved;

  const TaskColumn({
    super.key,
    required this.title,
    required this.emoji,
    required this.tasks,
    required this.status,
    required this.onTaskMoved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Tasks
          Expanded(
            child: DragTarget<TaskModel>(
              onAcceptWithDetails: (details) {
                final task = details.data;
                if (task.status != status) {
                  onTaskMoved(task.id, status);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? _getStatusColor(status).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: tasks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No tasks', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          primary: false, // Added this line
                          physics: const ClampingScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < tasks.length - 1 ? 8.0 : 0.0,
                              ),
                              child: Draggable<TaskModel>(
                                data: task,
                                feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 280,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue),
                                    ),
                                    child: Text(
                                      task.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                childWhenDragging: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Center(
                                    child: Text('Moving...', style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                                child: TaskCard(task: task),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.done:
        return Colors.green;
    }
  }
}
