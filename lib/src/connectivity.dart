// Copyright 2023, Anthony Champagne. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:ac_dart_essentials/ac_dart_essentials.dart';
import 'package:ac_flutter_essentials/ac_flutter_essentials.dart';
import 'package:ac_inet_connectivity_checker/ac_inet_connectivity_checker.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as connectivity_plus;

import 'typedefs.dart';
import 'inet_connectivity_state.dart';

class Connectivity extends Stream<InetConnectivityState> {
  static final defaultInetEndpoints = List.generate(
      min(_randomIpV4Endpoints.length, _randomIpV6Endpoints.length) * 2,
      (index) => index % 2 == 0
          ? _randomIpV6Endpoints[index >> 1]
          : _randomIpV4Endpoints[(index - 1) >> 1]);

  static final _randomIpV4Endpoints = [...kRootNameServersIpV4Endpoints]
    ..shuffle();
  static final _randomIpV6Endpoints = [...kRootNameServersIpV6Endpoints]
    ..shuffle();

  static final _instance = Connectivity._();
  factory Connectivity() => _instance;

  Connectivity._() {
    connectivity_plus.Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityPlusEvent);

    if (defaultTargetPlatform == TargetPlatform.android) {
      // on Android, when app is in the background it might not receive
      // an onConnectivityChanged event, so each time we resume we add
      // an event ourselves.
      _appLifecycleStream
          .where((event) => event == AppLifecycleState.resumed)
          .listen((_) async {
        await checkConnectivityPlusState();
      });
    }

