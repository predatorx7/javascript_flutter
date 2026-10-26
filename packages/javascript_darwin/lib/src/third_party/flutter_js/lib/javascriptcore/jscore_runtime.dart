import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascript_runtime.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/binding/js_object_ref.dart'
    as jsObject;
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/flutter_jscore.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_bindings.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/js_eval_result.dart';

class JavascriptCoreRuntime extends JavascriptRuntime {
  late Pointer _contextGroup;
  late Pointer _globalContext;
  late JSContext context;
  late Pointer _globalObject;

  int executePendingJob() {
    evaluate('(function(){})();');
    return 0;
  }

  String? onMessageFunctionName;
  String? sendMessageFunctionName;

  JavascriptCoreRuntime() {
    _contextGroup = jSContextGroupCreate();
    _globalContext = jSGlobalContextCreateInGroup(_contextGroup, nullptr);
    _globalObject = jSContextGetGlobalObject(_globalContext);

    context = JSContext(_globalContext);

    _sendMessageDartFuncByContext[_globalContext.address] = _sendMessage;
    _engineInstanceIdByContext[_globalContext.address] = getEngineInstanceId();

    Pointer<Utf8> funcNameCString = 'sendMessage'.toNativeUtf8();
    final functionName = jSStringCreateWithUTF8CString(funcNameCString);
    var functionObject = jSObjectMakeFunctionWithCallback(_globalContext,
        functionName, Pointer.fromFunction(sendMessageBridgeFunction));
    jSObjectSetProperty(
        _globalContext,
        _globalObject,
        functionName,
        functionObject,
        jsObject.JSPropertyAttributes.kJSPropertyAttributeNone,
        nullptr);
    calloc.free(funcNameCString);
    jSStringRelease(functionName);

    init();
  }

