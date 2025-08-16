# JavaScript Android

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

The Android implementation of [javascript_flutter](https://pub.dev/packages/javascript_flutter) which provides access to a JavaScript environment through [JavaScriptAndroid] platform.

## Implementation

The Android plugin [javascript_android](https://pub.dev/packages/javascript_android) depends on [Android Jetpack JavaScript Engine](https://developer.android.com/reference/kotlin/androidx/javascriptengine) library for its [JavaScriptIsolate](https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptIsolate) API.

The implementation uses method channel for communication generated with [pub.dev:pigeon](https://pub.dev/packages/pigeon) library.

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin), which means you can simply use [javascript_flutter](https://pub.dev/packages/javascript_flutter) package normally. This package will be automatically included in your app when you do, so you do not need to add it to your `pubspec.yaml`.

However, if you import this package to use any of its APIs directly, you should add it to your `pubspec.yaml` as usual.
