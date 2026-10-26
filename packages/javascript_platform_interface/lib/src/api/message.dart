import 'package:meta/meta.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

/// A message that was sent by JavaScript code running in a [JavaScriptPlatform] environment.
@immutable
class JavaScriptMessage {
  /// Creates a new JavaScript message object.
  const JavaScriptMessage({required this.message});

  /// The contents of the message that was sent by the JavaScript code.
  ///
  /// This is the string passed to `sendMessage(channelName, message)` in
  /// JavaScript, delivered verbatim. Nothing is decoded; use `jsonDecode` if
  /// the script sent `JSON.stringify(...)`.
  final String? message;
}

/// A message that is sent to the JavaScript code running in a [JavaScriptPlatform] environment as a reply to a [JavaScriptMessage] .
@immutable
class JavaScriptReply {
  /// Creates a new JavaScript message object.
  const JavaScriptReply({required this.message});

  /// The contents of the message that is sent back to the JavaScript code.
  ///
  /// It is delivered verbatim to JavaScript as the string the promise returned
  /// by `sendMessage(...)` resolves to. Nothing is encoded; use `jsonEncode`
  /// to reply with structured data and `JSON.parse` it in JavaScript.
  ///
  /// A `null` message resolves the JavaScript promise with `null`.
  final String? message;
}