  @override
  void initChannelFunctions() {
    JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()] = {};
  }

  @override
  JsEvalResult evaluate(String js, {String? sourceUrl}) {
    _checkAlive();
    Pointer<Utf8> scriptCString = js.toNativeUtf8();
    Pointer<Utf8>? sourceUrlCString = sourceUrl?.toNativeUtf8();

    JSValuePointer exception = JSValuePointer();
    final script = jSStringCreateWithUTF8CString(scriptCString);
    final url = sourceUrlCString == null
        ? nullptr
        : jSStringCreateWithUTF8CString(sourceUrlCString);
    var jsValueRef = jSEvaluateScript(
        _globalContext, script, nullptr, url, 1, exception.pointer);
    jSStringRelease(script);
    if (url != nullptr) jSStringRelease(url);
    calloc.free(scriptCString);
    if (sourceUrlCString != null) {
      calloc.free(sourceUrlCString as Pointer<NativeType>);
    }

    String result;

    JSValue exceptionValue = exception.getValue(context);
    // PATCH(javascript_darwin): track whether an exception was thrown instead of
    // inferring it from a result string that starts with 'ERROR:', so scripts
    // may evaluate to any string, and non-object values can be thrown.
    final exceptionRef = exception.pointer.value;
    final hasException = exceptionRef != nullptr;
    malloc.free(exception.pointer);
    bool isPromise = false;
    if (exceptionValue.isObject) {
      result =
          'ERROR: ${exceptionValue.toObject().getProperty("message").string} \n  at ${exceptionValue.toObject().getProperty("stack").string}';
    } else if (hasException) {
      result = 'ERROR: ${_getJsValue(exceptionRef)}';
    } else {
      result = _getJsValue(jsValueRef);
      JSValue resultValue = JSValue(context, jsValueRef);

      isPromise = resultValue.isObject &&
          resultValue.toObject().getProperty('then').isObject &&
          resultValue.toObject().getProperty('catch').isObject;
    }

    return JsEvalResult(
      result,
      exceptionValue.isObject
          ? exceptionValue.toObject().pointer
          : (hasException ? exceptionRef : jsValueRef),
      isError: hasException,
      isPromise: isPromise,
    );
  }

  bool _isDisposed = false;

  void _checkAlive() {
    if (_isDisposed) throw StateError('JavaScript runtime is disposed');
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    releaseDartResources();
    _sendMessageDartFuncByContext.remove(_globalContext.address);
    _engineInstanceIdByContext.remove(_globalContext.address);
    // JSContext allocates this output slot; it does not own the JSValueRef.
    malloc.free(context.exception.pointer);
    jSGlobalContextRelease(_globalContext);
    jSContextGroupRelease(_contextGroup);
  }

  @override
  String getEngineInstanceId() => hashCode.abs().toString();

  /// Works only for iOS & MacOS.
  @override
  void setInspectable(bool inspectable) {
    _checkAlive();
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        context.setInspectable(inspectable);
      } on Error {
        print('Could not set inspectable to $inspectable');
      }
    }
  }

  @override
  bool setupBridge(String channelName, Function(dynamic args) fn) {
    _checkAlive();
    final channelFunctionCallbacks =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    if (channelFunctionCallbacks.keys.contains(channelName)) return false;

    channelFunctionCallbacks[channelName] = fn;

    return true;
  }

  static Pointer sendMessageBridgeFunction(
      Pointer ctx,
      Pointer function,
      Pointer thisObject,
      int argumentCount,
      Pointer<Pointer> arguments,
      Pointer<Pointer> exception) {
    final sendMessageDartFunc = _sendMessageDartFuncByContext[ctx.address];
    if (sendMessageDartFunc != null) {
      return sendMessageDartFunc(
          ctx, function, thisObject, argumentCount, arguments, exception);
    }
    return nullptr;
  }

  String _getJsValue(Pointer jsValueRef) {
    if (jSValueIsNull(_globalContext, jsValueRef) == 1) {
      return 'null';
    } else if (jSValueIsUndefined(_globalContext, jsValueRef) == 1) {
      return 'undefined';
    }
    var resultJsString =
        jSValueToStringCopy(_globalContext, jsValueRef, nullptr);
    if (resultJsString == nullptr) return 'null';
    var resultCString = jSStringGetCharactersPtr(resultJsString);
    int resultCStringLength = jSStringGetLength(resultJsString);
    if (resultCString == nullptr) {
      jSStringRelease(resultJsString);
      return 'null';
    }
    String result = String.fromCharCodes(Uint16List.view(
        resultCString.cast<Uint16>().asTypedList(resultCStringLength).buffer,
        0,
        resultCStringLength));
    jSStringRelease(resultJsString);
    return result;
  }

  static final Map<int, jsObject.JSObjectCallAsFunctionCallbackDart>
      _sendMessageDartFuncByContext = {};
  static final Map<int, String> _engineInstanceIdByContext = {};

  Pointer _sendMessage(
      Pointer ctx,
      Pointer function,
      Pointer thisObject,
      int argumentCount,
      Pointer<Pointer> arguments,
      Pointer<Pointer> exception) {
    if (_isDisposed || argumentCount < 2) return nullptr;
    final channelFunctions =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    String channelName = _getJsValue(arguments[0]);
    String message = _getJsValue(arguments[1]);

    if (channelFunctions.containsKey(channelName)) {
      try {
        final result = channelFunctions[channelName]!.call(jsonDecode(message));
        if (result is Future) {
          return _constructPromiseFor(result);
        }
        final encoded = json.encode(result);
        final string = JSString.fromString(encoded);
        try {
          return jSValueMakeFromJSONString(context.pointer, string.pointer);
        } finally {
          string.release();
        }
      } catch (err) {
        print(
            'Could not encode return value of message on channel $channelName to json... returning null');
      }
    } else {
      print('No channel $channelName registered');
    }

    return nullptr;
  }

  Pointer<NativeType> _constructPromiseFor(Future future) {
    final id = future.hashCode;
    Pointer<Utf8> scriptCString = ('var __JSC_promise_result$id = {};' +
            'new Promise(function(resolve, reject) { __JSC_promise_result$id.resolve = resolve;' +
            ' __JSC_promise_result$id.reject = reject;});')
        .toNativeUtf8();

    final script = jSStringCreateWithUTF8CString(scriptCString);
    var jsValueRef =
        jSEvaluateScript(_globalContext, script, nullptr, nullptr, 1, nullptr);
    calloc.free(scriptCString);
    jSStringRelease(script);

    future.then((value) {
      if (_isDisposed) return;
      final encoded = json.encode(value);
      evaluate(
          '__JSC_promise_result$id.resolve($encoded); __JSC_promise_result$id = null;');
    }).catchError((error) {
      if (_isDisposed) return;
      evaluate(
          '__JSC_promise_result$id.reject(${jsonEncode(error.toString())}); __JSC_promise_result$id = null;');
    });
    return jsValueRef;
  }

  @override
  JsEvalResult callFunction(Pointer<NativeType>? fn, Pointer<NativeType>? obj) {
    _checkAlive();
    JSValue fnValue = JSValue(context, fn ?? nullptr);
    JSObject functionObj = fnValue.toObject();
    JSValuePointer exception = JSValuePointer();
    final arguments = JSValuePointer(obj);
    late final JSValue result;
    late final JSValue exceptionValue;
    try {
      result = functionObj.callAsFunction(
        functionObj,
        arguments,
        exception: exception,
      );
      exceptionValue = exception.getValue(context);
    } finally {
      malloc.free(arguments.pointer);
      malloc.free(exception.pointer);
    }
    bool isPromise = false;

    if (exceptionValue.isObject) {
      throw Exception(
          'ERROR: ${exceptionValue.toObject().getProperty("message").string}');
    } else {
      isPromise = result.isObject &&
          result.toObject().getProperty('then').isObject &&
          result.toObject().getProperty('catch').isObject;
    }

    return JsEvalResult(
      _getJsValue(result.pointer),
      exceptionValue.isObject
          ? exceptionValue.toObject().pointer
          : result.pointer,
      isPromise: isPromise,
    );
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    _checkAlive();
    if (jSValueIsNull(_globalContext, jsValue.rawResult) == 1) {
      return null;
    } else if (jSValueIsString(_globalContext, jsValue.rawResult) == 1) {
      return _getJsValue(jsValue.rawResult) as T;
    } else if (jSValueIsBoolean(_globalContext, jsValue.rawResult) == 1) {
      return (_getJsValue(jsValue.rawResult) == "true") as T;
    } else if (jSValueIsNumber(_globalContext, jsValue.rawResult) == 1) {
      String valueString = _getJsValue(jsValue.rawResult);

      if (valueString.contains(".")) {
        try {
          return double.parse(valueString) as T;
        } on TypeError {
          print('Failed to cast $valueString... returning null');
          return null;
        }
      } else {
        try {
          return int.parse(valueString) as T;
        } on TypeError {
          print('Failed to cast $valueString... returning null');
          return null;
        }
      }
    } else if (jSValueIsObject(_globalContext, jsValue.rawResult) == 1 ||
        jSValueIsArray(_globalContext, jsValue.rawResult) == 1) {
      String serialized = jsonStringify(jsValue);
      return jsonDecode(serialized);
    } else {
      return null;
    }
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    _checkAlive();
    final string =
        jSValueCreateJSONString(context.pointer, jsValue.rawResult, 0, nullptr);
    if (string == nullptr) return 'null';
    try {
      return JSString(string).string!;
    } finally {
      jSStringRelease(string);
    }
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) {
    return Future.value(evaluate(code, sourceUrl: sourceUrl));
  }
}
