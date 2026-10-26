package com.magnificsoftware.javascript_android

class JavaScriptAndroidMessagePortHandlerProxyApi(pigeonRegistrar: ProxyApiRegistrar) :
    PigeonApiJavaScriptAndroidMessagePortHandler(pigeonRegistrar) {
    override fun pigeon_defaultConstructor(): JavaScriptAndroidMessagePortHandler {
        return JavaScriptAndroidMessagePortHandler(this)
    }

    override val pigeonRegistrar: ProxyApiRegistrar
        get() = super.pigeonRegistrar as ProxyApiRegistrar
}
