# JavaScript Interpreter Example

This example demonstrates a complete JavaScript interpreter console built with Flutter using the [`javascript`](https://pub.dev/packages/javascript) package. It showcases how to create an interactive JavaScript environment within a Flutter application.

## Features

- **Interactive JavaScript Console**: A command-line interface for executing JavaScript code
- **Real-time Output Display**: Shows execution results, errors, and console output
- **File Loading**: Ability to load and execute JavaScript files from URLs
- **Modern UI**: Dark theme console interface with syntax highlighting
- **Error Handling**: Comprehensive error display and logging

## What It Demonstrates

This example shows how to:

- Initialize and manage JavaScript runtime environments
- Create a user-friendly interface for JavaScript code execution
- Handle asynchronous JavaScript operations and promises
- Display formatted output and error messages
- Load external JavaScript files from the web
- Implement proper resource management and cleanup

## Getting Started

1. Ensure you have Flutter installed and set up
2. Run `flutter pub get` to install dependencies
3. Launch the example with `flutter run`

The app provides a console-like interface where you can type JavaScript code and see the results immediately. You can also load JavaScript files from URLs to execute larger scripts.

## Architecture

The example follows a clean architecture pattern with:
- **UI Layer**: Flutter widgets for the console interface
- **Service Layer**: JavaScript runtime management
- **Model Layer**: Data structures and state management

This demonstrates best practices for integrating the `javascript` package into a production-ready Flutter application.
