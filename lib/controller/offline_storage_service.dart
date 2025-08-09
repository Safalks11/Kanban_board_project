import 'dart:convert';
import 'package:kanban_board_project/model/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/file_attachment_model.dart';

class OfflineStorageService {
  static const String _tasksKey = 'tasks';
  static const String _syncQueueKey = 'sync_queue';
  static const String _pendingUploadsKey = 'pending_uploads';
  static const String _lastSyncKey = 'last_sync';
  static const String _conflictsKey = 'conflicts';

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, jsonEncode(tasksJson));
  }

  Future<List<TaskModel>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksString = prefs.getString(_tasksKey);
    if (tasksString == null) return [];

    try {
      final tasksJson = jsonDecode(tasksString) as List;
      return tasksJson.map((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading tasks from offline storage: $e');
      return [];
    }
  }

  Future<void> saveTask(TaskModel task) async {
    final tasks = await loadTasks();
    final existingIndex = tasks.indexWhere((t) => t.id == task.id);

    if (existingIndex >= 0) {
      tasks[existingIndex] = task;
    } else {
      tasks.add(task);
    }

    await saveTasks(tasks);
  }

  Future<void> deleteTask(String taskId) async {
    final tasks = await loadTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await saveTasks(tasks);
  }

  Future<void> addToSyncQueue(TaskModel task, {String action = 'update'}) async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString(_syncQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(jsonDecode(queueString));

    final taskJson = task.toJson();
    taskJson['syncAction'] = action;
    taskJson['queuedAt'] = DateTime.now().toIso8601String();

    queue.removeWhere((item) => item['id'] == task.id);
    queue.add(taskJson);

    await prefs.setString(_syncQueueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString(_syncQueueKey) ?? '[]';
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(queueString));
    } catch (e) {
      print('Error loading sync queue: $e');
      return [];
    }
  }

  Future<void> removeFromSyncQueue(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString(_syncQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(jsonDecode(queueString));

    queue.removeWhere((item) => item['id'] == taskId);
    await prefs.setString(_syncQueueKey, jsonEncode(queue));
  }

  Future<void> clearSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncQueueKey);
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadsString = prefs.getString(_pendingUploadsKey) ?? '[]';
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(uploadsString));
    } catch (e) {
      print('Error loading pending uploads: $e');
      return [];
    }
  }

  Future<void> removePendingUpload(String attachmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final uploadsString = prefs.getString(_pendingUploadsKey) ?? '[]';
    final uploads = List<Map<String, dynamic>>.from(jsonDecode(uploadsString));

    uploads.removeWhere((upload) => upload['attachment']['id'] == attachmentId);
    await prefs.setString(_pendingUploadsKey, jsonEncode(uploads));
  }

  Future<void> updatePendingUploadRetryCount(String attachmentId, int retryCount) async {
    final prefs = await SharedPreferences.getInstance();
    final uploadsString = prefs.getString(_pendingUploadsKey) ?? '[]';
    final uploads = List<Map<String, dynamic>>.from(jsonDecode(uploadsString));

    final uploadIndex = uploads.indexWhere((upload) => upload['attachment']['id'] == attachmentId);
    if (uploadIndex >= 0) {
      uploads[uploadIndex]['retryCount'] = retryCount;
      await prefs.setString(_pendingUploadsKey, jsonEncode(uploads));
    }
  }

  Future<void> setLastSync(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
  }

  Future<void> saveConflict(TaskModel localTask, TaskModel remoteTask) async {
    final prefs = await SharedPreferences.getInstance();
    final conflictsString = prefs.getString(_conflictsKey) ?? '[]';
    final conflicts = List<Map<String, dynamic>>.from(jsonDecode(conflictsString));

    final conflictJson = {
      'localTask': localTask.toJson(),
      'remoteTask': remoteTask.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'resolved': false,
    };

    conflicts.removeWhere((conflict) => conflict['localTask']['id'] == localTask.id);
    conflicts.add(conflictJson);

    await prefs.setString(_conflictsKey, jsonEncode(conflicts));
  }

  Future<List<Map<String, dynamic>>> getConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    final conflictsString = prefs.getString(_conflictsKey) ?? '[]';
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(conflictsString));
    } catch (e) {
      print('Error loading conflicts: $e');
      return [];
    }
  }

  Future<void> addPendingUpload(FileAttachment attachment, String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final uploadsString = prefs.getString(_pendingUploadsKey) ?? '[]';
    final uploads = List<Map<String, dynamic>>.from(jsonDecode(uploadsString));

    final uploadJson = {
      'attachment': attachment.toJson(),
      'taskId': taskId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };

    uploads.removeWhere((upload) => upload['attachment']['id'] == attachment.id);
    uploads.add(uploadJson);

    await prefs.setString(_pendingUploadsKey, jsonEncode(uploads));
  }

  Future<void> markConflictResolved(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final conflictsString = prefs.getString(_conflictsKey) ?? '[]';
    final conflicts = List<Map<String, dynamic>>.from(jsonDecode(conflictsString));

    final conflictIndex = conflicts.indexWhere((conflict) => conflict['localTask']['id'] == taskId);
    if (conflictIndex >= 0) {
      conflicts[conflictIndex]['resolved'] = true;
      await prefs.setString(_conflictsKey, jsonEncode(conflicts));
    }
  }

  Future<int> getUnsyncedTasksCount() async {
    final tasks = await loadTasks();
    return tasks.where((task) => !task.isSynced).length;
  }

  Future<int> getPendingUploadsCount() async {
    final uploads = await getPendingUploads();
    return uploads.length;
  }

  Future<int> getConflictsCount() async {
    final conflicts = await getConflicts();
    return conflicts.where((conflict) => !conflict['resolved']).length;
  }
}
