import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:javascript_example/json.dart';
import 'package:javascript_example/runtime.dart';
import 'package:web_socket/web_socket.dart';

// Service Layer
class JsRuntimeService {
  late JsRuntimeDelegate _jsRuntime;
  late http.Client _httpClient;

  Future<void> initialize() async {
    _jsRuntime = JsRuntimeDelegate();
    _httpClient = http.Client();
    return _jsRuntime.initialize();
  }

  Future<Object?> evaluate(String source) async {
    return await _jsRuntime.evaluate(source);
  }

  Future<String> loadJsFromUrl(String url) async {
    if (url.isEmpty) {
      throw Exception('URL is empty');
    }
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    } else {
      throw Exception('Failed to load JS from URL: ${response.statusCode}');
    }
  }

  void dispose() {
    _httpClient.close();
    _jsRuntime.dispose();
  }

  void setConsole({
    required void Function(String message) log,
    required void Function(String message) info,
    required void Function(String message) warn,
    required void Function(String message) error,
  }) {
    try {
      debugPrint('Setting console');
      _jsRuntime.evaluate("""
  console.log = function() {
    sendMessage('AppConsoleLog', JSON.stringify(['log', ...arguments]));
  }
  console.info = function() {
    sendMessage('AppConsoleLog', JSON.stringify(['info', ...arguments]));
  }
  console.warn = function() {
    sendMessage('AppConsoleLog', JSON.stringify(['warn', ...arguments]));
  }
  console.error = function() {
    sendMessage('AppConsoleLog', JSON.stringify(['error', ...arguments]));
  }
  """);
      _jsRuntime.onMessage('AppConsoleLog', (dynamic args) {
        // if (kDebugMode) {
        //   print('ConsoleLog: ${args.runtimeType}:$args');
        // }
        print('message: (${args.runtimeType}) $args');
        final data = args is List
            ? args
            : (args is String
                  ? json.decode(args) as List
                  : throw FormatException('Invalid console log format'));
        final logType = data.removeAt(0);
        String output = data.join(' ');
        debugPrint('jsconsole [$logType]: $output');
        switch (logType) {
          case 'info':
            info(output);
            break;
          case 'warn':
            warn(output);
            break;
          case 'error':
            error(output);
            break;
          case 'log':
          default:
            log(output);
            break;
        }
      });
    } catch (e, s) {
      if (kDebugMode) {
        print('Error setting console: $e');
        print('Stack trace: $s');
      }
      rethrow;
    }
  }

  final Map<String, WebSocket> _sockets = {};

  void _addSocket(String id, WebSocket ws) {
    _sockets[id] = ws;
  }

  bool _isSetDebug = false;

  void setRPCMessageHandler(
    String module,
    void Function(dynamic args) handler,
  ) {
    if (kDebugMode) {
      print('setRPCMessageHandler: $module');
    }
    _jsRuntime.onMessage(module, (args) async {
      try {
        final cmd = args is Map
            ? args
            : (args is String
                  ? json.decode(args) as Map
                  : throw FormatException('Invalid RPC message format'));
        final response = await (args) async {
          try {
            debugPrint('jsconsole-rpc [$module]: $args');
            handler(args);
            switch (cmd['type']) {
              case 'connectWs':
                if (!_isSetDebug) {
                  _isSetDebug = true;
                  sendRPCMessage(
                    requestId: generateRequestId(),
                    type: 'setLogLevel',
                    request: {'logLevel': 'debug', 'sendLogsToApp': true},
                  );
                  await Future.delayed(const Duration(seconds: 1));
                }

                final request = cmd['request'] as Map?;
                if (request == null) {
                  throw Exception('Invalid request: $cmd');
                }
                final id = request['id'] as String?;
                final url = request['url'] as String?;
                if (id == null || url == null) {
                  throw Exception('Invalid request: $cmd');
                }
                final ws = await WebSocket.connect(Uri.parse(url));
                _addSocket(id, ws);
                ws.events.listen((ev) {
                  switch (ev) {
                    case TextDataReceived():
                      final data = ev.text;
                      debugPrint('jsconsole-rpc [$module]: TEXT RECEIVED: $ev');
                      sendRPCMessage(
                        requestId: generateRequestId(),
                        type: 'sendWsMessage',
                        request: {'id': id, 'data': data},
                      );
                      break;
                    case BinaryDataReceived():
                      final data = ev.data;
                      debugPrint(
                        'jsconsole-rpc [$module]: BINARY RECEIVED: $ev',
                      );
                      sendRPCMessage(
                        requestId: generateRequestId(),
                        type: 'sendWsMessage',
                        request: {'id': id, 'data': bytesToBase64Json(data)},
                      );
                      break;
                    case CloseReceived():
                      debugPrint(
                        'jsconsole-rpc [$module]: CLOSE RECEIVED: $ev',
                      );
                      sendRPCMessage(
                        requestId: generateRequestId(),
                        type: 'disconnectWs',
                        request: {'id': id},
                      );
                      _sockets.remove(id);
                      break;
                  }
                });
                return {};
              case 'setLogLevelDone':
              case 'createClaimDone':
              case 'log':
              case 'console':
                debugPrint('jsconsole-rpc [$module]: console: $cmd');
                return null;
              case 'error':
                debugPrint('jsconsole-rpc [$module]: err: $cmd');
                return null;
              case 'disconnectWs':
                final request = cmd['request'] as Map;
                final id = request['id'] as String;
                final ws = _sockets[id];
                if (ws == null) {
                  throw Exception('WebSocket not found');
                }
                ws.close();
                _sockets.remove(id);
                return {};
              case 'sendWsMessage':
                final request = cmd['request'] as Map;
                final id = request['id'] as String;
                final data = request['data'];
                final ws = _sockets[id];
                debugPrint(
                  'jsconsole-rpc [$module]: sendWsMessage SENDING TO WS: $id => (${data.runtimeType}) $data',
                );
                if (ws == null) {
                  throw Exception('WebSocket not found');
                }
                if (data is String) {
                  ws.sendText(data);
                } else if (data is Map && data['type'] == 'uint8array') {
                  final bytes = base64.decode(data['value'] as String);
                  ws.sendBytes(bytes);
                } else {
                  throw Exception('Invalid data type: ${data.runtimeType}');
                }
                return {};
              case 'createClaimStep':
                debugPrint('jsconsole-rpc [$module]: createClaimStep');
                return null;
              default:
                debugPrint('jsconsole-rpc [$module]: UNKNOWN COMMAND: $cmd');
                throw UnsupportedError('Unknown RPC command: ${cmd['type']}');
            }
          } catch (e, s) {
            debugPrint('jsconsole-rpc [$module]: $e\n$s');
            debugPrintStack(stackTrace: s);
            rethrow;
          }
        }(args);
        if (response == null) {
          return;
        }
        sendRPCResponse(
          requestId: cmd['id'] ?? generateRequestId(),
          type: cmd['type'] ?? 'unknown',
          response: response,
        );
      } catch (e, s) {
        debugPrint('jsconsole-rpc ERROR [$module]: $e\n$s');
        debugPrintStack(stackTrace: s);
        sendRPCErrorResponse(
          requestId: generateRequestId(),
          message: e.toString(),
          stack: s.toString(),
        );
      }
    });
    if (kDebugMode) {
      print('setRPCMessageHandler: $module: done');
    }
  }

  void sendRPCMessage({
    required String requestId,
    required String type,
    required Map<String, dynamic> request,
  }) {
    _jsRuntime.evaluate('''
    handleIncomingMessage(${json.encode(json.encode({
      // this is a random ID you generate,
      // use to match the response to the request
      'id': requestId,
      // the type of request you want to make
      'type': type,
      'request': request,
    }))});
''');
  }

  void sendRPCResponse({
    required String requestId,
    required String type,
    required Map<dynamic, dynamic> response,
  }) {
    _jsRuntime.evaluate('''
    handleIncomingMessage(${json.encode({
      // this is a random ID you generate,
      // use to match the response to the request
      'id': requestId,
      // the type of request you want to make
      'type': '${type}Done',
      'isResponse': true,
      'response': response,
    })});
''');
  }

  void sendRPCErrorResponse({
    required String requestId,
    required String message,
    required String stack,
  }) {
    _jsRuntime.evaluate('''
    handleIncomingMessage(${json.encode({
      // this is a random ID you generate,
      // use to match the response to the request
      'id': requestId,
      // the type of request you want to make
      'type': 'error',
      'isResponse': true,
      'data': {'message': message, 'stack': stack},
    })});
''');
  }

  static String generateRequestId() {
    final random = Random.secure();
    final randomNumber = random.nextDouble();
    final hexString = randomNumber.toStringAsFixed(16).substring(2);
    return hexString;
  }
}
