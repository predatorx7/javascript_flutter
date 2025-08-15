import 'dart:async';

import 'package:flutter/foundation.dart';

import 'message.dart';

/// Describes the parameters necessary for registering a JavaScript channel.
@immutable
class JavaScriptChannelParams {
  /// Creates a new [JavaScriptChannelParams] object.
  const JavaScriptChannelParams({required this.name, required this.onMessageReceived});

  /// The name that identifies the JavaScript channel.
  final String name;

  /// The callback method that is invoked when a [JavaScriptMessage] is
  /// received.
  final FutureOr<JavaScriptReply> Function(JavaScriptMessage) onMessageReceived;
}
