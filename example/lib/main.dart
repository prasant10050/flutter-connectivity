// Copyright 2023, Anthony Champagne. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:ac_connectivity/flutter_internet_connectivity.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ConnectivityPlusState? _lastConnectivityPlusState;
  InternetConnectivityState? _lastInetConnectivityState;
  StreamSubscription? _inetConnectivityStreamSubscription;
  StreamSubscription? _connectivityPlusStreamSubscription;

  @override
  void initState() {
    super.initState();

    _lastConnectivityPlusState = Connectivity().lastConnectivityPlusState;
    _lastInetConnectivityState = Connectivity().lastInetConnectivityState;

    _connectivityPlusStreamSubscription =
        Connectivity().getConnectivityPlusStream().listen((state) {
      setState(() {
        _lastConnectivityPlusState = state;
      });
    });

    _inetConnectivityStreamSubscription = Connectivity().listen((state) {
      setState(() {
        _lastInetConnectivityState = state;
      });
    });
  }

  @override
  void dispose() {
    _inetConnectivityStreamSubscription?.cancel();
    _connectivityPlusStreamSubscription?.cancel();

    super.dispose();
  }

  void _notifyConnectivityChange() {
    Connectivity().notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Last connectivity_plus state:'),
            Text(
              '$_lastConnectivityPlusState',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            const Text('Last Internet connectivity state:'),
            Text(
              '$_lastInetConnectivityState',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _notifyConnectivityChange,
        tooltip: 'Notify connectivity change',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
