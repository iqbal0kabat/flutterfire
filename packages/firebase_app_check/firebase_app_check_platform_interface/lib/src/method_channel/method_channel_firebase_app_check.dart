// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import '../../firebase_app_check_platform_interface.dart';
import 'utils/exception.dart';

class MethodChannelFirebaseAppCheck extends FirebaseAppCheckPlatform {
  /// Create an instance of [MethodChannelFirebaseAppCheck].
  MethodChannelFirebaseAppCheck({required FirebaseApp app})
      : super(appInstance: app) {
    _tokenChangesListeners[app.name] =
        StreamController<AppCheckTokenResult>.broadcast();

    channel.invokeMethod<String>('FirebaseAppCheck#registerTokenListener', {
      'appName': app.name,
    }).then((channelName) {
      final events = EventChannel(channelName!, channel.codec);
      events.receiveBroadcastStream().listen(
        (arguments) {
          // ignore: close_sinks
          StreamController<AppCheckTokenResult> controller =
              _tokenChangesListeners[app.name]!;
          Map<dynamic, dynamic> result = arguments;
          controller.add(AppCheckTokenResult(result['result']));
        },
      );
    });
  }

  static final Map<String, StreamController<AppCheckTokenResult>>
      _tokenChangesListeners = {};

  static Map<String, MethodChannelFirebaseAppCheck>
      _methodChannelFirebaseAppCheckInstances =
      <String, MethodChannelFirebaseAppCheck>{};

  /// The [MethodChannel] used to communicate with the native plugin
  static MethodChannel channel = const MethodChannel(
    'plugins.flutter.io/firebase_app_check',
  );

  /// Returns a stub instance to allow the platform interface to access
  /// the class instance statically.
  static MethodChannelFirebaseAppCheck get instance {
    return MethodChannelFirebaseAppCheck._();
  }

  /// Internal stub class initializer.
  ///
  /// When the user code calls an auth method, the real instance is
  /// then initialized via the [delegateFor] method.
  MethodChannelFirebaseAppCheck._() : super(appInstance: null);

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) {
    return _methodChannelFirebaseAppCheckInstances.putIfAbsent(app.name, () {
      return MethodChannelFirebaseAppCheck(app: app);
    });
  }

  @override
  MethodChannelFirebaseAppCheck setInitialValues() {
    return this;
  }

  @override
  Future<void> activate({String? webRecaptchaSiteKey}) async {
    try {
      await channel.invokeMethod<void>('FirebaseAppCheck#activate', {
        'appName': app.name,
      });
    } on PlatformException catch (e, s) {
      throw platformExceptionToFirebaseException(e, s);
    }
  }

  @override
  Future<AppCheckTokenResult> getToken(bool forceRefresh) async {
    try {
      final result = await channel.invokeMapMethod(
        'FirebaseAppCheck#getToken',
        {'appName': app.name, 'forceRefresh': forceRefresh},
      );

      return AppCheckTokenResult(result!['token']);
    } on PlatformException catch (e, s) {
      throw platformExceptionToFirebaseException(e, s);
    }
  }

  @override
  Future<void> setTokenAutoRefreshEnabled(
    bool isTokenAutoRefreshEnabled,
  ) async {
    try {
      await channel.invokeMapMethod(
        'FirebaseAppCheck#setTokenAutoRefreshEnabled',
        {
          'appName': app.name,
          'isTokenAutoRefreshEnabled': isTokenAutoRefreshEnabled
        },
      );
    } on PlatformException catch (e, s) {
      throw platformExceptionToFirebaseException(e, s);
    }
  }

  @override
  Stream<AppCheckTokenResult> tokenChanges() {
    return _tokenChangesListeners[app.name]!.stream;
  }
}
