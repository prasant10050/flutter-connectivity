import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:anthochamp_dart_essentials/dart_essentials.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as connectivity_plus;
import 'package:flutter_essentials/flutter_essentials.dart';
import 'package:inet_connectivity_checker/inet_connectivity_checker.dart';

export 'package:inet_connectivity_checker/inet_connectivity_checker.dart'
    show ConnectivityCheckerEndpoint;

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

enum ConnectionStatus {
  disconnected,
  connected,
  internet,
}

class ConnectivityPlusExtended
    extends Stream<connectivity_plus.ConnectivityResult> {
  static final _subscriptionsFinalizer = createStreamSubscriptionFinalizer();

  ConnectivityPlusExtended() {
    final onConnectivityChangedSubscription =
        _connectivity.onConnectivityChanged.listen(_streamController.add);

    _subscriptionsFinalizer.attach(this, onConnectivityChangedSubscription);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final appLifecycleStreamSubscription = _appLifecycleStream
          .where((event) => event == AppLifecycleState.resumed)
          .listen((_) async {
        _streamController.add(await getConnectivityResult());
      });

      _subscriptionsFinalizer.attach(this, appLifecycleStreamSubscription);
    }
  }

  final _appLifecycleStream = AppLifecycleStream();
  final _connectivity = connectivity_plus.Connectivity();
  final _streamController =
      StreamController<connectivity_plus.ConnectivityResult>.broadcast();

  @override
  StreamSubscription<connectivity_plus.ConnectivityResult> listen(
          void Function(connectivity_plus.ConnectivityResult event)? onData,
          {Function? onError,
          void Function()? onDone,
          bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  Future<connectivity_plus.ConnectivityResult> getConnectivityResult() =>
      _connectivity.checkConnectivity();

  /// Nota: if timeout is null, it will check for as long as the OS socket timeout
  CancelableOperation<ConnectionStatus> getConnectionStatus(
    Iterable<ConnectivityCheckerEndpoint> internetTestEndpoints,
    Duration? timeout,
  ) {
    if (kIsWeb) {
      final completer = CancelableCompleter<ConnectionStatus>();
      completer.complete(getConnectivityResult()
          .then(_composeConnectionStatusByConnectivityResult));

      return completer.operation;
    }

    return checkConnectivity(
      internetTestEndpoints,
      timeout: timeout,
    ).thenOperation<ConnectionStatus>((result, completer) {
      if (result) {
        completer.complete(ConnectionStatus.internet);
      } else {
        completer.complete(getConnectivityResult()
            .then(_composeConnectionStatusByConnectivityResult));
      }
    });
  }

  static ConnectionStatus _composeConnectionStatusByConnectivityResult(
    connectivity_plus.ConnectivityResult connectivityResult,
  ) {
    if (connectivityResult == connectivity_plus.ConnectivityResult.none) {
      return ConnectionStatus.disconnected;
    } else {
      return kIsWeb ? ConnectionStatus.internet : ConnectionStatus.connected;
    }
  }
}
