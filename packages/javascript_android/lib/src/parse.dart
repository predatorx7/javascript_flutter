import 'dart:convert';

Object? parseValue(String? result) {
  if (result == null) return null;
  if (result == 'null') return null;
  if (result == 'true') return true;
  if (result == 'false') return false;
  final numResult = num.tryParse(result);
  if (numResult != null) return numResult;
  try {
    return json.decode(result);
  } catch (_) {
    return result;
  }
}
