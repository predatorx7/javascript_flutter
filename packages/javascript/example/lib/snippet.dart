import 'dart:convert';

import 'package:javascript_flutter/javascript_flutter.dart';

void main() async {
  /// Create a new javascript environment
  final javascript = await JavaScript.createNew();

  /// Add a javascript channel to the environment
  await javascript.addJavaScriptChannel(
    JavaScriptChannelParams(
      name: 'Sum',
      onMessageReceived: (message) {
        final data = json.decode(message.message!);
        return JavaScriptReply(message: json.encode(data['a'] + data['b']));
      },
    ),
  );

  /// Run a javascript program and return the result
  final result = await javascript.runJavaScriptReturningResult('''
    const sum = (a, b) => a + b;

    /// Send a message to the platform and return the result
    const platformSum = (a, b) => sendMessage('Sum', JSON.stringify({a, b})).then(result => JSON.parse(result));

    const addSum = async (a, b) => {
      return sum(a, b) + (await platformSum(a, b));
    }

    /// The result of the last expression (or the value of a returned Promise) is
    /// handed to Dart. It must be a string: use JSON.stringify for anything else.
    /// No return statement should be used at this top level evaluation.
    addSum(1, 2).then(result => JSON.stringify({sum: result}));
  ''');

  /// The result is always a String. Decode it yourself.
  final data = json.decode(result as String) as Map<String, dynamic>;
  print(data['sum']); // 6

  /// Dispose of the javascript environment to clear up resources
  await javascript.dispose();
}
