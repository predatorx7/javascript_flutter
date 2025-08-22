package com.magnificsoftware.javascript_android

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

public class JavaScriptPlugin : FlutterPlugin, ActivityAware {
    private var javaScriptAndroid: JavaScriptAndroid? = null
    private var proxyApiRegistrar: ProxyApiRegistrar? = null
    private var pluginBinding: FlutterPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        pluginBinding = binding
        proxyApiRegistrar =
            ProxyApiRegistrar(
                binding.applicationContext,
                binding.binaryMessenger,
            )

        proxyApiRegistrar!!.setUp()

        val api = JavaScriptAndroid(binding.applicationContext, proxyApiRegistrar!!)
        javaScriptAndroid = api
        JavaScriptAndroidPlatformApi.setUp(binding.binaryMessenger, api)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        if (proxyApiRegistrar != null) {
            proxyApiRegistrar!!.tearDown()
            proxyApiRegistrar!!.instanceManager.stopFinalizationListener()
            proxyApiRegistrar = null
        }

        if (javaScriptAndroid == null) {
            Log.wtf(TAG, "Already detached from the engine.")
            return
        }

        JavaScriptAndroidPlatformApi.setUp(binding.binaryMessenger, null)
        javaScriptAndroid = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        proxyApiRegistrar?.setContext(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        if (pluginBinding != null) {
            proxyApiRegistrar?.setContext(pluginBinding!!.applicationContext)
        }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        proxyApiRegistrar?.setContext(binding.activity)
    }

    override fun onDetachedFromActivity() {
        if (pluginBinding != null) {
            proxyApiRegistrar?.setContext(pluginBinding!!.applicationContext);
        }
        Log.i("JavaScriptPlugin", "closing javascript android js sandbox on detached from activity")
        javaScriptAndroid?.cleanUpSandBox()
    }

    companion object {
        private const val TAG = "UrlLauncherPlugin"
    }
}