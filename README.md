# connectivity_plus extended with Internet Connectivity

This package extends the [connectivity_plus](https://pub.dev/packages/connectivity_plus) plugin :
- with Internet Connectivity state (accessible on-demand or via a change stream),
- with a fix that refresh connectivity when an Android app resumes from background.
- with a stateful state of both the connectivity_plus and Internet connectivity states (with some limitations, see *Important note on Internet Connectivity Stream* below).

## Usage

### Access to the original connectivity_plus members

#### checkConnectivity

```dart
final ConnectivityPlusState state = await Connectivity().checkConnectivityPlusState();

print(state); // ConnectivityPlusState.none, .mobile, .ethernet, etc.
```

#### onConnectivityChanged stream

```dart
Connectivity().getConnectivityPlusStream().listen((state) {
  // It is guaranteed that two successive events have different values.
  print(result);
});
```

### Internet connectivity

For Internet connectivity, this package uses [ac_inet_connectivity_checker](https://pub.dev/packages/ac_inet_connectivity_checker) with the recommended endpoints configuration (randomized root nameservers' IPv4 and IPv6 addresses).

```dart
final state = Connectivity().lastInetConnectivityState;

if (state == InetConnectivityState.disconnected) {
  // disconnected (same as ConnectivityResult.none)
} else if (state == InetConnectivityState.connected) {
  // connected to a network without Internet access.
} else if (state == InetConnectivityState.internet) {
  // connected to Internet.
}
```

#### On-demand fresh value

Contrary to the network connectivity test, Internet connectivity test allows the definition of a timeout. It can be avoided if you want to handle the timeout yourself with the cancelable operation. Be aware that if you don't specify a timeout, and in some condition, it might uses the default operating system timeout which is usually 120s.

For Flutter on the Web, it will not make any network request but instead deduce the state based on a fresh connectivity_plus state.

```dart
final cancelableOperation = Connectivity().checkInetConnectivityState(
  timeout: const Duration(seconds: 3),
);

final state = await cancelableOperation.value;
```

#### Stream

> ⚠ Important: In some condition it won't automatically detect the transition from InetConnectivityState.internet to InetConnectivityState.connected. Please check "Important note on Internet Connectivity Stream" below.

```dart
Connectivity().listen((state) {
  // It is guaranteed that two successive events have different values.
  print(state);
});
```

## Important note on Internet Connectivity Stream

Detecting Internet connectivity changes without a constant background test is a tricky business. 

### Detecting Internet access

This package starts a background test (ONLY) when there's no Internet connectivity, so it can guarantee that when the app gets back online, you'll be quickly informed of it.

The speed at which you'll be informed of it depends on the network configuration : 
- If the device changes network configuration (going from a 4G network to a Wifi network for example), Internet detection will be almost instantaneous.
- Whereas if the device is connected to Internet via a router (eg. connected to Wifi), but the Wifi network itself has no Internet access, it might take as much time as the duration you've specified in the `backgroundChecksInterval` configuration (which is 0 by default).

### Detecting loss of Internet access

The real issue is to detect loss of connection when there's no network configuration changes. So for example if the device is connected to a Wifi network with its network router which looses access to the Internet, the only way to detect that the app lost Internet is either to make constant Internet Connectivity checks, or to check for error when the app makes network request (to the Internet, obviously).

The package make the choice to **not** do that constant background Internet check itself when it thinks it has access to the Internet (when `Connectivity().lastInetConnectivityState == InetConnectivityState.internet`). Instead it provides a `notifyChange` that you **must** call if you think the Internet connectivity has changed (on a HTTP request error for example). You can call it even if you're unsure.

```dart
import 'package:http/http.dart' as http;

try {
  var response = await http.get(Uri.https('google.com'));
} on SocketException {
  Connectivity().notifyChange();

  rethrow;
} catch(error) {
  print(error);
}
```

On the other hand, if you really want to implement the constant background Internet check, here's an example:

```dart
CancelableTimer? connectivityChecker;

Connectivity().listen((state) {
  if (state == InetConnectivityState.internet) {
    connectivityChecker = CancelableTimer.periodic(
      const Duration(seconds: 60),
      (_) => Connectivity().checkInetConnectivityState(),
      wait: true,
    );
  } else {
    connectivityChecker?.cancel();
    connectivityChecker = null;
  }
})
```
