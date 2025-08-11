import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javascript/javascript.dart';
import 'package:javascript_example/runtime_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  GoogleFonts.pendingFonts([GoogleFonts.sourceCodePro()]);

  runApp(const JsInterpreterApp());
}

class JsInterpreterApp extends StatelessWidget {
  const JsInterpreterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JS Interpreter Console',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.green,
          secondary: Colors.greenAccent,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Colors.green,
          elevation: 0,
        ),
      ),
      home: const JsInterpreterPage(),
    );
  }
}

// Repository Layer
class JsCodeRepository {
  final JsRuntimeService _jsService;

  JsCodeRepository(this._jsService);

  Future<Object?> executeCode(String code) async {
    return await _jsService.evaluate(code);
  }

  Future<String> loadFromUrl(String url) async {
    return await _jsService.loadJsFromUrl(url);
  }

  void setConsole({
    required void Function(String message) log,
    required void Function(String message) error,
    required void Function(String message) info,
    required void Function(String message) warn,
  }) {
    return _jsService.setConsole(
      log: log,
      error: error,
      info: info,
      warn: warn,
    );
  }

  void setRPCMessageHandler(
    String module,
    void Function(dynamic args) handler,
  ) {
    return _jsService.setRPCMessageHandler(module, handler);
  }
}

// Use Case Layer
class ExecuteJsUseCase {
  final JsCodeRepository _repository;

  ExecuteJsUseCase(this._repository);

  Future<Object?> execute(String code) async {
    return await _repository.executeCode(code);
  }

  Future<String> loadFromUrl(String url) async {
    return await _repository.loadFromUrl(url);
  }

  void setConsole({
    required void Function(String message) log,
    required void Function(String message) error,
    required void Function(String message) info,
    required void Function(String message) warn,
  }) {
    return _repository.setConsole(
      log: log,
      error: error,
      info: info,
      warn: warn,
    );
  }

  void setRPCMessageHandler(
    String module,
    void Function(dynamic args) handler,
  ) {
    return _repository.setRPCMessageHandler(module, handler);
  }
}

// ViewModel
class JsInterpreterViewModel extends ChangeNotifier {
  final ExecuteJsUseCase _useCase;

