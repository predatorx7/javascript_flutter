# JavaScript Darwin

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

The iOS and macOS implementation of [javascript](https://pub.dev/packages/javascript) which provides access to a JavaScript environment through [JavaScriptDarwin] platform.

## Implementation

The iOS, & MacOS plugin [javascript_darwin](https://pub.dev/packages/javascript_darwin) depends on [Apple's JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) framework for its [JSContext](https://developer.apple.com/documentation/javascriptcore/jscontext) API.

The implementation uses FFI for communication, taken from [pub.dev:flutter_js](https://pub.dev/packages/flutter_js), and [pub.dev:flutter_jscore](https://pub.dev/packages/flutter_jscore) flutter packages.

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin), which means you can simply use [javascript](https://pub.dev/packages/javascript) package normally. This package will be automatically included in your app when you do, so you do not need to add it to your `pubspec.yaml`.

However, if you import this package to use any of its APIs directly, you should add it to your `pubspec.yaml` as usual.
