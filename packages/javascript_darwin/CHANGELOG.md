## 2.1.0

- `runJavaScriptReturningResult` and `runJavaScriptFromFileReturningResult` now follow the string-only result contract shared with Android: a string result (or a string a Promise resolves to) is returned verbatim, and any non-string value (number, boolean, null, undefined, object, ...) resolves to an empty string.
- Fix `FormatException` thrown for `NaN`, `Infinity`, `-Infinity`, `1e21` and `2 ** 63` results.
- Fix Promise results being double-encoded (`Promise.resolve("hi")` returned `"\"hi\""`). Only native Promises are awaited (like Android); other thenables resolve to an empty string.
- Fix `undefined`, functions, symbols, bigint and circular objects silently resolving to `null`; they now resolve to an empty string.
- Promise rejection reasons are now surfaced in `JavaScriptDarwinExecutionException` (previously lost as `{}`).
- Scripts whose result string starts with `ERROR:` are no longer mistaken for errors; non-object values can be thrown.
- Channel messages are delivered to `onMessageReceived` exactly as the string passed to `sendMessage`, and `sendMessage` to an unregistered channel throws, like on Android. Non-string `sendMessage` messages throw.
- Disposing an environment while a Promise is pending now throws `JavaScriptEnvironmentClosedException`.
- Remove per-runtime callback registrations and cancel timers on disposal.
- Guard asynchronous replies and Promise polling after context disposal.
- Release temporary JavaScriptCore strings and pointer slots in runtime paths.
- Handle null JSON string references without calling JSStringRelease on null.

# 2.0.0

- Update dependency of `javascript_platform_interface` to version `2.0.0`
- Rename `JavaScriptDarwin.getPlatformEngineInstanceId` to `JavaScriptDarwin.getPlatformEnvironmentInstanceId`
- Fix crash when timer ticks for setTimeout support in javascript_darwin of an instance that has been disposed

# 1.0.1

- Fix state issues with sendChannel when using multiple js runtimes at the same moment
- Fix registry of channels for multiple js runtimes
- Add `getPlatformEngineInstanceId` to `JavaScriptDarwin` for fetching the underlying engine's instance identifier
- Handle `JsEvalResult` to be re-thrown wrapped with `JavaScriptDarwinExecutionException`

# 1.0.0+1

- Update name of main package from `javascript` to `javascript_flutter`

# 1.0.0

- Initial release
