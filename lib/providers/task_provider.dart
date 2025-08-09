import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controller/connectivity_service.dart';
import '../controller/firebase_service.dart';
import '../controller/offline_storage_service.dart';
import '../model/file_attachment_model.dart';
import '../model/task_model.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final offlineStorageServiceProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final connectionStatusProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectionStatus;
});

class TaskNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  final Ref ref;

  TaskNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final offlineTasks = await ref.read(offlineStorageServiceProvider).loadTasks();

      final connectivityService = ref.read(connectivityServiceProvider);
      final isConnected = connectivityService.isConnected;

      if (isConnected) {
        try {
          await _syncWithFirebase();
          final firebaseTasks = await ref.read(firebaseServiceProvider).getTasks();
          state = AsyncValue.data(firebaseTasks.isNotEmpty ? firebaseTasks : offlineTasks);
        } catch (e) {
          debugPrint('Firebase sync failed: $e');
          state = AsyncValue.data(offlineTasks);
        }
      } else {
        state = AsyncValue.data(offlineTasks);
      }
      ref.invalidate(syncStatusProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      ref.invalidate(syncStatusProvider);
    }
  }

  Future<void> _handleTaskOperation({
    required TaskModel task,
    required String action,
    required Future<void> Function() firebaseAction,
    String? originalTaskIdForDelete,
  }) async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isConnected = connectivityService.isConnected;

    if (action == 'delete') {
      await ref.read(offlineStorageServiceProvider).deleteTask(originalTaskIdForDelete ?? task.id);
    } else {
      await ref.read(offlineStorageServiceProvider).saveTask(task);
    }

    if (!isConnected) {
      await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: action);
    } else {
      try {
        await firebaseAction();
        if (action != 'delete') {
          final syncedTask = task.copyWith(isSynced: true);
          await ref.read(offlineStorageServiceProvider).saveTask(syncedTask);
        }
      } catch (e) {
        debugPrint('Firebase $action task failed: $e');
        await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: action);
      }
    }
    await _loadTasks();
  }

  Future<void> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required TaskStatus status,
  }) async {
    final currentUserId = ref.read(firebaseServiceProvider).currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final task = TaskModel.create(
      title: title,
      description: description,
      assignedTo: assignedTo,
      updatedBy: currentUserId,
    );

    await _handleTaskOperation(
      task: task,
      action: 'create',
      firebaseAction: () => ref.read(firebaseServiceProvider).createTask(task),
    );
  }

  Future<void> updateTask(TaskModel task) async {
    final currentUserId = ref.read(firebaseServiceProvider).currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: currentUserId,
      isSynced: false,
    );

    await _handleTaskOperation(
      task: updatedTask,
      action: 'update',
      firebaseAction: () => ref.read(firebaseServiceProvider).updateTask(updatedTask),
    );
  }

  Future<void> deleteTask(String taskId) async {
    final placeholderTaskForQueue = TaskModel(
      id: taskId,
      title: '',
      description: '',
      status: TaskStatus.todo,
      assignedTo: '',
      updatedAt: DateTime.now(),
      updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
      createdAt: DateTime.now(),
    );

    await _handleTaskOperation(
      task: placeholderTaskForQueue,
      action: 'delete',
      firebaseAction: () => ref.read(firebaseServiceProvider).deleteTask(taskId),
      originalTaskIdForDelete: taskId,
    );
  }

  Future<void> moveTask(String taskId, TaskStatus newStatus) async {
    final tasks = state.value ?? [];
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final updatedTask = task.copyWith(status: newStatus);
      await updateTask(updatedTask);
    }
  }

  Future<void> addAttachment(String taskId, File file) async {
    final tasks = state.value ?? [];
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final attachment = FileAttachment.fromFile(file);

      await ref.read(offlineStorageServiceProvider).addPendingUpload(attachment, taskId);

      final updatedAttachments = [...task.attachments, attachment.id];
      final updatedTask = task.copyWith(attachments: updatedAttachments);

      await updateTask(updatedTask);

      final connectivityService = ref.read(connectivityServiceProvider);
      if (connectivityService.isConnected) {
        try {
          final downloadUrl = await ref
              .read(firebaseServiceProvider)
              .uploadFile(
                file,
                taskId,
                onProgress: (progress) {
                  debugPrint('Upload progress: \${(progress * 100).toStringAsFixed(1)}%');
                },
              );

          final currentTasks = state.value ?? [];
          final currentTaskIndex = currentTasks.indexWhere((t) => t.id == taskId);
          if (currentTaskIndex != -1) {
            final taskAfterUpload = currentTasks[currentTaskIndex];
            final finalAttachments = taskAfterUpload.attachments.map((url) {
              if (url == attachment.id) return downloadUrl;
              return url;
            }).toList();

            final finalUpdatedTask = taskAfterUpload.copyWith(attachments: finalAttachments);
            await updateTask(finalUpdatedTask);
          }
          await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
        } catch (e) {
          debugPrint('Upload failed: $e. Handled by FirebaseService.');
        }
      }
    }
  }

  Future<void> removeAttachment(String taskId, String attachmentId) async {
    final tasks = state.value ?? [];
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final updatedAttachments = task.attachments.where((id) => id != attachmentId).toList();
      final updatedTask = task.copyWith(attachments: updatedAttachments);
      await updateTask(updatedTask);
    }
  }

  Future<void> syncTasks() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    if (!connectivityService.isConnected) return;

    try {
      final syncQueue = await ref.read(offlineStorageServiceProvider).getSyncQueue();

      for (final taskData in syncQueue) {
        final task = TaskModel.fromJson(taskData);
        final syncAction = taskData['syncAction'] as String?;

        try {
          if (syncAction == 'create') {
            await ref.read(firebaseServiceProvider).createTask(task);
          } else if (syncAction == 'update') {
            await ref.read(firebaseServiceProvider).updateTask(task);
          } else if (syncAction == 'delete') {
            await ref.read(firebaseServiceProvider).deleteTask(task.id);
          }

          await ref.read(offlineStorageServiceProvider).removeFromSyncQueue(task.id);
        } catch (e) {
          debugPrint('Sync failed for task \${task.id}: $e');
        }
      }

      await _processPendingUploads();
      await ref.read(offlineStorageServiceProvider).setLastSync(DateTime.now());
      await _loadTasks();
    } catch (e) {
      debugPrint('Sync process failed: $e');
      ref.invalidate(syncStatusProvider);
    }
  }

  Future<void> _processPendingUploads() async {
    final pendingUploads = await ref.read(offlineStorageServiceProvider).getPendingUploads();

    for (final uploadData in pendingUploads) {
      final attachment = FileAttachment.fromJson(uploadData['attachment']);
      final taskId = uploadData['taskId'] as String;
      final retryCount = uploadData['retryCount'] as int? ?? 0;

      if (retryCount >= 3) {
        debugPrint('Max retry count reached for attachment \${attachment.id}');
        continue;
      }

      if (attachment.localPath != null) {
        try {
          final file = File(attachment.localPath!);
          if (await file.exists()) {
            final downloadUrl = await ref.read(firebaseServiceProvider).uploadFile(file, taskId);

            final currentTasks = state.value ?? [];
            final taskIndex = currentTasks.indexWhere((task) => task.id == taskId);

            if (taskIndex != -1) {
              final task = currentTasks[taskIndex];
              final updatedAttachments = task.attachments.map((url) {
                if (url == attachment.id) return downloadUrl;
                return url;
              }).toList();
              final updatedTask = task.copyWith(attachments: updatedAttachments);
              await updateTask(updatedTask);
            }
            await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
          } else {
            await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
          }
        } catch (e) {
          debugPrint(
            'Upload failed for attachment \${attachment.id}: $e. Handled by FirebaseService.',
          );
          await ref
              .read(offlineStorageServiceProvider)
              .updatePendingUploadRetryCount(attachment.id, retryCount + 1);
        }
      }
    }
    ref.invalidate(syncStatusProvider);
  }

  Future<void> _syncWithFirebase() async {
    try {
      final firebaseTasks = await ref.read(firebaseServiceProvider).getTasks();
      final offlineTasksResult = await ref.read(offlineStorageServiceProvider).loadTasks();

      final mergedTasks = <TaskModel>[];
      final processedIds = <String>{};

      final List<TaskModel> offlineTasks = List.from(offlineTasksResult);

      for (final firebaseTask in firebaseTasks) {
        TaskModel? offlineMatch;
        try {
          offlineMatch = offlineTasks.firstWhere((task) => task.id == firebaseTask.id);
        } catch (e) {
          offlineMatch = null;
        }

        if (offlineMatch == null) {
          mergedTasks.add(firebaseTask);
        } else {
          if (offlineMatch.updatedAt.isAfter(firebaseTask.updatedAt)) {
            if (!offlineMatch.isSynced) {
              mergedTasks.add(offlineMatch);
            } else {
              debugPrint(
                "Conflict detected for task \${firebaseTask.id}. Offline newer but both marked synced. Taking Firebase version.",
              );
              mergedTasks.add(firebaseTask);
              await ref
                  .read(offlineStorageServiceProvider)
                  .saveConflict(offlineMatch, firebaseTask);
            }
          } else if (firebaseTask.updatedAt.isAfter(offlineMatch.updatedAt)) {
            mergedTasks.add(firebaseTask);
          } else {
            mergedTasks.add(firebaseTask.isSynced ? firebaseTask : offlineMatch);
          }
        }
        processedIds.add(firebaseTask.id);
      }

      for (final offlineTask in offlineTasks) {
        if (!processedIds.contains(offlineTask.id)) {
          mergedTasks.add(offlineTask);
        }
      }
      await ref.read(offlineStorageServiceProvider).saveTasks(mergedTasks);
    } catch (e) {
      debugPrint('Sync with Firebase failed: $e');
    }
  }

  Future<int> getUnsyncedTasksCount() async {
    return await ref.read(offlineStorageServiceProvider).getUnsyncedTasksCount();
  }

  Future<int> getPendingUploadsCount() async {
    return await ref.read(offlineStorageServiceProvider).getPendingUploadsCount();
  }

  Future<int> getConflictsCount() async {
    return await ref.read(offlineStorageServiceProvider).getConflictsCount();
  }
}

