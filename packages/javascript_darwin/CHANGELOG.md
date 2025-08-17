# 1.0.1

- Fix state issues with sendChannel when using multiple js runtimes at the same moment
- Fix registry of channels for multiple js runtimes
- Add `getPlatformEngineInstanceId` to `JavaScriptDarwin` for fetching the underlying engine's instance identifier
- Handle `JsEvalResult` to be re-thrown wrapped with `JavaScriptDarwinExecutionException`

# 1.0.0+1

- Update name of main package from `javascript` to `javascript_flutter`

# 1.0.0

- Initial release
