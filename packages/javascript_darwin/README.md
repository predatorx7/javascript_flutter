# JavaScript Darwin

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

A MacOS/iOS Flutter plugin that provides access to a JavaScript environment through [JavaScriptDarwin] platform.

The iOS, & MacOS plugin [javascript_darwin] depends on [Apple's JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) framework for its [JSContext](https://developer.apple.com/documentation/javascriptcore/jscontext) API.

The implementation uses FFI for communication, taken from [pub.dev:flutter_js](https://pub.dev/packages/flutter_js), and [pub.dev:flutter_jscore](https://pub.dev/packages/flutter_jscore) flutter packages.
