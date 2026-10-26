/// The mechanism JavaScript uses to deliver channel messages to Dart.
///
/// Transports are selected in declaration order: the first one the device
/// supports (and that is not disabled for testing) wins.
enum JavaScriptAndroidMessagingTransport {
  /// `androidx.javascriptengine` message ports (`JS_FEATURE_MESSAGE_PORTS`).
  messagePort,

  /// `console.warn` notifications (`JS_FEATURE_CONSOLE_MESSAGING`).
  consoleMessaging,

  /// Periodically polling the JavaScript environment for pending messages.
  polling,
}
