import 'package:flutter/material.dart';

import '../model.dart';

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
                animation: viewModel.inputController,
                builder: (context, child) {
                  if (viewModel.inputController.text.isEmpty) {
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
