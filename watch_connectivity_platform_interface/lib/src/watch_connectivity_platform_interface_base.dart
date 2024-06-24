import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

class WatchStatus {
  const WatchStatus({
    required this.isPaired,
    required this.isReachable,
    required this.isWatchAppInstalled,
  });

  final bool isPaired;
  final bool isReachable;
  final bool isWatchAppInstalled;
}

/// Interface to communicate with watch devices
///
/// Implementations are provided separately for each watch platform
///
/// See implementation overrides for platform-specific documentation
abstract class WatchConnectivityBase {
  /// The channel for communicating with the plugin's native code
  @protected
  final MethodChannel channel;

  final _watchStatusStreamController = BehaviorSubject<WatchStatus>();
  final _messageStreamController = BehaviorSubject<Map<String, dynamic>>();
  final _contextStreamController = BehaviorSubject<Map<String, dynamic>>();
  final _userInfoStreamController = BehaviorSubject<Map<String, dynamic>>();

  /// Stream of watch status changes
  Stream<WatchStatus> get watchStatusStream =>
      _watchStatusStreamController.stream;

  /// Stream of messages received
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  /// Stream of contexts received
  Stream<Map<String, dynamic>> get contextStream =>
      _contextStreamController.stream;

  /// Stream of user info received
  Stream<Map<String, dynamic>> get userInfoStream =>
      _userInfoStreamController.stream;

  /// Create an instance of [WatchConnectivityBase] for the given
  /// [pluginName]
  WatchConnectivityBase({required String pluginName})
      : channel = MethodChannel(pluginName) {
    channel.setMethodCallHandler(_handle);
  }

  void dispose() {
    _watchStatusStreamController.close();
    _messageStreamController.close();
    _contextStreamController.close();
    _userInfoStreamController.close();
  }

  Future _handle(MethodCall call) async {
    switch (call.method) {
      case 'didUpdateWatchState':
        _watchStatusStreamController.add(WatchStatus(
          isPaired: call.arguments['isPaired'],
          isReachable: call.arguments['isReachable'],
          isWatchAppInstalled: call.arguments['isWatchAppInstalled'],
        ));
        break;
      case 'didReceiveMessage':
        _messageStreamController.add(Map<String, dynamic>.from(call.arguments));
        break;
      case 'didReceiveApplicationContext':
        _contextStreamController.add(Map<String, dynamic>.from(call.arguments));
        break;
      case 'didReceiveUserInfo':
        _userInfoStreamController
            .add(Map<String, dynamic>.from(call.arguments));
        break;
      default:
        throw UnimplementedError('${call.method} not implemented');
    }
  }

  /// Get current status of the watch
  Future<WatchStatus?> get status async {
    final rawResult =
        await channel.invokeMethod<Map<Object?, Object?>>('status');
    final result = rawResult == null ? null : Map<String, bool>.from(rawResult);
    return result != null
        ? WatchStatus(
            isPaired: result['isPaired'] ?? false,
            isReachable: result['isReachable'] ?? false,
            isWatchAppInstalled: result['isWatchAppInstalled'] ?? false,
          )
        : null;
  }

  /// If watches are supported by the current platform
  Future<bool> get isSupported async {
    final supported = await channel.invokeMethod<bool>('isSupported');
    return supported ?? false;
  }

  /// If a watch is paired
  Future<bool> get isPaired async {
    final paired = await channel.invokeMethod<bool>('isPaired');
    return paired ?? false;
  }

  /// If the companion app is reachable
  Future<bool> get isReachable async {
    final reachable = await channel.invokeMethod<bool>('isReachable');
    return reachable ?? false;
  }

  /// The most recently sent contextual data
  Future<Map<String, dynamic>> get applicationContext async {
    final applicationContext =
        await channel.invokeMapMethod<String, dynamic>('applicationContext');
    return applicationContext ?? {};
  }

  /// A dictionary containing the last update data received
  Future<List<Map<String, dynamic>>> get receivedApplicationContexts async {
    final receivedApplicationContexts =
        await channel.invokeListMethod<Map>('receivedApplicationContexts');
    return receivedApplicationContexts
            ?.map((e) => e.cast<String, dynamic>())
            .toList() ??
        [];
  }

  /// Send a message to all connected watches
  Future<void> sendMessage(Map<String, dynamic> message) {
    return channel.invokeMethod('sendMessage', message);
  }

  /// Update the application context
  Future<void> updateApplicationContext(Map<String, dynamic> context) {
    return channel.invokeMethod('updateApplicationContext', context);
  }

  /// Transfer user info
  Future<void> transferUserInfo(Map<String, dynamic> info) {
    return channel.invokeMethod('transferUserInfo', info);
  }
}