  Object? _result;
  Object? _error;
  bool _isLoading = false;
  final List<ConsoleEntry> _consoleHistory = [];
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  JsInterpreterViewModel(this._useCase) {
    _useCase.setConsole(
      log: (message) => _addToHistory(ConsoleEntry.output(message)),
      error: (message) => _addToHistory(ConsoleEntry.error(message)),
      info: (message) => _addToHistory(ConsoleEntry.info(message)),
      warn: (message) => _addToHistory(ConsoleEntry.warn(message)),
    );
    _useCase.setRPCMessageHandler('attestor-core', (args) {
      try {
        _addToHistory(
          ConsoleEntry.output(args is String ? args : json.encode(args)),
        );
      } catch (e, s) {
        _addToHistory(ConsoleEntry.error('Error parsing RPC message: $e\n$s'));
      }
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
      if (kDebugMode) {
        print('no code entered');
      }
      return;
    }

    _addToHistory(ConsoleEntry.input(code));
    _setLoading(true);
    _clearError();

    try {
      _result = await _useCase.execute(code);
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

    _setLoading(true);
    _clearError();

    try {
      final code = await _useCase.loadFromUrl(url);
      _inputController.text = code;
      _addToHistory(ConsoleEntry.info('Loaded code from: $url'));
    } catch (e) {
      _error = e;
      _addToHistory(
        ConsoleEntry.error('Failed to load from URL: ${e.toString()}'),
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

// Models
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

// Main Page
class JsInterpreterPage extends StatefulWidget {
  const JsInterpreterPage({super.key});

  @override
  State<JsInterpreterPage> createState() => _JsInterpreterPageState();
}

class _JsInterpreterPageState extends State<JsInterpreterPage> {
  JsInterpreterViewModel? _viewModel;
  JsRuntimeService? _jsService;
  ExecuteJsUseCase? _useCase;
  JsCodeRepository? _repository;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _jsService = JsRuntimeService();
    await _jsService!.initialize();
    _repository = JsCodeRepository(_jsService!);
    _useCase = ExecuteJsUseCase(_repository!);
    _viewModel = JsInterpreterViewModel(_useCase!);
    _viewModel!.addListener(_onViewModelChanged);
    setState(() {});
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    _jsService?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JS Interpreter Console'),
        actions: [
          IconButton(
            onPressed: _viewModel?.clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Column(
        children: [
          // URL Input Section
          UrlInputSection(viewModel: _viewModel!),

          // Console Output
          Expanded(
            child: ConsoleOutputSection(
              viewModel: _viewModel!,
              scrollController: _scrollController,
            ),
          ),

          // Command Input Section
          CommandInputSection(viewModel: _viewModel!),
        ],
      ),
    );
  }
}

// Widget Components
class UrlInputSection extends StatelessWidget {
  final JsInterpreterViewModel viewModel;

  const UrlInputSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: viewModel.urlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter JS source URL (optional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => viewModel.loadFromUrl(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: viewModel.loadFromUrl,
            icon: const Icon(Icons.download, color: Colors.green),
            tooltip: 'Load from URL',
          ),
        ],
      ),
    );
  }
}

class ConsoleOutputSection extends StatelessWidget {
  final JsInterpreterViewModel viewModel;
  final ScrollController scrollController;

  const ConsoleOutputSection({
    super.key,
    required this.viewModel,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.consoleHistory.length,
        itemBuilder: (context, index) {
          final entry = viewModel.consoleHistory[index];
          return ConsoleEntryWidget(entry: entry);
        },
      ),
    );
  }
}

class ConsoleEntryWidget extends StatelessWidget {
  final ConsoleEntry entry;

  const ConsoleEntryWidget({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrefix(),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 1.2 * 14 * 20),
              child: Text(
                entry.content,
                style: _getTextStyle(),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefix() {
    switch (entry.type) {
      case ConsoleEntryType.input:
        return const Text(
          '> ',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        );
      case ConsoleEntryType.output:
        return const Text(
          '← ',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        );
      case ConsoleEntryType.error:
        return const Text(
          '✗ ',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        );
      case ConsoleEntryType.warn:
        return const Text(
          '! ',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        );
      case ConsoleEntryType.info:
        return const Text(
          'ℹ ',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        );
    }
  }

  TextStyle _getTextStyle() {
    final baseStyle = GoogleFonts.sourceCodePro(fontSize: 14);

    switch (entry.type) {
      case ConsoleEntryType.input:
        return baseStyle.copyWith(color: Colors.green);
      case ConsoleEntryType.output:
        return baseStyle.copyWith(color: Colors.white);
      case ConsoleEntryType.error:
        return baseStyle.copyWith(color: Colors.red);
      case ConsoleEntryType.warn:
        return baseStyle.copyWith(color: Colors.orange);
      case ConsoleEntryType.info:
        return baseStyle.copyWith(color: Colors.yellow);
    }
  }
}

class CommandInputSection extends StatelessWidget {
  final JsInterpreterViewModel viewModel;

  const CommandInputSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.green,
                  size: 16,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: viewModel.inputController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter JavaScript code...',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  onSubmitted: (_) => viewModel.executeCode(),
                  maxLines: 5,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              if (viewModel.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: viewModel.executeCode,
                      icon: const Icon(Icons.play_arrow, color: Colors.green),
                      tooltip: 'Execute (Enter)',
                    ),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              AnimatedBuilder(
                animation: viewModel._inputController,
                builder: (context, child) {
                  if (viewModel._inputController.text.isEmpty) {
                    return const SizedBox(height: kMinInteractiveDimension);
                  }
                  return OutlinedButton.icon(
                    onPressed: viewModel.clearInput,
                    icon: const Icon(Icons.close, color: Colors.green),
                    label: const Text('Clear'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
