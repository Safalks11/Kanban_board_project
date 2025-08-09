import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:kanban_board_project/model/task_model.dart';
import '../../providers/task_provider.dart';
import 'task_detail_dialog.dart';

class TaskCard extends ConsumerWidget {
  final TaskModel task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _editTask(context, ref),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => _deleteTask(ref),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: task.hasConflict ? Colors.red : Colors.grey[300]!,
            width: task.hasConflict ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(25), // Adjusted alpha for softer shadow
              spreadRadius: 1,
              blurRadius: 2, // Reduced blur
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTaskDetail(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ), // Reduced font size
                          maxLines: 1, // Changed to 1 line for compactness
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.hasConflict)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6), // Adjusted radius
                          ),
                          child: const Text(
                            'Conflict',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (!task.isSynced)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6), // Adjusted radius
                          ),
                          child: const Text(
                            'Offline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  // Description
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]), // Reduced font size
                      maxLines: 2, // Kept at 2 lines
                      overflow: TextOverflow.ellipsis,
                    ),

                  if (task.description.isNotEmpty) const SizedBox(height: 4), // Reduced spacing
                  // Attachments
                  if (task.attachments.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 14,
                          color: Colors.grey,
                        ), // Reduced icon size
                        const SizedBox(width: 4),
                        Text(
                          '${task.attachments.length} attachment${task.attachments.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ), // Reduced font size
                        ),
                        const SizedBox(width: 6),
                        // Show attachment type icons
                        Row(children: _getAttachmentTypeIcons()),
                      ],
                    ),

                  if (task.attachments.isNotEmpty) const SizedBox(height: 4), // Reduced spacing
                  // Footer
                  Row(
                    children: [
                      // Assigned to
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey,
                            ), // Reduced icon size, changed icon
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task.assignedTo.isNotEmpty
                                    ? task.assignedTo
                                    : "Unassigned", // Handle empty assignedTo
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ), // Reduced font size
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Updated date
                      Text(
                        DateFormat('MMM dd').format(task.updatedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ), // Reduced font size
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _getAttachmentTypeIcons() {
    final types = <String>{};

    for (final attachment in task.attachments) {
      final lowercaseAttachment = attachment.toLowerCase();
      if (lowercaseAttachment.contains('.pdf')) {
        types.add('pdf');
      } else if (lowercaseAttachment.contains('.jpg') ||
          lowercaseAttachment.contains('.jpeg') ||
          lowercaseAttachment.contains('.png')) {
        types.add('image');
      } else if (lowercaseAttachment.contains('.doc') || lowercaseAttachment.contains('.docx')) {
        types.add('doc');
      } else if (attachment.isNotEmpty) {
        // Ensure non-empty before adding 'file'
        types.add('file');
      }
    }

    return types.take(3).map((type) {
      IconData iconData;
      Color color;

      switch (type) {
        case 'pdf':
          iconData = Icons.picture_as_pdf_outlined; // Changed icon
          color = Colors.red.shade700;
          break;
        case 'image':
          iconData = Icons.image_outlined; // Changed icon
          color = Colors.blue.shade700;
          break;
        case 'doc':
          iconData = Icons.description_outlined; // Changed icon
          color = Colors.green.shade700;
          break;
        default:
          iconData = Icons.attach_file;
          color = Colors.grey.shade700;
      }

      return Padding(
        padding: const EdgeInsets.only(right: 3), // Reduced padding
        child: Icon(iconData, size: 12, color: color), // Reduced icon size
      );
    }).toList();
  }

  void _editTask(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(task: task),
    );
  }

  void _deleteTask(WidgetRef ref) {
    ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
  }

  void _showTaskDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(task: task),
    );
  }
}
