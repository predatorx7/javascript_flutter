package com.magnificsoftware.javascript_android

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger

class ProxyApiRegistrar(private var context: Context, binaryMessenger: BinaryMessenger): MessagesPigeonProxyApiRegistrar(binaryMessenger) {
    override fun getPigeonApiJavaScriptAndroidConsoleMessageHandler(): PigeonApiJavaScriptAndroidConsoleMessageHandler {
        return JavaScriptAndroidConsoleMessageHandlerProxyApi(this)
    }

    fun setContext(context: Context) {
        this.context = context
    }

    // Added to be overridden for tests. The test implementation calls `callback` immediately, instead
    // of waiting for the main thread to run it.
    fun runOnMainThread(runnable: Runnable) {
        if (context is Activity) {
            (context as Activity).runOnUiThread(runnable)
        } else {
            Handler(Looper.getMainLooper()).post(runnable)
        }
    }
}