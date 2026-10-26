package com.magnificsoftware.javascript_android

import androidx.javascriptengine.Message
import androidx.javascriptengine.MessagePortClient

/** Receives string messages that JavaScript posts over the isolate's message port and forwards them to Dart. */
class JavaScriptAndroidMessagePortHandler
    constructor(val api: JavaScriptAndroidMessagePortHandlerProxyApi) : MessagePortClient {

    override fun onMessage(message: Message) {
        if (message.type != Message.TYPE_STRING) return
        onMessage(message.string)
    }

    fun onMessage(message: String) {
        api.pigeonRegistrar
            .runOnMainThread(
                {
                    api.onMessage(this@JavaScriptAndroidMessagePortHandler, message, { reply -> null })
                })
    }
}
