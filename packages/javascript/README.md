# JavaScript Flutter

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment for your flutter apps where you can run your javascript code.

## Advantages

For applications requiring non-interactive JavaScript evaluation, using this JavaScript library has the following advantages:

- **Lower resource consumption**, since there is no need to allocate a WebView instance.
- **Multiple** isolated javascript environments with **low overhead**, enabling the application to run several JavaScript snippets simultaneously.
- Provides implementation for setTimeout in the javascript environment.
- Support for **javascript channels** for sending asynchronous messages from javascript environment to host and then receive a reply asynchronously as Promise.
- Supports loading javaScript code from a file and then evaluate it for **efficient evaluation of large scripts** that may be expensive to pass as a String.
- **Minimal** contribution to your compiled **application size** on Android, MacOS, and iOS. This package, by using [javascript_android](#android) and [javascript_darwin](#iosmacos), leverages the system's built-in JavaScript execution environment rather than embedding a separate runtime library. Adds approximately **~0.1 MB** to your Android App and **~0.55 MB** on iOS/MacOS applications. 

## Implementation

### Android

The Android plugin [javascript_android](https://pub.dev/packages/javascript_android) depends on [Android Jetpack JavaScript Engine](https://developer.android.com/reference/kotlin/androidx/javascriptengine) library for its [JavaScriptIsolate](https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptIsolate) API.

The implementation uses method channel for communication generated with [pub.dev:pigeon](https://pub.dev/packages/pigeon) library.

### iOS/MacOS

The iOS, & MacOS plugin [javascript_darwin](https://pub.dev/packages/javascript_darwin) depends on [Apple's JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) framework for its [JSContext](https://developer.apple.com/documentation/javascriptcore/jscontext) API.

The implementation uses FFI for communication, taken from [pub.dev:flutter_js](https://pub.dev/packages/flutter_js), and [pub.dev:flutter_jscore](https://pub.dev/packages/flutter_jscore) flutter packages (With some additional improvements).

## Using

The easiest way to use this library is via the high-level interface defined by [JavaScript] class.

```dart
import 'dart:convert';

import 'package:javascript_flutter/javascript_flutter.dart';

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

Checkout a larger example that is using this package in a JS Interpreter UI here: [JavaScript Package Example](https://github.com/predatorx7/javascript_flutter/tree/main/packages/javascript/example).

## API Reference

### JavaScript Class

The `JavaScript` class represents a connection to an isolated JavaScript environment where code can be evaluated. Each instance has its own isolated state and cannot interact with other instances.

#### Creating a JavaScript Instance

##### `JavaScript.createNew({JavaScriptPlatform? platform})`

Creates and returns a new `JavaScript` instance.

**Parameters:**
- `platform` (optional): A `JavaScriptPlatform` instance that manages the underlying JavaScript environment. If not provided, the default platform is used.

**Returns:** `Future<JavaScript>`

**Example:**
```dart
// Create with default platform
final javascript = await JavaScript.createNew();

// Create with custom platform
final customPlatform = MyCustomJavaScriptPlatform();
final javascript = await JavaScript.createNew(platform: customPlatform);
```

#### JavaScript Instance Properties

##### `instanceId`

The unique identifier of the JavaScript instance.

**Type:** `String`

**Example:**
```dart
final javascript = await JavaScript.createNew();
print(javascript.instanceId); // e.g., "123456789"
```

##### `isFunctional`

Whether the JavaScript instance is functional and can be used.

**Type:** `bool`

A JavaScript instance is functional if it is available and can be used. Any further operations on a non-functional JavaScript instance that has become defunct will throw a `JavaScriptUnavailablePlatformException`.

**Example:**
```dart
final javascript = await JavaScript.createNew();
print(javascript.isFunctional); // true

// After disposal or if the instance becomes unavailable
await javascript.dispose();
print(javascript.isFunctional); // false
```

##### `unavailableReason`

The reason why the JavaScript instance is not functional.

**Type:** `Object?`

If the JavaScript instance is functional, this will be `null`. If the JavaScript instance is not functional, this will be an exception, likely a `JavaScriptUnavailablePlatformException`, which made the instance non-functional.

**Example:**
```dart
final javascript = await JavaScript.createNew();

if (!javascript.isFunctional) {
  print('JavaScript instance is not functional: ${javascript.unavailableReason}');
}

// After disposal
await javascript.dispose();
if (javascript.unavailableReason != null) {
  print('Instance became unavailable due to: ${javascript.unavailableReason}');
}
```

##### `platform`

The platform that is used to control the underlying JavaScript environment.

**Type:** `JavaScriptPlatform`

**Example:**
```dart
final javascript = await JavaScript.createNew();
print(javascript.platform); // The platform instance being used
```

#### JavaScript Code Execution

##### `runJavaScriptReturningResult(String javaScript)`

Evaluates the given JavaScript code in the context of the current JavaScript instance and returns the result.

**Parameters:**
- `javaScript`: The JavaScript code to evaluate

**Returns:** `Future<Object?>` - The result of the JavaScript evaluation

**Behavior:**
The method has specific behavior based on the output of the JavaScript expression:

1. **JSON String or Promise of JSON String**: Returns a `Map`, `List`, `String`, `num`, `bool`, or `null` if the string can be decoded as JSON, otherwise returns the string.
2. **Other Data Types**: Returns an empty `String` on some platforms.
3. **JavaScript Error**: The Future completes with an error.

Global variables set by one evaluation are visible for later evaluations, similar to adding multiple `<script>` tags in HTML.

**Examples:**
```dart
// Simple expression
final result1 = await javascript.runJavaScriptReturningResult('2 + 2');
print(result1); // 4

// JSON object
final result2 = await javascript.runJavaScriptReturningResult('''
  JSON.stringify({name: "John", age: 30})
''');
print(result2); // {name: John, age: 30}

// Promise that resolves to JSON
final result3 = await javascript.runJavaScriptReturningResult('''
  Promise.resolve(JSON.stringify([1, 2, 3]))
''');
print(result3); // [1, 2, 3]

// Function with global state
await javascript.runJavaScriptReturningResult('let counter = 0;');
final result4 = await javascript.runJavaScriptReturningResult('++counter');
print(result4); // 1

// Error handling
try {
  await javascript.runJavaScriptReturningResult('undefined.nonExistentMethod()');
} catch (e) {
  print('JavaScript error: $e');
}
```

##### `runJavaScriptFromFileReturningResult(String javaScriptFilePath)`

Loads the content of a file from the given path and evaluates it as JavaScript code in the context of the current JavaScript instance.

**Parameters:**
- `javaScriptFilePath`: Path to the JavaScript file to load and evaluate

**Returns:** `Future<Object?>` - The result of the JavaScript evaluation

**Behavior:**
Same behavior as `runJavaScriptReturningResult()` but loads code from a file instead of a string. This is more efficient for large scripts that would be expensive to pass as strings.

**Example:**
```dart
// Load and execute a JavaScript file
final result = await javascript.runJavaScriptFromFileReturningResult(
  'assets/scripts/calculator.js'
);
print(result);
```

#### JavaScript Channel Management

##### `addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams)`

Adds a new JavaScript channel to the set of enabled channels for the current JavaScript instance.

JavaScript code can then call `sendMessage('channelName', JSON.stringify(data))` to send a message that will be passed to the `onMessageReceived` callback, and a reply will be sent back to the JavaScript code as a Promise. Calling this function more than once with the same `JavaScriptChannelParams.name` will remove the previously set `JavaScriptChannelParams`.

**Parameters:**
- `javaScriptChannelParams`: Configuration for the JavaScript channel including name and message handler

**Returns:** `Future<void>`

**Example:**
```dart
await javascript.addJavaScriptChannel(
  JavaScriptChannelParams(
    name: 'Calculator',
    onMessageReceived: (message) {
      final data = json.decode(message.message!);
      final result = data['operation'] == 'add' 
          ? data['a'] + data['b'] 
          : data['a'] - data['b'];
      return JavaScriptReply(message: json.encode(result));
    },
  ),
);

// In JavaScript:
// sendMessage('Calculator', JSON.stringify({operation: 'add', a: 5, b: 3}))
//   .then(result => JSON.parse(result)) // Returns 8
```

##### `removeJavaScriptChannel(String javaScriptChannelName)`

Removes the JavaScript channel with the matching name from the set of enabled channels.

**Parameters:**
- `javaScriptChannelName`: The name of the channel to remove

**Returns:** `Future<void>`

**Example:**
```dart
await javascript.addJavaScriptChannel(
  JavaScriptChannelParams(name: 'TempChannel', onMessageReceived: (m) => null),
);
// ... use the channel
await javascript.removeJavaScriptChannel('TempChannel'); // Remove the channel
```

#### Core methods

##### `dispose()`

Disposes of the underlying JavaScript environment and frees up resources.

**Returns:** `Future<void>`

**Example:**
```dart
final javascript = await JavaScript.createNew();
// ... use the javascript instance
await javascript.dispose(); // Clean up resources
```

##### `setIsInspectable(bool isInspectable)`

Sets whether the underlying JavaScript environment is inspectable. This is only applicable to some runtime engines. Right now only supported on iOS/MacOS when using [javascript_darwin](https://pub.dev/packages/javascript_darwin) to inspect the JavaScript context with Safari Web Inspector.

**Parameters:**
- `isInspectable`: Whether the JavaScript environment should be inspectable

**Returns:** `Future<void>`

**Example:**
```dart
final javascript = await JavaScript.createNew();
await javascript.setIsInspectable(true); // Enable inspection for debugging
```

### JavaScriptChannelParams Class

Configuration class for JavaScript channels.

**Properties:**
- `name`: The name of the channel (required)
- `onMessageReceived`: Callback function that handles incoming messages from JavaScript

**Example:**
```dart
JavaScriptChannelParams(
  name: 'MyChannel',
  onMessageReceived: (message) {
    // Process the message from JavaScript
    final data = json.decode(message.message!);
    
    // Return a reply that will be sent back to JavaScript
    return JavaScriptReply(message: json.encode({'status': 'success'}));
  },
)
```

### JavaScriptReply Class

Represents a reply to be sent back to JavaScript code.

**Properties:**
- `message`: The message content to send back to JavaScript

**Example:**
```dart
JavaScriptReply(message: json.encode({'result': 42}))
```

### Error Handling

JavaScript errors are propagated as Dart exceptions. Always wrap JavaScript execution in try-catch blocks:

```dart
try {
  final result = await javascript.runJavaScriptReturningResult('''
    // This will throw a JavaScript error
    const obj = null;
    obj.someMethod();
  ''');
} on JavaScriptPlatformException catch (e) {
  print('JavaScript platform error: $e');
} catch (e) {
  print('JavaScript unknown error: $e');
}
```

#### JavaScriptUnavailablePlatformException

This exception is thrown when a JavaScript instance becomes unavailable (e.g., due to crashing or being disposed) and you attempt to perform operations on it.

**When it occurs:**
- When calling methods on a disposed JavaScript instance
- When the underlying JavaScript environment crashes
- When the JavaScript instance becomes defunct for any reason

**Example:**
```dart
final javascript = await JavaScript.createNew();
await javascript.dispose();

try {
  // This will throw JavaScriptUnavailablePlatformException
  await javascript.runJavaScriptReturningResult('console.log("hello")');
} catch (e) {
  if (e is JavaScriptUnavailablePlatformException) {
    print('JavaScript instance is no longer available: $e');
  }
}

// Check if instance is functional before using it
if (javascript.isFunctional) {
  await javascript.runJavaScriptReturningResult('console.log("hello")');
} else {
  print('Instance is not functional: ${javascript.unavailableReason}');
}
```

### Best Practices

1. **Always dispose**: Call `dispose()` when you're done with a JavaScript instance to free resources.

2. **Use channels for complex communication**: JavaScript channels provide a clean way to communicate between JavaScript and Dart code.

3. **Handle errors**: Wrap JavaScript execution in try-catch blocks to handle runtime errors gracefully.

4. **Use file loading for large scripts**: Use `runJavaScriptFromFileReturningResult()` for large JavaScript files instead of passing them as strings.

5. **Isolate instances**: Each JavaScript instance is isolated, so you can run multiple independent JavaScript environments simultaneously.

```dart
// Example of multiple isolated instances
final instance1 = await JavaScript.createNew();
final instance2 = await JavaScript.createNew();

// These instances are completely independent
await instance1.runJavaScriptReturningResult('let x = 1;');
await instance2.runJavaScriptReturningResult('let x = 2;');

// Clean up
await instance1.dispose();
await instance2.dispose();
```
