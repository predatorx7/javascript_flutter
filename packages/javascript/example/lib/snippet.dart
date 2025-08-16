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
    const platformSum = (a, b) => sendMessage('Sum', JSON.stringify({a: 1, b: 2})).then(result => JSON.parse(result));

    const addSum = async (a, b) => {
      return sum(a, b) + (await platformSum(a, b));
    }

    /// Return the result as a string or a promise of a string.
    /// No return statement should be used at this top level evaluation.
    addSum(1, 2).then(result => result.toString());
  ''');
  print(result);

  /// Dispose of the javascript environment to clear up resources
  await javascript.dispose();
}
