package org.reclaimprotocol.javascript_android

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding

/**
 * Plugin implementation that uses the new `io.flutter.embedding` package.
 *
 *
 * Instantiate this in an add to app scenario to gracefully handle activity and context changes.
 */
public class JavaScriptPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPluginBinding) {}

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {}

    companion object {
        private const val TAG = "JavaScriptPlugin"
    }
}