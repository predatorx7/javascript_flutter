package com.magnificsoftware.javascript_android

import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.javascriptengine.IsolateStartupParameters
import androidx.javascriptengine.IsolateTerminatedException
import androidx.javascriptengine.JavaScriptConsoleCallback
import androidx.javascriptengine.JavaScriptIsolate
import androidx.javascriptengine.JavaScriptSandbox
import androidx.javascriptengine.MemoryLimitExceededException
import androidx.javascriptengine.SandboxDeadException
import androidx.javascriptengine.TerminationInfo
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import java.io.File
import java.util.concurrent.Executor

class JavaScriptAndroid(private var applicationContext: android.content.Context, private var proxyApiRegistrar: ProxyApiRegistrar) :
    JavaScriptAndroidPlatformApi {
    companion object {
        private const val TAG = "JavaScriptAndroid"

        private var sandbox: ListenableFuture<JavaScriptSandbox>? = null
    }

    private fun getJSSandbox(): ListenableFuture<JavaScriptSandbox> {
        val s = sandbox ?: JavaScriptSandbox.createConnectedInstanceAsync(applicationContext)
        sandbox = s
        return s
    }

    private val activeJsIsolates = mutableMapOf<String, JavaScriptIsolate>()

    private fun getMainExecutor(): Executor {
        val executor = ContextCompat.getMainExecutor(applicationContext)
        return executor
    }

    override fun startJavaScriptEnvironment(
        javascriptInstanceId: String, callback: (Result<Unit>) -> Unit
    ) {
        try {
            val sandboxFuture = getJSSandbox()
            Futures.addCallback(
                sandboxFuture, object : FutureCallback<JavaScriptSandbox> {
                    override fun onSuccess(sandbox: JavaScriptSandbox) {
                        val startupParams = IsolateStartupParameters()
                        if (sandbox.isFeatureSupported(JavaScriptSandbox.JS_FEATURE_ISOLATE_MAX_HEAP_SIZE)) {
                            startupParams.setMaxHeapSizeBytes(IsolateStartupParameters.AUTOMATIC_MAX_HEAP_SIZE)
                        }
                        Log.i("JavaScriptAndroid", mapOf(
                            "JS_FEATURE_EVALUATE_WITHOUT_TRANSACTION_LIMIT" to sandbox.isFeatureSupported(JavaScriptSandbox.JS_FEATURE_EVALUATE_WITHOUT_TRANSACTION_LIMIT),
                            "JS_FEATURE_ISOLATE_MAX_HEAP_SIZE" to sandbox.isFeatureSupported(JavaScriptSandbox.JS_FEATURE_ISOLATE_MAX_HEAP_SIZE)
                        ).toString())
                        val jsIsolate = sandbox.createIsolate(startupParams)
                        activeJsIsolates.put(javascriptInstanceId, jsIsolate)
                        callback(Result.success(Unit))

                        // refer: https://developer.android.com/develop/ui/views/layout/webapps/jsengine#handling-sandbox-crashes
                        val  terminationCallback: Consumer<TerminationInfo> = object : Consumer<TerminationInfo> {
                            override fun accept(value: TerminationInfo) {
                                Log.e(TAG, "The isolate crashed: $value")
                                val ex = when (value.status) {
                                    TerminationInfo.STATUS_SANDBOX_DEAD -> SandboxDeadException(this.toString())
                                    TerminationInfo.STATUS_MEMORY_LIMIT_EXCEEDED -> MemoryLimitExceededException(this.toString())
                                    else -> IsolateTerminatedException(this.toString())
                                }
                                cleanUpIfSandboxDead(ex)
                                activeJsIsolates.remove(javascriptInstanceId)
                            }
                        }
                        try {
                            jsIsolate.addOnTerminatedCallback(getMainExecutor(), terminationCallback)
                        } catch (e: IllegalStateException) {
                            Log.w("JavaScriptAndroid", "Failed to add termination callback", e)
                        }
                    }

                    override fun onFailure(t: Throwable) {
                        cleanUpIfSandboxDead(t)
                        callback(Result.failure(t))
                    }
                }, getMainExecutor()
            )
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    fun requireJsIsolateById(javascriptEngineId: String): JavaScriptIsolate {
        val jsIsolate = activeJsIsolates[javascriptEngineId]
        if (jsIsolate == null) {
            throw IllegalStateException("No active isolate with id $javascriptEngineId")
        }
        return jsIsolate
    }

    override fun dispose(
        javascriptInstanceId: String, callback: (Result<Unit>) -> Unit
    ) {
        try {
            val js = requireJsIsolateById(javascriptInstanceId)
            js.close()
            activeJsIsolates.remove(javascriptInstanceId)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            cleanUpIfSandboxDead(e)
            if (e is IsolateTerminatedException) {
                // its okay
                callback(Result.success(Unit))
            } else {
                callback(Result.failure(e))
            }
        }
    }

    override fun runJavaScriptFromFileReturningResult(
        javascriptInstanceId: String,
        javaScriptFilePath: String,
        callback: (Result<String?>) -> Unit
    ) {
        try {
            val javaScriptFile = File(javaScriptFilePath)
            val javascript = javaScriptFile.readText()
            return runJavaScriptReturningResult(javascriptInstanceId, javascript, callback)
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun runJavaScriptReturningResult(
        javascriptInstanceId: String, javaScript: String, callback: (Result<String?>) -> Unit
    ) {
        try {
            val js = requireJsIsolateById(javascriptInstanceId)

            var didSubmitResponse = false

            Futures.addCallback(
                js.evaluateJavaScriptAsync(javaScript), object : FutureCallback<String> {
                    override fun onSuccess(result: String) {
                        if (didSubmitResponse) {
                            Log.i("JavaScriptAndroid", "A response was received when didSubmitResponse is true: $result")
                            return
                        }
                        didSubmitResponse = true
                        callback(Result.success(result))
                    }

                    override fun onFailure(t: Throwable) {
                        cleanUpIfSandboxDead(t)
                        if (didSubmitResponse) {
                            Log.e("JavaScriptAndroid", "An error was received when didSubmitResponse is true", t)
                            return
                        }
                        didSubmitResponse = true
                        callback(Result.failure(t))
                    }
                }, getMainExecutor()
            )
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun setJavaScriptConsoleMessageHandler(
        javascriptInstanceId: String,
        mJavaScriptAndroidConsoleMessageHandlerInstanceIdentifier: Long,
        callback: (Result<Boolean>) -> Unit
    ) {
        try {
            val handler = proxyApiRegistrar.instanceManager.getInstance<JavaScriptAndroidConsoleMessageHandler>(mJavaScriptAndroidConsoleMessageHandlerInstanceIdentifier)
            if (handler == null) {
                return callback(Result.failure(Throwable("No JavaScriptAndroidConsoleMessageHandler found registered by identifier $mJavaScriptAndroidConsoleMessageHandlerInstanceIdentifier")))
            }

            val sandbox = getJSSandbox()

            val js = requireJsIsolateById(javascriptInstanceId)

            var didSubmitResponse = false

            fun onError(t: Throwable) {
                cleanUpIfSandboxDead(t)
                if (didSubmitResponse) {
                    Log.e("JavaScriptAndroid", "An error was received when didSubmitResponse is true", t)
                    return
                }
                didSubmitResponse = true
                callback(Result.failure(t))
            }

            Futures.addCallback(
                sandbox, object : FutureCallback<JavaScriptSandbox> {
                    override fun onSuccess(sandbox: JavaScriptSandbox) {
                        var result = false
                        try {
                            if (sandbox.isFeatureSupported(JavaScriptSandbox.JS_FEATURE_CONSOLE_MESSAGING)) {
                                js.setConsoleCallback(getMainExecutor(), handler)
                                result = true
                            }
                        } catch (e: Throwable) {
                            onError(e)
                            return
                        }
                        if (didSubmitResponse) {
                            Log.i("JavaScriptAndroid", "A response was received when didSubmitResponse is true: $result")
                            return
                        }
                        didSubmitResponse = true
                        callback(Result.success(result))
                    }

                    override fun onFailure(t: Throwable) {
                        onError(t)
                    }
                }, getMainExecutor()
            )
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun setIsInspectable(
        javascriptInstanceId: String, isInspectable: Boolean, callback: (Result<Unit>) -> Unit
    ) {
        try {
            requireJsIsolateById(javascriptInstanceId)
            // unsupported
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    fun cleanUpIfSandboxDead(t: Throwable) {
        if (t is SandboxDeadException) {
            try {
                cleanUpSandBox()
            } catch (e: Exception) {
                Log.e("JavaScriptAndroid", "Failed to clean up sandbox", e)
            }
        }
    }

    fun cleanUpSandBox() {
        if (Companion.sandbox == null) return;
        val sandbox = getJSSandbox()
        Companion.sandbox = null;
        Futures.addCallback(
            sandbox, object : FutureCallback<JavaScriptSandbox> {
                override fun onSuccess(sandbox: JavaScriptSandbox) {
                    Log.i("JavaScriptAndroid", "Closing sandbox")
                    activeJsIsolates.clear()
                    try {
                        sandbox.close()
                    } catch (e: Throwable) {
                        Log.e("JavaScriptAndroid", "Failed to close sandbox", e)
                    }
                }
                override fun onFailure(t: Throwable) {
                    Log.e("JavaScriptAndroid", "Failed to close sandbox", t)
                }
            }, getMainExecutor()
        )
    }
}