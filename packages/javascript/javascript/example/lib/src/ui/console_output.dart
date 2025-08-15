import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javascript_example/src/model.dart';

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
