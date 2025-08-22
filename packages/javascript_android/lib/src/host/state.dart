import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

import 'package:javascript_platform_interface/javascript_platform_interface.dart';

part 'scripts.dart';

typedef RunJavascriptCallback = Future<Object?> Function(String javaScript);

class EngineHostState {
  EngineHostState._({
    required this.messageListenerInterval,
    required this.engineId,
    required RunJavascriptCallback runJavaScript,
    required this.useConsoleMessagingHack,
  }) {
    _runJavaScript = (String javascript) {
      if (_isDisposed) return Future.value(null);
      return runJavaScript(javascript);
    };
  }

  static const _envExport = 'globalThis.JavaScriptAndroid';

  static Future<EngineHostState> create({
    required String engineId,
    required Duration messageListenerInterval,
    bool implementJsSetTimeout = true,
    required RunJavascriptCallback runJavaScript,
    // A hack that uses console message handler to receive new channel messages
    // for more efficient communication because jetpack javascript engine doesn't
    // have an api to set javascript interface in javascript environment
    required bool useConsoleMessagingHack,
  }) async {
    final state = EngineHostState._(
      messageListenerInterval: messageListenerInterval,
      engineId: engineId,
      runJavaScript: runJavaScript,
      useConsoleMessagingHack: useConsoleMessagingHack,
    );

    await state._runJavaScript(_MESSAGING_SCRIPT(useConsoleMessagingHack));
    if (implementJsSetTimeout) {
      await state._runJavaScript(_TIMEOUT_SCRIPT);
      await state._setupJsSetTimeoutMessaging();
    }

    return state;
  }

  final String engineId;
  final Duration messageListenerInterval;
  final bool useConsoleMessagingHack;

  late final RunJavascriptCallback _runJavaScript;

  late final Logger _logger = Logger('EngineHostState.$engineId');

  final Map<String, JavaScriptChannelParams> _enabledChannels = {};

  Timer? _timer;

  void _ensureMessageListenerActive() {
    if (_timer != null) {
      return;
    }
    if (useConsoleMessagingHack) return;
    _startTimer();
  }

  void _startTimer() {
    if (_isDisposed) {
      return;
    }
    _timer = Timer.periodic(messageListenerInterval, _onTimerTick);
  }

  Future<Map<String, Object?>> getPendingMessages() async {
    final channelPendingMessages = _enabledChannels.keys.map((channelName) {
      return '"$channelName": $_envExport.getPendingMessages("$channelName")';
    }).join(',');

    final messages =
        await _runJavaScript('JSON.stringify({$channelPendingMessages})')
            as Map<String, Object?>;

    return messages;
  }

  Future<Map<String, Object?>> getPendingMessagesBy(
    String channelName,
    num id,
  ) async {
    final channelPendingMessages = [channelName].map((channelName) {
      return '"$channelName": $_envExport.getPendingMessages("$channelName").filter(it => it.id == $id)';
    }).join(',');

    final messages =
        await _runJavaScript('JSON.stringify({$channelPendingMessages})')
            as Map<String, Object?>;

    return messages;
  }

  final Map<String, Set<int>> _processingMessages = {};

  void _onTimerTick(Timer timer) async {
    timer.cancel();
    if (_isDisposed) {
      return;
    }
    try {
      // check for pending messages
      final messages = await getPendingMessages();
      onChannelMessages(messages);
    } catch (e, s) {
      _logger.severe('Error in message listener', e, s);
    }
    // resume timer
    _startTimer();
  }

  void onChannelMessages(Map<String, Object?> messages) {
    for (final message in messages.entries) {
      // send messages to channels and wait for responses
      final channelName = message.key;
      final events = message.value as List<Object?>;
      final channel = _enabledChannels[channelName];
      if (channel == null) {
        _logger.severe('Channel $channelName not found');
        continue;
      }
      for (final event in events) {
        if (event is! Map<String, Object?>) {
          _logger.severe(
            'Invalid event received for channel $channelName: $event',
          );
          continue;
        }
        final id = event['id'] as int;
        final message = event['message'] as String;
        final processingEventIds = _processingMessages.putIfAbsent(
          channelName,
          () => {},
        );
        if (!processingEventIds.contains(id)) {
          _processMessage(channel, message, channelName, id);
          processingEventIds.add(id);
        }
      }
    }
  }

  Future<void> _processMessage(
    JavaScriptChannelParams channel,
    String message,
    String channelName,
    int id,
  ) async {
    Future<void> evaluationResult;
    try {
      _logger.finest(
        'Processing a new message by id $id for channel $channelName: (${message.runtimeType}) $message',
      );
      final response = await channel.onMessageReceived(
        JavaScriptMessage(message: message),
      );
      final reply = response.message;
      String encodedMessage = 'null';
      if (reply != null) {
        encodedMessage = reply;
      }
      _logger.finest(
        'Resolved message by id $id for channel $channelName: $encodedMessage',
      );
      evaluationResult = _runJavaScript(
        '$_envExport.HostMessengerRegisteredChannels["$channelName"].resolveById($id, ${json.encode(encodedMessage)})',
      );
    } catch (e) {
      final encodedMessage = e.toString();
      _logger.finest(
        'Rejected message by id $id for channel $channelName: $encodedMessage',
      );
      evaluationResult = _runJavaScript(
        '$_envExport.HostMessengerRegisteredChannels["$channelName"].rejectById($id, new Error(${json.encode(encodedMessage)}))',
      );
    }
    try {
      await evaluationResult;
    } catch (e, s) {
      _logger.severe('Error in message listener', e, s);
    }
    final processingEventIds = _processingMessages[channelName];
    processingEventIds?.remove(id);
  }

  void _removeTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> addChannel(JavaScriptChannelParams channelParams) async {
    final channelName = channelParams.name;
    _enabledChannels[channelName] = channelParams;
    _ensureMessageListenerActive();
    try {
      await _runJavaScript(
          '''$_envExport.HostMessengerRegisteredChannels["$channelName"] = new HostMessenger("$channelName");
      // for compatibility with popular webview plugins receiving messages
      globalThis["$channelName"] = $_envExport.HostMessengerRegisteredChannels["$channelName"];''');
      _logger.finest('Channel $channelName added');
    } catch (e, s) {
      _logger.severe('Error adding channel $channelName', e, s);
      rethrow;
    }
  }

  void removeChannel(String channelName) {
    _enabledChannels.remove(channelName);
    final events = _processingMessages.remove(channelName);
    events?.clear();
    if (_enabledChannels.isEmpty) {
      _removeTimer();
    }
  }

  bool _isDisposed = false;

  void dispose() {
    _isDisposed = true;
    _removeTimer();
    _enabledChannels.clear();
  }

  Future<void> _setupJsSetTimeoutMessaging() async {
    await addChannel(
      JavaScriptChannelParams(
        name: 'SetTimeout',
        onMessageReceived: (message) async {
          try {
            final args = json.decode(message.message ?? '{}');
            final int duration = args['timeout'] ?? 0;
            final String idx = args['timeoutIndex'];

            Future.delayed(Duration(milliseconds: duration), () async {
              try {
                await _runJavaScript("""
            __NATIVE_HOST_JS__setTimeoutCallbacks[$idx].call();
            delete __NATIVE_HOST_JS__setTimeoutCallbacks[$idx];
          """);
              } catch (e, s) {
                _logger.severe(
                  'Error when running setTimeout callback by id $idx',
                  e,
                  s,
                );
              }
            });
          } catch (e, s) {
            _logger.severe('Exception no setTimeout: $e', s);
          }
          return JavaScriptReply(message: '');
        },
      ),
    );
  }
}
