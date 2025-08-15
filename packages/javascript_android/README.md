# JavaScript Android

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

An Android Flutter plugin that provides access to a JavaScript environment through [JavaScriptAndroid] platform.

The Android plugin [javascript_android] depends on [Android Jetpack JavaScript Engine](https://developer.android.com/reference/kotlin/androidx/javascriptengine) library for its [JavaScriptIsolate](https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptIsolate) API.

The implementation uses method channel for communication generated with [pub.dev:pigeon](https://pub.dev/packages/pigeon) library.
