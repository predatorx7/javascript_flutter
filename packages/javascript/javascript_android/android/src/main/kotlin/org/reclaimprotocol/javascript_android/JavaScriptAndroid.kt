package org.reclaimprotocol.javascript_android

import android.util.Log
import androidx.core.content.ContextCompat
import androidx.javascriptengine.IsolateStartupParameters
import androidx.javascriptengine.IsolateTerminatedException
import androidx.javascriptengine.JavaScriptException
import androidx.javascriptengine.JavaScriptIsolate
import androidx.javascriptengine.JavaScriptSandbox
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.TimeUnit


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

    override fun startJavaScriptEngine(
        javascriptEngineId: String, callback: (Result<Unit>) -> Unit
    ) {
        try {
            val sandboxFuture = getJSSandbox()
            val executor = ContextCompat.getMainExecutor(applicationContext)
            Futures.transform(sandboxFuture, { sandbox ->
                val startupParams = IsolateStartupParameters()
                if (sandbox.isFeatureSupported(JavaScriptSandbox.JS_FEATURE_ISOLATE_MAX_HEAP_SIZE)) {
                    startupParams.setMaxHeapSizeBytes(100000000)
                }
                val jsIsolate = sandbox.createIsolate(startupParams)
                activeJsIsolates.put(javascriptEngineId, jsIsolate)
                callback(Result.success(Unit))
            }, executor)
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
        javascriptEngineId: String, javaScript: String, callback: (Result<Any?>) -> Unit
    ) {
        try {
            val js = requireJsIsolateById(javascriptEngineId)

            val result = js.evaluateJavaScriptAsync(javaScript).get(10, TimeUnit.MINUTES)

            Log.i("JavaScriptAndroid", "result: $result")
            callback(Result.success(result))
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