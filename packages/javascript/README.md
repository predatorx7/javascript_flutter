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
