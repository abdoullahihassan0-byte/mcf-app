import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralise les appels au backend MCF.
/// Adapte [baseUrl] selon ton environnement (emulateur Android : 10.0.2.2,
/// device physique : IP locale de ton backend, prod : ton domaine).
class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    final decoded = _decode(response);
    return decoded as Map<String, dynamic>;
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    final decoded = _decode(response);
    return decoded as List<dynamic>;
  }

  dynamic _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error']?.toString() ?? 'Erreur inconnue')
          : 'Erreur inconnue';
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    return decoded;
  }
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
