
import 'dart:convert';
import 'dart:typed_data';

final RegExp _base64 = RegExp(r'^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=|[A-Za-z0-9+\/]{4})$');

/// check if a string is base64 encoded
bool _isBase64(String str) {
  return _base64.hasMatch(str);
}

Object? bytesToBase64Json(Uint8List bytes) {
  final base64String = base64.encode(bytes);
  return {'type': 'uint8array', 'value': base64String};
}

Object? _base64JsonReviver(Object? key, Object? value) {
  if (value is Map) {
    final hasStringKeys = value.keys.every((key) => key is String);
    final hasIntValues = value.values.every((value) => value is int);
    if (hasStringKeys && hasIntValues) {
      final bytes = Uint8List(value.length);
      for (final entry in value.entries) {
        bytes[int.parse(entry.key)] = entry.value as int;
      }
      final base64String = base64.encode(bytes);
      return {'type': 'uint8array', 'value': base64String};
    }
  }
  if (value is String && _isBase64(value)) {
    return {'type': 'uint8array', 'value': value};
  }
  return value;
}

String reformatJsonStringForRPC(String jsonString) {
  return json.encode(json.decode(jsonString, reviver: _base64JsonReviver));
}

Object? replaceBase64Json(Object? value) {
  if (value is Map) {
    if (value['type'] == 'uint8array') {
      return value['value'];
    }
    final newMap = <dynamic, dynamic>{};
    for (final entry in value.entries) {
      newMap[entry.key] = replaceBase64Json(entry.value);
    }
    return newMap;
  }
  if (value is List) {
    final newList = <dynamic>[];
    for (final entry in value) {
      newList.add(replaceBase64Json(entry));
    }
    return newList;
  }

  return value;
}