import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board_project/view/widgets/kanban_board.dart';
import 'package:kanban_board_project/view/widgets/task_detail_dialog.dart';
import '../providers/task_provider.dart';

class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<AsyncValue<bool>>(connectionStatusProvider, (previous, next) {
        next.whenData((isConnected) {
          if (isConnected && previous?.value == false) {
            ref.read(taskNotifierProvider.notifier).syncTasks();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Back online! Syncing tasks...'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivityService = ref.watch(connectivityServiceProvider);
    final isConnected = connectivityService.isConnected;
    ref.watch(connectionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isConnected ? Icons.wifi : Icons.wifi_off, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuSelection(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Sync Now'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'conflicts',
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.black),
                    SizedBox(width: 8),
                    Text('View Conflicts'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Clear All Data'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final syncStatus = ref.watch(syncStatusProvider);
                  return syncStatus.when(
                    data: (status) {
                      if (status['unsynced']! > 0 ||
                          status['pendingUploads']! > 0 ||
                          status['conflicts']! > 0) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getSyncStatusMessage(status),
                                  style: const TextStyle(color: Colors.orange),
                                ),
                              ),
                              if (isConnected)
                                TextButton(
                                  onPressed: () async {
                                    await ref.read(taskNotifierProvider.notifier).syncTasks();
                                  },
                                  child: const Text('Sync Now'),
                                ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  );
                },
              ),
              Expanded(
                child: const Padding(padding: EdgeInsets.all(8), child: KanbanBoard()),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTaskDialog(context),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  String _getSyncStatusMessage(Map<String, dynamic> status) {
    final messages = <String>[];

    if (status['unsynced']! > 0) {
      messages.add('${status['unsynced']} unsynced tasks');
    }
    if (status['pendingUploads']! > 0) {
      messages.add('${status['pendingUploads']} pending uploads');
    }
    if (status['conflicts']! > 0) {
      messages.add('${status['conflicts']} conflicts detected');
    }

    return messages.join(', ');
  }

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const TaskDetailDialog());
  }

  void _handleMenuSelection(String value) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (value) {
      case 'sync':
        try {
          await ref.read(taskNotifierProvider.notifier).syncTasks();
          messenger.showSnackBar(const SnackBar(content: Text('Sync completed')));
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
          );
        }
        break;
      case 'conflicts':
        _showConflictsDialog();
        break;
      case 'clear':
        _showClearDataDialog();
        break;
    }
  }

  void _showConflictsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflicts'),
        content: Consumer(
          builder: (context, ref, child) {
            final conflicts = ref.watch(syncStatusProvider);
            return conflicts.when(
              data: (status) {
                final conflictCount = status['conflicts']!;
                return Text(
                  'You have $conflictCount unresolved conflicts. These will be automatically resolved when you sync.',
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => const Text('Error loading conflicts'),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will clear all local data including tasks, attachments, and sync queue. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                await ref.read(offlineStorageServiceProvider).clearAllData();
                ref.invalidate(taskNotifierProvider);
                messenger.showSnackBar(const SnackBar(content: Text('All data cleared')));
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error clearing data: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
