import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:javascript/javascript.dart';
import 'package:logging/logging.dart';

import 'runtime_service.dart';

final Logger _log = Logger('JsInterpreterViewModel');

class JsInterpreterViewModel extends ChangeNotifier {
  final JsRuntimeService _service;

  Object? _result;
  Object? _error;
  bool _isLoading = false;
  final List<ConsoleEntry> _consoleHistory = [];
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  JsInterpreterViewModel(this._service);

  Future<void> initialize() async {
    await _service.useJsRuntime((js) async {
      await js.runJavaScriptReturningResult("""
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
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'AppConsoleLog',
          onMessageReceived: (JavaScriptMessage message) async {
            final data = json.decode(message.message ?? '[]') as List;
            final logType = data.removeAt(0);
            final output = data.join(' ');
            _log.info('jsconsole [$logType]: $output');

            final ConsoleEntry entry = switch (logType) {
              'info' => ConsoleEntry.info(output),
              'warn' => ConsoleEntry.warn(output),
              'error' => ConsoleEntry.error(output),
              _ => ConsoleEntry.output(output),
            };

            _addToHistory(entry);

            return JavaScriptReply(message: '');
          },
        ),
      );

      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Sum',
          onMessageReceived: (message) {
            final data = json.decode(message.message!);
            return JavaScriptReply(message: json.encode(data['a'] + data['b']));
          },
        ),
      );

      /// Add your own code to evaluate javascript or add javascript channels here
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'ExampleChannel',
          onMessageReceived: (message) {
            _log.info(
              'Received message from ExampleChannel: ${message.message}',
            );
            return JavaScriptReply(
              message: 'replying from host: ${message.message}',
            );
          },
        ),
      );
    });
  }

  Object? get result => _result;
  Object? get error => _error;
  bool get isLoading => _isLoading;
  List<ConsoleEntry> get consoleHistory => _consoleHistory;
  TextEditingController get inputController => _inputController;
  TextEditingController get urlController => _urlController;

  Future<void> executeCode() async {
    final code = _inputController.text.trim();
    if (code.isEmpty) {
      _log.info('no code entered');
      return;
    }

    _addToHistory(ConsoleEntry.input(code));
    _setLoading(true);
    _clearError();

    try {
      _result = await _service.evaluate(code);
      _addToHistory(ConsoleEntry.output(_result.toString()));
      clearInput();
    } catch (e) {
      _error = e;
      _addToHistory(
        ConsoleEntry.error(
          e is JavaScriptExecutionException ? e.message : e.toString(),
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    _addToHistory(ConsoleEntry.info('Loading from URL: $url'));
    _setLoading(true);
    _clearError();

    try {
      _result = await _service.loadJsFromUrlAndEvaluate(url);
      _addToHistory(ConsoleEntry.output(_result.toString()));
      _addToHistory(ConsoleEntry.info('Loaded code & evaluated from: $url'));
    } catch (e) {
      _error = e;
      _addToHistory(
        ConsoleEntry.error(
          'Failed to load from URL: ${e is JavaScriptExecutionException ? e.message : e.toString()}',
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  void clearAll() {
    _inputController.clear();
    _urlController.clear();
    _clearResult();
    _clearError();
    _consoleHistory.clear();
    notifyListeners();
  }

  void clearInput() {
    _inputController.clear();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearResult() {
    _result = null;
    notifyListeners();
  }

  void _addToHistory(ConsoleEntry entry) {
    _consoleHistory.add(entry);
    notifyListeners();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _urlController.dispose();
    super.dispose();
  }
}

class ConsoleEntry {
  final String content;
  final ConsoleEntryType type;
  final DateTime timestamp;

  ConsoleEntry(this.content, this.type) : timestamp = DateTime.now();

  factory ConsoleEntry.input(String content) =>
      ConsoleEntry(content, ConsoleEntryType.input);
  factory ConsoleEntry.output(String content) =>
      ConsoleEntry(content, ConsoleEntryType.output);
  factory ConsoleEntry.error(String content) =>
      ConsoleEntry(content, ConsoleEntryType.error);
  factory ConsoleEntry.info(String content) =>
      ConsoleEntry(content, ConsoleEntryType.info);
  factory ConsoleEntry.warn(String content) =>
      ConsoleEntry(content, ConsoleEntryType.warn);
}

enum ConsoleEntryType { input, output, error, info, warn }
