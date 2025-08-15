# JavaScript

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

## Advantages

For applications requiring non-interactive JavaScript evaluation, using this JavaScript library has the following advantages:

- Lower resource consumption, since there is no need to allocate a WebView instance.
- Multiple isolated javascript environments with low overhead, enabling the application to run several JavaScript snippets simultaneously.
- Provides implementation for setTimeout in the javascript environment.
- Support for javascript channels for sending asynchronous messages from javascript environment to host and then receive a reply asynchronously as Promise.
- Supports loading javaScript code from a file and then evaluate it for efficient evaluation of large scripts that may be expensive to pass as a String.

## Implementation

### Android

The Android plugin [javascript_android] depends on [Android Jetpack JavaScript Engine](https://developer.android.com/reference/kotlin/androidx/javascriptengine) library for its [JavaScriptIsolate](https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptIsolate) API.

The implementation uses method channel for communication generated with [pub.dev:pigeon](https://pub.dev/packages/pigeon) library.

### iOS/MacOS

The iOS, & MacOS plugin [javascript_darwin] depends on [Apple's JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) framework for its [JSContext](https://developer.apple.com/documentation/javascriptcore/jscontext) API.

The implementation uses FFI for communication, taken from [pub.dev:flutter_js](https://pub.dev/packages/flutter_js), and [pub.dev:flutter_jscore](https://pub.dev/packages/flutter_jscore) flutter packages.

## Using

The easiest way to use this library is via the high-level interface defined by [JavaScript] class.

```dart
import 'dart:convert';

import 'package:javascript/javascript.dart';

void example() async {
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
```