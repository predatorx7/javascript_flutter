# 2.1.0

- Document the result contract of `runJavaScriptReturningResult` and `runJavaScriptFromFileReturningResult` (documentation only, no code change):
  - The completion value of the script, or the value a returned `Promise` resolves to, is returned as a `String` exactly as-is, with no JSON decoding or type detection.
  - A value that is not a JavaScript string resolves to the empty string `''` on every platform. Use `JSON.stringify(...)` in JavaScript and `jsonDecode` in Dart for structured data.
  - A rejected promise, a thrown error, or a parse failure completes with a `JavaScriptExecutionException`.
  - The declared type stays `Future<Object?>` but always resolves to a `String`; it may be narrowed to `Future<String>` in a future major version.
- Document that a `null` `JavaScriptReply.message` resolves the JavaScript promise with `null`.
- Document that channel messages (`JavaScriptMessage.message`, `JavaScriptReply.message`) are strings delivered verbatim, and that calling `sendMessage` with an unregistered channel throws in JavaScript.

# 2.0.0

- Add [JavaScriptUnavailablePlatform] as the default JavaScriptPlatform
- Update [JavaScriptPlatform] apis & exceptions to be more technically unambiguous

# 1.1.0

- Adds more exceptions that extend [JavaScriptPlatformException]
- Updates existing [JavaScriptExecutionException] to extend [JavaScriptPlatformException]

# 1.0.0+1

- Update name of main package from `javascript` to `javascript_flutter`

# 1.0.0

- Initial release
