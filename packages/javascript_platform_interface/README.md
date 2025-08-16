# JavaScript Plugin Platform Interface

<p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Enable your app to evaluate javascript programs. A simple library that provides a javascript environment where you can run your javascript code.

A common platform interface for the [javascript_flutter](https://pub.dev/packages/javascript_flutter) plugin.

This interface allows platform-specific implementations of the [javascript_flutter](https://pub.dev/packages/javascript_flutter) plugin, as well as the plugin itself, to ensure they are supporting the same interface.

## Usage

To implement a new platform-specific implementation of [javascript_flutter](https://pub.dev/packages/javascript_flutter), extend `JavaScriptPlatform` with an implementation that performs the platform-specific behavior, and when you register your plugin, set the default `JavaScriptPlatform` by calling `JavaScriptPlatform.instance = MyPlatformPathProvider()`.

## Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface) over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion on why a less-clean interface is preferable to a breaking change.
