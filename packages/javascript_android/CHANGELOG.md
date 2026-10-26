## 2.2.0

### BREAKING BEHAVIOR CHANGE: results are no longer auto-JSON-decoded

`runJavaScriptReturningResult` and `runJavaScriptFromFileReturningResult` now return what the JavaScript engine gives back as a Dart `String`, exactly as-is. Nothing is parsed or coerced anymore.

- A script that evaluates to the JS string `"42"` now returns the Dart `String` `'42'`, not the `int` `42`.
- `'{"a":1}'` now returns the JSON text, not a `Map`. Likewise `'true'`, `'null'` and `'[1,2]'` stay strings.
- Callers that relied on the old decoding must call `jsonDecode` themselves.

### Fixes

- Fix [#11](https://github.com/predatorx7/javascript_flutter/issues/11): the old heuristic decoding produced inconsistent types and differed from the other platforms. Results that are not JS strings (numbers, booleans, `null`, objects, ...) are documented as returning an empty string on both Android and Darwin. Use `JSON.stringify(...)` in the script to return structured data. A Promise is awaited and its resolved string is returned when the WebView supports `JS_FEATURE_PROMISE_RETURN`; otherwise it evaluates to an empty string.
- Removing a channel now also removes it from the JavaScript environment: `sendMessage` on a removed channel throws, and sends already in flight are rejected with an error instead of never resolving.
- A `null` reply message resolves the JavaScript promise with `null` (it used to be the string `"null"`).
- Message ids are unique across channels, so a late reply for a removed channel can no longer resolve a message of a re-added channel.
- A failed environment start now disposes the native isolate and message port instead of leaking them.

### Features

- Channel messaging (`sendMessage` in JavaScript, replies from Dart, and the internal `setTimeout` support) now uses `androidx.javascriptengine` message ports (`JS_FEATURE_MESSAGE_PORTS`, `androidx.javascriptengine:javascriptengine:1.1.1`). Message bodies are delivered verbatim in one hop, with no console truncation and no follow-up fetch.
- Transport selection order is message ports, then the console messaging hack (`JS_FEATURE_CONSOLE_MESSAGING`), then timer polling. The chosen transport is logged to logcat under the `JavaScriptAndroid` tag.
- A warning is logged when the WebView lacks `JS_FEATURE_PROMISE_RETURN`: Promises then evaluate to an empty string.
- Requires Flutter 3.44 or newer and Java 17 for the Android build.
- `minSdk` remains 26 (required by `androidx.javascriptengine`).

### Testing hooks

- `JavaScriptAndroid.debugDisabledTransports` (`@visibleForTesting`) skips transports during selection so fallbacks can be exercised on a capable device.
- `JavaScriptAndroid.debugTransportFor(instanceId)` (`@visibleForTesting`) returns the `JavaScriptAndroidMessagingTransport` selected for an instance.

# 2.1.0

- For improving performance, add a hack to use console messaging as a more efficient way to receive independent javascript channel messages from JavaScript environment

# 2.0.0

- Update dependency of `javascript_platform_interface` to version `2.0.0`
- Add javascript exceptions for getting more details when an error occurs while using the javascript environment
- Fix [#5](https://github.com/predatorx7/javascript_flutter/issues/5) creation of javascript environment with new JavaScriptSandbox when a JavaScriptSandbox dies because of SandboxDeadException

# 1.0.0+1

- Update name of main package from `javascript` to `javascript_flutter`

# 1.0.0

- Initial release
