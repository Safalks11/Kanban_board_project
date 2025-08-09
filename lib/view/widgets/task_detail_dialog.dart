import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kanban_board_project/model/task_model.dart';

import '../../providers/task_provider.dart';

class TaskDetailDialog extends ConsumerStatefulWidget {
  final TaskModel? task;

  const TaskDetailDialog({super.key, this.task});

  @override
  ConsumerState<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends ConsumerState<TaskDetailDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _assignedToController;
  late TaskStatus _selectedStatus;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _assignedToController = TextEditingController(text: widget.task?.assignedTo ?? '');
    _selectedStatus = widget.task?.status ?? TaskStatus.todo;
    _isEditing = widget.task != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assignedToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(_isEditing ? Icons.edit : Icons.add, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Task' : 'Create Task',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Title',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter task title',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter task description',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Assigned To
                    const Text(
                      'Assigned To',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _assignedToController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter assignee',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: (_isEditing ? TaskStatus.values : [TaskStatus.todo]).map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Text(status.emoji),
                              const SizedBox(width: 8),
                              Text(status.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Attachments
                    if (widget.task != null) ...[
                      Row(
                        children: [
                          const Text(
                            'Attachments',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Add Files'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.task!.attachments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: widget.task!.attachments.map((attachment) {
                              return _buildAttachmentItem(attachment);
                            }).toList(),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            const SizedBox(height: 24),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveTask,
                  child: Text(_isEditing ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(String attachment) {
    return ListTile(
      leading: _getAttachmentIcon(attachment),
      title: Text(
        attachment.contains('http') ? 'Uploaded file' : attachment,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: attachment.contains('http')
          ? const Text('File uploaded to cloud')
          : const Text('Local file'),
      trailing: IconButton(
        onPressed: () => _removeAttachment(attachment),
        icon: const Icon(Icons.delete),
        color: Colors.red,
      ),
    );
  }

  Widget _getAttachmentIcon(String attachment) {
    if (attachment.contains('http')) {
      // Remote file
      if (attachment.contains('.pdf')) {
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      } else if (attachment.contains('.jpg') ||
          attachment.contains('.jpeg') ||
          attachment.contains('.png')) {
        return const Icon(Icons.image, color: Colors.blue);
      } else {
        return const Icon(Icons.attach_file, color: Colors.grey);
      }
    } else {
      // Local file
      return const Icon(Icons.file_present, color: Colors.orange);
    }
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (_assignedToController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an assignee')));
      return;
    }

    if (_isEditing && widget.task != null) {
      // Update existing task
      final updatedTask = widget.task!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _assignedToController.text.trim(),
        status: _selectedStatus,
      );

      ref.read(taskNotifierProvider.notifier).updateTask(updatedTask);
    } else {
      // Create new task
      ref
          .read(taskNotifierProvider.notifier)
          .createTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            assignedTo: _assignedToController.text.trim(),
            status: _selectedStatus,
          );
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickFiles() async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('File uploads require a paid Firebase Storage plan.'),
        backgroundColor: Colors.orange,
      ),
    );

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final fileObj = File(file.path!);
            await ref.read(taskNotifierProvider.notifier).addAttachment(widget.task!.id, fileObj);
          }
        }

        // Refresh the dialog
        setState(() {});

        messenger.showSnackBar(
          SnackBar(
            content: Text('${result.files.length} file(s) added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error picking files: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeAttachment(String attachmentId) {
    if (widget.task != null) {
      ref.read(taskNotifierProvider.notifier).removeAttachment(widget.task!.id, attachmentId);
      setState(() {});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attachment removed')));
    }
  }
}
