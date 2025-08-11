import 'package:flutter/foundation.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

/// A message that was sent by JavaScript code running in a [JavaScriptPlatform] runtime.
@immutable
class JavaScriptMessage {
  /// Creates a new JavaScript message object.
  const JavaScriptMessage({required this.message});

  /// The contents of the message that was sent by the JavaScript code.
  final String? message;
}

/// A message that is sent to the JavaScript code running in a [JavaScriptPlatform] runtime as a reply to a [JavaScriptMessage] .
@immutable
class JavaScriptReply {
  /// Creates a new JavaScript message object.
  const JavaScriptReply({required this.message});

  /// The contents of the message that is sent back to the JavaScript code.
  final String? message;
}
