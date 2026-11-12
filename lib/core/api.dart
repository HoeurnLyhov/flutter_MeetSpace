import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  final int status;
  final String message;
  final Json errors;
  const ApiFailure(this.status, this.message, [this.errors = const {}]);
  @override
  String toString() => message;
}

class Upload {
  final String name;
  final Uint8List bytes;
  const Upload(this.name, this.bytes);
}

class Api {
  final http.Client client;
  final String baseUrl;
  String? token;
  void Function()? onUnauthorized;
  Api({http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:8000/api/v1',
                  ))
              .replaceFirst(RegExp(r'/$'), '');

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    Json? query,
    List<Upload> files = const [],
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));
    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      http.BaseRequest req;
      if (files.isNotEmpty) {
        final multipart = http.MultipartRequest('POST', uri);
        if (method != 'POST') multipart.fields['_method'] = method;
        for (final entry in (body ?? {}).entries) {
          if (entry.value is List) {
            for (var i = 0; i < (entry.value as List).length; i++) {
              multipart.fields['${entry.key}[$i]'] = '${entry.value[i]}';
            }
          } else {
            multipart.fields[entry.key] = entry.value is bool
                ? (entry.value ? '1' : '0')
                : '${entry.value}';
          }
        }
        multipart.files.addAll(
          files.map(
            (f) => http.MultipartFile.fromBytes(
              'attachments[]',
              f.bytes,
              filename: f.name,
            ),
          ),
        );
        req = multipart;
      } else {
        final plain = http.Request(method, uri);
        if (body != null) {
          plain.headers['Content-Type'] = 'application/json';
          plain.body = jsonEncode(body);
        }
        req = plain;
      }
      req.headers.addAll(headers);
      final response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));
      Json data;
      try {
        data = jsonDecode(response.body) as Json;
      } catch (_) {
        throw ApiFailure(response.statusCode, 'invalidResponse');
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && token != null) onUnauthorized?.call();
        throw ApiFailure(
          response.statusCode,
          data['message']?.toString() ?? 'unexpected',
          (data['errors'] as Json?) ?? {},
        );
      }
      return data;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(0, 'timeout');
    } on http.ClientException {
      throw const ApiFailure(0, 'offline');
    }
  }

  Future<Uint8List> download(String path) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Accept': 'application/octet-stream',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401) onUnauthorized?.call();
      if (response.statusCode != 200) {
        throw ApiFailure(response.statusCode, 'downloadFailed');
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiFailure(0, 'timeout');
    } on http.ClientException {
      throw const ApiFailure(0, 'offline');
    }
  }
}

List<Json> rows(Json response) =>
    (response['data'] as List? ?? []).cast<Json>();
