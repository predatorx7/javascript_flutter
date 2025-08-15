package com.magnificsoftware.javascript_android

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

public class JavaScriptPlugin : FlutterPlugin, ActivityAware {
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

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        //
    }

    override fun onDetachedFromActivityForConfigChanges() {
        //
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        //
    }

    override fun onDetachedFromActivity() {
        Log.i("JavaScriptPlugin", "closing javascript android on detached from activity")
        javaScriptAndroid?.onDetachedFromActivity()
    }

    companion object {
        private const val TAG = "UrlLauncherPlugin"
    }
}