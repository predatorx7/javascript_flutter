# JavaScript

[![License: UNLICENSED][license_badge]][license_link]

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

The Android plugin [javascript_android] implementation uses the [JavaScriptIsolate](https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptIsolate) as the javascript environment from the [Android Jetpack JavaScript Engine](https://developer.android.com/reference/kotlin/androidx/javascriptengine) library.

### iOS & MacOS

The iOS, & MacOS plugin [javascript_darwin] implementation uses [JSContext](https://developer.apple.com/documentation/javascriptcore/jscontext) from [Apple's JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) framework.

## Using

The easiest way to use this library is via the high-level interface defined by [JavaScript] class.

[license_badge]: https://img.shields.io/badge/license-UNLICENSED-blue.svg
[license_link]: https://opensource.org/license/UNLICENSED
