import 'package:http/http.dart' as http;
import 'package:javascript/javascript.dart';
import 'package:logging/logging.dart';

import 'file.dart';

class JsRuntimeService {
  final _log = Logger('JsRuntimeService');

  late JavaScript _jsRuntime;
  late http.Client _httpClient;

  Future<void> initialize() async {
    _jsRuntime = await JavaScript.createNew();
    _httpClient = http.Client();
  }

  Future<Object?> evaluate(String source) {
    return _jsRuntime.runJavaScriptReturningResult(source);
  }

  Future<Object?> loadJsFromUrlAndEvaluate(String url) async {
    final file = await downloadFromUrl(url);

    return _jsRuntime.runJavaScriptFromFileReturningResult(file.absolute.path);
  }

  void dispose() {
    _httpClient.close();
    _jsRuntime.dispose();
  }

  Future<void> useJsRuntime(Future<void> Function(JavaScript) onEngine) async {
    try {
      return await onEngine(_jsRuntime);
    } catch (e, s) {
      _log.severe('Error when running a callback with [useJsRuntime]', e, s);
    }
  }
}
