package org.reclaimprotocol.javascript_android

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Plugin implementation that uses the new `io.flutter.embedding` package.
 *
 *
 * Instantiate this in an add to app scenario to gracefully handle activity and context changes.
 */
public class JavaScriptPlugin : FlutterPlugin {
    private var javaScriptAndroid: JavaScriptAndroid? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        val api = JavaScriptAndroid(binding.applicationContext)
        javaScriptAndroid = api
        JavaScriptAndroidPlatformApi.setUp(binding.binaryMessenger, api)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        if (javaScriptAndroid == null) {
            Log.wtf(TAG, "Already detached from the engine.")
            return
        }

        JavaScriptAndroidPlatformApi.setUp(binding.binaryMessenger, null)
        javaScriptAndroid = null
    }

    companion object {
        private const val TAG = "UrlLauncherPlugin"
    }
}