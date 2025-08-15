import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

Future<File> getFileForUrl(String url, [String extension = '']) async {
  final dir = Directory.systemTemp;
  await dir.create(recursive: true);
  final fileHash = sha1.convert(utf8.encode(url)).toString();
  final file = File('${dir.path}/$fileHash$extension');
  if (file.existsSync()) {
    await file.delete();
  }
  await file.create(recursive: true);
  return file;
}

Future<File> readResponseToFile(
  http.StreamedResponse response, {
  String extension = '',
}) async {
  final logger = Logger('readResponseToFile');

  final request = response.request;
  if (request == null) {
    throw Exception('request is null');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('response status code is not 2xx');
  }
  final file = await getFileForUrl(request.url.toString(), extension);

  final sink = file.openWrite(mode: FileMode.writeOnlyAppend);

  bool isFileClosed = false;

  try {
    final doneCompleter = Completer<void>();

    response.stream.listen(
      sink.add,
      onError: (e, s) {
        isFileClosed = false;
        doneCompleter.completeError(e, s);
        sink.close();
      },
      onDone: () async {
        try {
          await sink.flush();
          await sink.close();
          isFileClosed = true;
          doneCompleter.complete();
        } catch (e, s) {
          logger.severe('Error flushing file', e, s);
          doneCompleter.completeError(e, s);
        }
      },
      cancelOnError: true,
    );

    await doneCompleter.future;
  } catch (e, s) {
    logger.severe('Error downloading file', e, s);
    rethrow;
  } finally {
    try {
      if (!isFileClosed) {
        await sink.close();
      }
    } catch (e, s) {
      logger.severe('Error closing file', e, s);
    }
  }

  return file;
}

final _client = http.Client();

Future<File> downloadFromUrl(String url, {String extension = ''}) async {
  final response = await _client.send(http.Request('GET', Uri.parse(url)));
  final file = await readResponseToFile(response, extension: extension);

  return file;
}
