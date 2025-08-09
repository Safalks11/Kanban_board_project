import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _isConnected = true; // Default to true, will be updated by _initConnectivity

  bool get isConnected => _isConnected;

  ConnectivityService() {
    debugPrint('[ConnectivityService] Initializing...');
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      debugPrint('[ConnectivityService] onConnectivityChanged received: $results');
      _updateConnectionStatus(results);
    });
  }

  Future<void> _initConnectivity() async {
    try {
      debugPrint('[ConnectivityService] _initConnectivity called.');
      final results = await _connectivity.checkConnectivity();
      debugPrint('[ConnectivityService] _initConnectivity results: $results');
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('[ConnectivityService] _initConnectivity error: $e. Defaulting to disconnected.');
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = results.any((result) => result != ConnectivityResult.none);
    debugPrint(
      '[ConnectivityService] _updateConnectionStatus: Connection determined as: $_isConnected (was: $wasConnected). Results: $results',
    );

    if (wasConnected != _isConnected) {
      _connectionStatusController.add(_isConnected);
      debugPrint('[ConnectivityService] Connection status changed. Emitting: $_isConnected');
    } else {
      debugPrint(
        '[ConnectivityService] Connection status not changed from previous. Current: $_isConnected',
      );
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final currentStatus = results.any((result) => result != ConnectivityResult.none);
      // _isConnected = currentStatus; // Avoid side-effects in a simple check method if it's not intended to update the stream
      return currentStatus;
    } catch (e) {
      debugPrint('[ConnectivityService] checkConnectivity error: $e');
      return false;
    }
  }

  void dispose() {
    debugPrint('[ConnectivityService] Disposing.');
    _connectionStatusController.close();
  }
}