final taskNotifierProvider = StateNotifierProvider<TaskNotifier, AsyncValue<List<TaskModel>>>((
  ref,
) {
  return TaskNotifier(ref);
});

final tasksByStatusProvider = Provider.family<List<TaskModel>, TaskStatus>((ref, status) {
  final tasksAsync = ref.watch(taskNotifierProvider);
  return tasksAsync.when(
    data: (tasks) => tasks.where((task) => task.status == status).toList(),
    loading: () => <TaskModel>[],
    error: (error, stack) => <TaskModel>[],
  );
});

final syncStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  debugPrint('[SyncStatusProvider] Re-evaluating...'); // Log start

  final asyncConnectionStatus = ref.watch(connectionStatusProvider);
  final isConnected = asyncConnectionStatus.when(
    data: (status) {
      debugPrint('[SyncStatusProvider] Connection status from data: $status');
      return status;
    },
    loading: () {
      debugPrint('[SyncStatusProvider] Connection status is loading, assuming false.');
      return false;
    },
    error: (err, stack) {
      debugPrint('[SyncStatusProvider] Connection status error ($err), assuming false.');
      return false;
    },
  );

  debugPrint('[SyncStatusProvider] Determined isConnected: $isConnected');

  final taskNotifier = ref.read(taskNotifierProvider.notifier);
  final unsyncedCount = await taskNotifier.getUnsyncedTasksCount();
  final pendingUploadsCount = await taskNotifier.getPendingUploadsCount();
  final conflictsCount = await taskNotifier.getConflictsCount();

  final result = {
    'isConnected': isConnected,
    'unsynced': unsyncedCount,
    'pendingUploads': pendingUploadsCount,
    'conflicts': conflictsCount,
  };
  debugPrint('[SyncStatusProvider] Evaluation complete. Result: $result'); // Log end
  return result;
});
