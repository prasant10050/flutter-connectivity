// Copyright 2023, Anthony Champagne. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum InetConnectivityState {
  /// Disconnected from Internet (same as [ConnectivityResult.none])
  disconnected,

  /// Connected to a network without Internet access.
  connected,

  /// Connected to Internet.
  internet,
}
