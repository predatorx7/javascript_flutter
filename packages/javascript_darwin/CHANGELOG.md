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
