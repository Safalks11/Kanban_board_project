import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:kanban_board_project/model/task_model.dart';

class FirebaseService {
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  final FirebaseAuth? _auth;
  FirebaseService() : _firestore = _getFirestore(), _storage = _getStorage(), _auth = _getAuth();

  static FirebaseFirestore? _getFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      print('Firestore not available: $e');
      return null;
    }
  }

  static FirebaseStorage? _getStorage() {
    try {
      return FirebaseStorage.instance;
    } catch (e) {
      print('Firebase Storage not available: $e');
      return null;
    }
  }

  static FirebaseAuth? _getAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      print('Firebase Auth not available: $e');
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _tasksCollection =>
      _firestore?.collection('tasks');

  String? get currentUserId => _auth?.currentUser?.uid ?? 'default-user';

  Future<void> createTask(TaskModel task) async {
    if (_tasksCollection == null) {
      throw Exception('Firebase not configured');
    }
    if (currentUserId == null) throw Exception('User not authenticated');

    final taskData = task.toJson();
    taskData.remove('id');
    await _tasksCollection!.doc(task.id).set(taskData);
  }

  Future<void> updateTask(TaskModel task) async {
    if (_tasksCollection == null) {
      throw Exception('Firebase not configured');
    }
    if (currentUserId == null) throw Exception('User not authenticated');

    final taskData = task.toJson();
    taskData.remove('id');
    await _tasksCollection!.doc(task.id).update(taskData);
  }

  Future<void> deleteTask(String taskId) async {
    if (_tasksCollection == null) {
      throw Exception('Firebase not configured');
    }
    if (currentUserId == null) throw Exception('User not authenticated');

    await _deleteTaskFiles(taskId);

    await _tasksCollection!.doc(taskId).delete();
  }

  Future<List<TaskModel>> getTasks() async {
    if (_tasksCollection == null) {
      return [];
    }
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _tasksCollection!
          .where('assignedTo', isEqualTo: currentUserId)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TaskModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting tasks from Firebase: $e');
      return [];
    }
  }

  Future<TaskModel> resolveConflict(TaskModel localTask, TaskModel remoteTask) async {
    if (localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
      return localTask.copyWith(hasConflict: false, isSynced: true);
    } else {
      return _mergeTasks(localTask, remoteTask);
    }
  }

  TaskModel _mergeTasks(TaskModel localTask, TaskModel remoteTask) {
    final bool localIsNewer = localTask.updatedAt.isAfter(remoteTask.updatedAt);
    final mergedTask = localTask.copyWith(
      title: localIsNewer ? localTask.title : remoteTask.title,
      description: localIsNewer ? localTask.description : remoteTask.description,
      status: localIsNewer ? localTask.status : remoteTask.status,
      assignedTo: localIsNewer ? localTask.assignedTo : remoteTask.assignedTo,
      attachments: {...localTask.attachments, ...remoteTask.attachments}.toSet().toList(),
      updatedAt: DateTime.now(),
      updatedBy: currentUserId!,
      hasConflict: false,
      isSynced: true,
    );

    return mergedTask;
  }

  Future<String> uploadFile(File file, String taskId, {Function(double)? onProgress}) async {
    if (_storage == null) {
      throw Exception('Firebase Storage not configured');
    }
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storageRef = _storage.ref().child('tasks/$taskId/$fileName');

      debugPrint('Uploading file to: tasks/$taskId/$fileName');

      final uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;

      debugPrint('Upload completed, getting download URL...');

      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Download URL obtained: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage upload failed: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw Exception(
            'Permission denied. Please check Firebase Storage rules. Users must be authenticated to upload files.',
          );
        case 'object-not-found':
        case 'bucket-not-found':
          throw Exception(
            'Storage bucket/object not found or network error. Please verify:\n1. Firebase Storage is enabled in your project\n2. Storage bucket is properly configured\n3. Internet connection is available',
          );
        default:
          throw Exception('Firebase Storage upload failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e');
      rethrow;
    }
  }

  Future<void> _deleteTaskFiles(String taskId) async {
    if (_storage == null) return;

    try {
      final taskFilesRef = _storage!.ref().child('tasks/$taskId');
      final result = await taskFilesRef.listAll();

      for (final item in result.items) {
        await item.delete();
      }
    } catch (e) {
      print('Error deleting task files: $e');
    }
  }
}
