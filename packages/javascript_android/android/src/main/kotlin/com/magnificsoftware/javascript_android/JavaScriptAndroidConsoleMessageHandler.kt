package com.magnificsoftware.javascript_android

import androidx.javascriptengine.JavaScriptConsoleCallback
import org.json.JSONObject


class JavaScriptAndroidConsoleMessageHandler
    /** Creates a [JavaScriptAndroidConsoleMessageHandler] that passes arguments of callback methods to Dart.  */
    constructor(val api: JavaScriptAndroidConsoleMessageHandlerProxyApi): JavaScriptConsoleCallback {

    override fun onConsoleMessage(message: JavaScriptConsoleCallback.ConsoleMessage) {
        val messageJson = JSONObject()
        messageJson.put("level", message.level)
        messageJson.put("message", message.message)
        onMessage(messageJson.toString())
    }

    // Suppressing unused warning as this is invoked from JavaScript class.
    @Suppress("unused")
    fun onMessage(message: String) {
        api.pigeonRegistrar
            .runOnMainThread(
                {
                    api.onMessage(this@JavaScriptAndroidConsoleMessageHandler, message, { reply -> null })
                })
    }
}
