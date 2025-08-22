package com.magnificsoftware.javascript_android

class JavaScriptAndroidConsoleMessageHandlerProxyApi(pigeonRegistrar: ProxyApiRegistrar) :
    PigeonApiJavaScriptAndroidConsoleMessageHandler(pigeonRegistrar) {
    override fun pigeon_defaultConstructor(): JavaScriptAndroidConsoleMessageHandler {
        return JavaScriptAndroidConsoleMessageHandler(this)
    }

    override val pigeonRegistrar: ProxyApiRegistrar
        get() = super.pigeonRegistrar as ProxyApiRegistrar
}