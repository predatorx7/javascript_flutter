import 'package:flutter/material.dart';
import 'package:javascript_example/src/model.dart';

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
