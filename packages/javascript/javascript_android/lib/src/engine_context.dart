import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

import 'package:javascript_platform_interface/javascript_platform_interface.dart';

typedef RunJavascriptCallback = Future<Object?> Function(String javaScript);

class EngineHostState {
  EngineHostState({
    required this.messageListenerInterval,
    required this.engineId,
    required RunJavascriptCallback runJavaScript,
  }) : _runJavaScript = runJavaScript,
       _ensureInitialized = runJavaScript(_MESSAGING_SCRIPT);

  final String engineId;
  final Duration messageListenerInterval;
  final RunJavascriptCallback _runJavaScript;
  final Future<void> _ensureInitialized;
  late final Logger _logger = Logger('EngineHostState.$engineId');

  final Map<String, JavaScriptChannelParams> _enabledChannels = {};

  Timer? _timer;

  void _ensureMessageListenerActive() {
    if (_timer != null) {
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    if (_isDisposed) {
      return;
    }
    _timer = Timer.periodic(messageListenerInterval, _onTimerTick);
  }

  Future<Map<String, Object?>> _getPendingMessages() async {
    final channelPendingMessages = _enabledChannels.keys
        .map((channelName) {
          return '"$channelName": globalThis["$channelName"].getPendingMessages()';
        })
        .join(',');

    final messages =
        await _runJavaScript('JSON.stringify({$channelPendingMessages})')
            as Map<String, Object?>;

    return messages;
  }

  final Map<String, Set<int>> _processingMessages = {};

  Future<Object?> _evaluateSafely(String javascript) {
    if (_isDisposed) return Future.value(null);
    return _runJavaScript(javascript);
  }

  void _onTimerTick(Timer timer) async {
    timer.cancel();
    if (_isDisposed) {
      return;
    }
    try {
      // check for pending messages
      final messages = await _getPendingMessages();
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
          final message = event['message'];
          final processingEventIds = _processingMessages.putIfAbsent(
            channelName,
            () => {},
          );
          if (!processingEventIds.contains(id)) {
            _processMessage(channel, message, channelName, id);
            processingEventIds.add(id);
          }
        }
        // resolve/reject messages
      }
    } catch (e, s) {
      _logger.severe('Error in message listener', e, s);
    }
    // resume timer
    _startTimer();
  }

  Future<void> _processMessage(
    JavaScriptChannelParams channel,
    Object? message,
    String channelName,
    int id,
  ) async {
    Future<void> evaluationResult;
    try {
      _logger.finest(
        'Processing a new message by id $id for channel $channelName: (${message.runtimeType}) $message',
      );
      final response = await channel.onMessageReceived(
        JavaScriptMessage(
          message: message is String ? message : json.encode(message),
        ),
      );
      final reply = response.message;
      String encodedMessage = 'null';
      if (reply != null) {
        encodedMessage = reply;
      }
      _logger.finest(
        'Resolved message by id $id for channel $channelName: $encodedMessage',
      );
      evaluationResult = _evaluateSafely(
        'globalThis["$channelName"].resolveById($id, ${json.encode(encodedMessage)})',
      );
    } catch (e) {
      final encodedMessage = e.toString();
      _logger.finest(
        'Rejected message by id $id for channel $channelName: $encodedMessage',
      );
      evaluationResult = _evaluateSafely(
        'globalThis["$channelName"].rejectById($id, ${json.encode(encodedMessage)})',
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

  Future<void> addChannel(
    String channelName,
    JavaScriptChannelParams channelParams,
  ) async {
    await _ensureInitialized;
    _enabledChannels[channelName] = channelParams;
    _ensureMessageListenerActive();
    try {
      await _runJavaScript('globalThis["$channelName"] = new HostMessenger();');
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
}

const String _MESSAGING_SCRIPT = r'''
class HostMessenger {
    constructor() {
        this.pendingMessages = [];
        this.id = 0;
    }

    getPendingMessages() {
        return this.pendingMessages.map(m => ({id: m.id, message: m.message}));
    }

    removeMessageById(id) {
        this.pendingMessages = this.pendingMessages.filter(m => m.id !== id);
    }

    resolveById(id, response) {
        let message = this.pendingMessages.find(m => m.id === id);
        if (message) {
            message.resolve(response);
            this.removeMessageById(id);
            return true;
        }
        return false;
    }

    rejectById(id, error) {
        let message = this.pendingMessages.find(m => m.id === id);
        if (message) {
            message.reject(error);
            this.removeMessageById(id);
            return true;
        }
        return false;
    }

    postMessage(message) {
        let promise = new Promise((resolve, reject) => {
            this.pendingMessages.push({
                id: this.id++,
                message,
                resolve,
                reject
            });
        });
        return promise;
    }
}

globalThis.sendMessage = function(channelName, message) {
  return globalThis[channelName].postMessage(message);
}
''';
