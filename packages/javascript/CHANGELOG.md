# 1.3.0

Fixes [#11](https://github.com/predatorx7/javascript_flutter/issues/11).

**Behavior change: `runJavaScriptReturningResult` and `runJavaScriptFromFileReturningResult` now follow one string-in, string-out contract on every platform.**

- The value the script evaluates to (its completion value, i.e. the last expression statement; no top level `return`), or the value a returned `Promise` resolves to, is returned to Dart as a `String` exactly as-is. There is no automatic JSON decoding, number or boolean parsing, or type detection. `""` is `""`.
- If that value is not a JavaScript string (number, boolean, `null`, `undefined`, object, array, bigint, function, `NaN`, `Infinity`, a script ending in a declaration, an empty script, ...) the `Future` resolves to the empty string `''` on every platform.
- Promises are awaited (on Android this needs a WebView with `JS_FEATURE_PROMISE_RETURN`; WebViews without it resolve a Promise result to `''`). A rejected promise, a thrown error, or a parse failure throws a `JavaScriptExecutionException` carrying the rejection reason or the JavaScript error message.
- The declared return type stays `Future<Object?>` for API compatibility; it always resolves to a `String` and may be narrowed to `Future<String>` in a future major version.
- Channels: `sendMessage(channelName, message)` takes a string and the Dart handler receives it verbatim in `JavaScriptMessage.message`; `JavaScriptReply.message` is delivered to JavaScript verbatim as the promise's resolved string; calling `sendMessage` with an unregistered channel name throws in JavaScript.

**What changed and how to migrate**

- Previously Android auto-decoded results: the JS string `"42"` became Dart `int 42`, `"true"` became a `bool`, and `'{"a":1}'` became a `Map`. Darwin returned typed values for numbers, booleans and objects and double-encoded promise results. Now both platforms return the string verbatim and non-strings become `''`.
- Where you relied on auto-decoding, wrap the result with `jsonDecode(result as String)`.
- Where you relied on typed results, end your script with `JSON.stringify(...)` and decode it with `jsonDecode` in Dart.
- Root cause of #11: Android's `androidx.javascriptengine` `evaluateJavaScriptAsync` only returns strings and coerces every other type to `""`, which the plugin passed through, while Darwin had its own inconsistent typed conversion.

**Other changes**

- Android now uses message ports for channel communication (see `javascript_android` 2.2.0).
- Modernized toolchain and CI. Requires Flutter 3.44 or newer; Android requires `minSdk` 26 and builds with Java 17.
- `JavaScriptReply(message: null)` resolves the JavaScript promise with `null` on both platforms (Android previously delivered the string `"null"`), and passing a non-string to `sendMessage` throws on both platforms.
- Update dependency of `javascript_platform_interface` to `^2.1.0`, `javascript_android` to `^2.2.0`, and `javascript_darwin` to `^2.1.0`.
- Add unit tests for the public `JavaScript` API.

# 1.2.0

- Deprecate `engineId` and introduce `instanceId` as an alternative
- Update dependency of `javascript_platform_interface`, `javascript_darwin`, and `javascript_android` to version `2.0.0`
- Add `bool get isFunctional` to `JavaScript` for checking whether the `JavaScript` instance is functional and can be used
- Add `bool get unavailableReason` to `JavaScript` for check the reason for `JavaScript` instance's unavailability
- Throw a [JavaScriptUnavailablePlatformException] when `JavaScript` instance becomes unavailable in cases such as crashing or getting disposed

# 1.1.0

- Add `engineId`, and `platform` to `JavaScript` class

# 1.0.0+1

- Update name of main package from `javascript` to `javascript_flutter`

# 1.0.0

- Initial release
