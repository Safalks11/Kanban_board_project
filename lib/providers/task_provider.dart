import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createTask({
    required String title,
    required String description,
    required String assignedTo,
  }) async {
    final currentUserId = ref.read(firebaseServiceProvider).currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final task = TaskModel.create(
      title: title,
      description: description,
      assignedTo: assignedTo,
      updatedBy: currentUserId,
    );

    await ref.read(offlineStorageServiceProvider).saveTask(task);

    final connectivityService = ref.read(connectivityServiceProvider);
    final isConnected = connectivityService.isConnected;

    if (!isConnected) {
      await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: 'create');
    } else {
      try {
        await ref.read(firebaseServiceProvider).createTask(task);
        final syncedTask = task.copyWith(isSynced: true);
        await ref.read(offlineStorageServiceProvider).saveTask(syncedTask);
      } catch (e) {
        debugPrint('Firebase create task failed: $e');
        await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: 'create');
      }
    }

    await _loadTasks();
  }

  Future<void> updateTask(TaskModel task) async {
    final currentUserId = ref.read(firebaseServiceProvider).currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: currentUserId,
      isSynced: false,
    );

    await ref.read(offlineStorageServiceProvider).saveTask(updatedTask);

    final connectivityService = ref.read(connectivityServiceProvider);
    final isConnected = connectivityService.isConnected;

    if (!isConnected) {
      await ref.read(offlineStorageServiceProvider).addToSyncQueue(updatedTask, action: 'update');
    } else {
      try {
        await ref.read(firebaseServiceProvider).updateTask(updatedTask);
        final syncedTask = updatedTask.copyWith(isSynced: true);
        await ref.read(offlineStorageServiceProvider).saveTask(syncedTask);
      } catch (e) {
        debugPrint('Firebase update task failed: $e');
        await ref.read(offlineStorageServiceProvider).addToSyncQueue(updatedTask, action: 'update');
      }
    }

    await _loadTasks();
  }

  Future<void> deleteTask(String taskId) async {
    await ref.read(offlineStorageServiceProvider).deleteTask(taskId);

    final connectivityService = ref.read(connectivityServiceProvider);
    final isConnected = connectivityService.isConnected;

    if (!isConnected) {
      final task = TaskModel(
        id: taskId,
        title: '',
        description: '',
        status: TaskStatus.todo,
        assignedTo: '',
        updatedAt: DateTime.now(),
        updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
        createdAt: DateTime.now(),
      );
      await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: 'delete');
    } else {
      try {
        await ref.read(firebaseServiceProvider).deleteTask(taskId);
      } catch (e) {
        debugPrint('Firebase delete task failed: $e');
        final task = TaskModel(
          id: taskId,
          title: '',
          description: '',
          status: TaskStatus.todo,
          assignedTo: '',
          updatedAt: DateTime.now(),
          updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
          createdAt: DateTime.now(),
        );
        await ref.read(offlineStorageServiceProvider).addToSyncQueue(task, action: 'delete');
      }
    }

    await _loadTasks();
  }

  Future<void> moveTask(String taskId, TaskStatus newStatus) async {
    final tasks = state.value ?? [];
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final updatedTask = task.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
        isSynced: false,
      );

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
      final updatedTask = task.copyWith(
        attachments: updatedAttachments,
        updatedAt: DateTime.now(),
        updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
        isSynced: false,
      );

      await updateTask(updatedTask);

      final connectivityService = ref.read(connectivityServiceProvider);
      if (connectivityService.isConnected) {
        try {
          final isStorageAvailable = await ref.read(firebaseServiceProvider).isStorageAvailable();
          if (isStorageAvailable) {
            final downloadUrl = await ref
                .read(firebaseServiceProvider)
                .uploadFile(
                  file,
                  taskId,
                  onProgress: (progress) {
                    debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
                  },
                );

            final finalTask = tasks[taskIndex];
            final finalAttachments = finalTask.attachments.map((url) {
              if (url == attachment.id) return downloadUrl;
              return url;
            }).toList();

            final finalUpdatedTask = finalTask.copyWith(
              attachments: finalAttachments,
              isSynced: false,
            );

            await updateTask(finalUpdatedTask);

            await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
          } else {
            debugPrint(
              'Firebase Storage not available, file will be uploaded when storage is accessible',
            );
          }
        } catch (e) {
          debugPrint('Upload failed: $e');
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
      final updatedTask = task.copyWith(
        attachments: updatedAttachments,
        updatedAt: DateTime.now(),
        updatedBy: ref.read(firebaseServiceProvider).currentUserId ?? '',
        isSynced: false,
      );

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
          debugPrint('Sync failed for task ${task.id}: $e');
        }
      }

      await _processPendingUploads();

      await ref.read(offlineStorageServiceProvider).setLastSync(DateTime.now());

      await _loadTasks();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> _processPendingUploads() async {
    final pendingUploads = await ref.read(offlineStorageServiceProvider).getPendingUploads();

    for (final uploadData in pendingUploads) {
      final attachment = FileAttachment.fromJson(uploadData['attachment']);
      final taskId = uploadData['taskId'] as String;
      final retryCount = uploadData['retryCount'] as int? ?? 0;

      if (retryCount >= 3) {
        debugPrint('Max retry count reached for attachment ${attachment.id}');
        continue;
      }

      if (attachment.localPath != null) {
        try {
          final file = File(attachment.localPath!);
          if (await file.exists()) {
            final downloadUrl = await ref.read(firebaseServiceProvider).uploadFile(file, taskId);

            final tasks = state.value ?? [];
            final taskIndex = tasks.indexWhere((task) => task.id == taskId);

            if (taskIndex != -1) {
              final task = tasks[taskIndex];
              final updatedAttachments = task.attachments.map((url) {
                if (url == attachment.id) return downloadUrl;
                return url;
              }).toList();

              final updatedTask = task.copyWith(attachments: updatedAttachments, isSynced: false);

              await updateTask(updatedTask);
            }

            await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
          } else {
            await ref.read(offlineStorageServiceProvider).removePendingUpload(attachment.id);
          }
        } catch (e) {
          debugPrint('Upload failed for attachment ${attachment.id}: $e');
          await ref
              .read(offlineStorageServiceProvider)
              .updatePendingUploadRetryCount(attachment.id, retryCount + 1);
        }
      }
    }
  }

  Future<void> _syncWithFirebase() async {
    try {
      final firebaseTasks = await ref.read(firebaseServiceProvider).getTasks();
      final offlineTasks = await ref.read(offlineStorageServiceProvider).loadTasks();

      final mergedTasks = <TaskModel>[];
      final processedIds = <String>{};

      for (final firebaseTask in firebaseTasks) {
        final offlineTask = offlineTasks.firstWhere(
          (task) => task.id == firebaseTask.id,
          orElse: () => firebaseTask,
        );

        if (offlineTask.id != firebaseTask.id) {
          mergedTasks.add(firebaseTask);
        } else {
          if (offlineTask.updatedAt != firebaseTask.updatedAt) {
            final resolvedTask = await ref
                .read(firebaseServiceProvider)
                .resolveConflict(offlineTask, firebaseTask);
            mergedTasks.add(resolvedTask);

            await ref.read(offlineStorageServiceProvider).saveConflict(offlineTask, firebaseTask);
          } else {
            mergedTasks.add(firebaseTask);
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

final syncStatusProvider = FutureProvider<Map<String, int>>((ref) async {
  final taskNotifier = ref.read(taskNotifierProvider.notifier);
  final unsyncedCount = await taskNotifier.getUnsyncedTasksCount();
  final pendingUploadsCount = await taskNotifier.getPendingUploadsCount();
  final conflictsCount = await taskNotifier.getConflictsCount();

  return {
    'unsynced': unsyncedCount,
    'pendingUploads': pendingUploadsCount,
    'conflicts': conflictsCount,
  };
});
