package org.reclaimprotocol.javascript_android

import android.util.Log
import androidx.core.content.ContextCompat
import androidx.javascriptengine.IsolateStartupParameters
import androidx.javascriptengine.IsolateTerminatedException
import androidx.javascriptengine.JavaScriptIsolate
import androidx.javascriptengine.JavaScriptSandbox
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executor

class JavaScriptAndroid(private var applicationContext: android.content.Context) :
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

    override fun startJavaScriptEngine(
        javascriptEngineId: String, callback: (Result<Unit>) -> Unit
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
                        val jsIsolate = sandbox.createIsolate(startupParams)
                        activeJsIsolates.put(javascriptEngineId, jsIsolate)
                        callback(Result.success(Unit))
                    }

                    override fun onFailure(t: Throwable) {
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
        javascriptEngineId: String, callback: (Result<Unit>) -> Unit
    ) {
        try {
            val js = requireJsIsolateById(javascriptEngineId)
            js.close()
            activeJsIsolates.remove(javascriptEngineId)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            if (e is IsolateTerminatedException) {
                // its okay
                callback(Result.success(Unit))
            } else {
                callback(Result.failure(e))
            }
        }
    }

    override fun runJavaScriptReturningResult(
        javascriptEngineId: String, javaScript: String, callback: (Result<String?>) -> Unit
    ) {
        try {
            val js = requireJsIsolateById(javascriptEngineId)

            var didSubmitResponse = false

            js.addOnTerminatedCallback(getMainExecutor(), { terminationInfo ->
                Log.e(TAG, "The isolate crashed: $terminationInfo")
                if (!didSubmitResponse) {
                    didSubmitResponse = true
                    callback(Result.failure(IsolateTerminatedException(terminationInfo.toString())))
                }
                activeJsIsolates.remove(javascriptEngineId)
            })

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

    override fun setIsInspectable(
        javascriptEngineId: String, isInspectable: Boolean, callback: (Result<Unit>) -> Unit
    ) {
        try {
            requireJsIsolateById(javascriptEngineId)
            // unsupported
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

}