    unawaited(checkConnectivityPlusState());
  }

  final _appLifecycleStream = AppLifecycleStream();
  final _connectivityPlusStreamController =
      StreamController<ConnectivityPlusState>.broadcast();
  final _inetConnectivityStreamController =
      StreamController<InetConnectivityState>.broadcast();
  CancelableTimer? _backgroundConnectivityChecker;
  ConnectivityPlusState? _lastConnectivityPlusState;
  InetConnectivityState? _lastInetConnectivityState;
  CancelableOperation? _updateStatusOperation;

  /// List of Internet endpoints to use for Internet checks
  /// if null, it will use the `defaultInetEndpoints` list.
  Iterable<InetEndpoint>? inetEndpoints;

  /// Interval of Internet background checks (default is 0)
  Duration backgroundChecksInterval = const Duration();

  /// Internet background check timeout (default is null)
  ///
  /// A null value means OS timeout will be used. The default value of null
  /// should be left as is unless the OS you are using has a low timeout.
  ///
  /// If you choose your own value, choose it high (above 30 seconds). The
  /// value in itself does not matter, but it will reduce the amount of
  /// resource used per seconds.
  Duration? backgroundCheckTimeout;

  /// Timeout for Internet check on change notification (default is 3s)
  ///
  /// What it represents is the amount of time it might take to register
  /// a change after you call `notifyChange`. In the case the device is
  /// connected via a router (which itself is no longer connected to Internet),
  /// the Internet check will hang up until the timeout is over.
  ///
  /// The value should represent the maximum time it would take for a device
  /// to connect to one of the `inetEndpoints`.
  Duration fastInetTestTimeout = const Duration(seconds: 3);

  ConnectivityPlusState? get lastConnectivityPlusState =>
      _lastConnectivityPlusState;

  InetConnectivityState? get lastInetConnectivityState =>
      _lastInetConnectivityState;

  /// equivalent to connectivity_plus's `Connectivity.onConnectivityChanged`
  /// although it guarantees that no two consecutives event are the same,
  /// and that on Android, when app is back in foreground state, it will
  /// fire an event if state has changed.
  Stream<ConnectivityPlusState> getConnectivityPlusStream() =>
      _connectivityPlusStreamController.stream;

  /// same as connectivity_plus's `Connectivity.checkConnectivity`
  Future<ConnectivityPlusState> checkConnectivityPlusState() {
    return connectivity_plus.Connectivity().checkConnectivity().then((state) {
      _handleConnectivityPlusEvent(state);
      return state;
    });
  }

  /// Get a fresh value for internet connectivity state.
  ///
  /// If timeout is null, it will check for as long as the OS socket timeout
  /// (usually 120s)
  ///
  /// NB. For Flutter on the Web, it won't make a network, it will deduce
  /// the state based on a fresh connectivity_plus value.
  CancelableOperation<InetConnectivityState> checkInetConnectivityState({
    Duration? timeout,
  }) {
    if (kIsWeb) {
      final completer = CancelableCompleter<InetConnectivityState>();

      completer.complete(connectivity_plus.Connectivity()
          .checkConnectivity()
          .then(_composeInetConnectivityStateByConnectivityPlusState));

      completer.operation.then(_handleInetConnectivityEvent);

      return completer.operation;
    }

    final checker = InetConcurrentConnectivityChecker(
      endpoints: inetEndpoints ?? defaultInetEndpoints,
      timeout: timeout,
    );

    final operation = checker.cancelableOperation
        .thenOperation<InetConnectivityState>((success, completer) {
      if (success) {
        completer.complete(InetConnectivityState.internet);
      } else {
        completer.complete(connectivity_plus.Connectivity()
            .checkConnectivity()
            .then(_composeInetConnectivityStateByConnectivityPlusState));
      }
    });

    operation.then(_handleInetConnectivityEvent);

    return operation;
  }

  /// Notify the singleton of a possible connection change
  ///
  /// Singleton will perform a Internet connectivity check.
  ///
  /// This method SHOULD be called when you encounter an error while
  /// making a network request (DNS resolution or socket opening errors).
  ///
  /// It is especially useful when user is connected to the Internet
  /// through a router (Wifi connection for example), because the router
  /// might loose access to Internet but we would have no way of knowing
  /// without making constant background checks (which this package does not).
  void notifyChange() {
    _updateStatusOperation ??=
        checkInetConnectivityState(timeout: fastInetTestTimeout)
          ..valueOrCancellation().then((_) {
            _updateStatusOperation = null;
          });
  }

  @override
  StreamSubscription<InetConnectivityState> listen(
    void Function(InetConnectivityState state)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _inetConnectivityStreamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  static InetConnectivityState
      _composeInetConnectivityStateByConnectivityPlusState(
    ConnectivityPlusState state,
  ) {
    if (state == ConnectivityPlusState.none) {
      return InetConnectivityState.disconnected;
    } else {
      return kIsWeb
          ? InetConnectivityState.internet
          : InetConnectivityState.connected;
    }
  }

  void _startBackgroundConnectivityChecker() {
    _backgroundConnectivityChecker ??= CancelableTimer.periodic(
      backgroundChecksInterval,
      (_) => checkInetConnectivityState(
        timeout: backgroundCheckTimeout,
      ).then((state) {
        if (state != InetConnectivityState.connected) {
          _backgroundConnectivityChecker?.cancel();
          _backgroundConnectivityChecker = null;
        }

        _handleInetConnectivityEvent(state);
      }),
      wait: true,
    );
  }

  void _handleConnectivityPlusEvent(ConnectivityPlusState state) {
    if (_lastConnectivityPlusState == null ||
        _lastConnectivityPlusState != state) {
      _lastConnectivityPlusState = state;

      _connectivityPlusStreamController.add(state);
    }

    _handleInetConnectivityEvent(
        _composeInetConnectivityStateByConnectivityPlusState(state));
  }

  void _handleInetConnectivityEvent(InetConnectivityState state) {
    if (_lastInetConnectivityState == null ||
        _lastInetConnectivityState != state) {
      _lastInetConnectivityState = state;

      _inetConnectivityStreamController.add(state);
    }

    if (state == InetConnectivityState.connected) {
      _startBackgroundConnectivityChecker();
    }
  }
}
