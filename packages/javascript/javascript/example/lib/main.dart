import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javascript_example/src/runtime_service.dart';
import 'package:logging/logging.dart';

import 'src/model.dart';
import 'src/ui/command_input.dart';
import 'src/ui/console_output.dart';
import 'src/ui/url_input.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Load fonts
  GoogleFonts.config.allowRuntimeFetching = true;
  GoogleFonts.pendingFonts([GoogleFonts.sourceCodePro()]);

  // setup logging
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '(${record.sequenceNumber.toString().padLeft(4)}) ${record.level.name.padLeft(7)} [${record.time}]: ${record.message}',
    );
    if (record.error != null) {
      debugPrint(record.error.toString());
      if (record.stackTrace != null) {
        debugPrintStack(stackTrace: record.stackTrace);
      }
    }
  });

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

// Main Page
class JsInterpreterPage extends StatefulWidget {
  const JsInterpreterPage({super.key});

  @override
  State<JsInterpreterPage> createState() => _JsInterpreterPageState();
}

class _JsInterpreterPageState extends State<JsInterpreterPage> {
  final JsRuntimeService _jsService = JsRuntimeService();
  late final JsInterpreterViewModel _viewModel = JsInterpreterViewModel(
    _jsService,
  );
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _initializeServices();
  }

  bool _isInitialized = false;

  Future<void> _initializeServices() async {
    if (_isInitialized) return;
    await _jsService.initialize();
    await _viewModel.initialize();
    _isInitialized = true;
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
    _viewModel.dispose();
    _jsService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JS Interpreter Console'),
        actions: [
          IconButton(
            onPressed: _viewModel.clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Column(
        children: [
          UrlInputSection(viewModel: _viewModel),

          Expanded(
            child: ConsoleOutputSection(
              viewModel: _viewModel,
              scrollController: _scrollController,
            ),
          ),

          CommandInputSection(viewModel: _viewModel),
        ],
      ),
    );
  }
}
