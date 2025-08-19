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
