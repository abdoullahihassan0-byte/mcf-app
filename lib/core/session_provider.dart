import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import '../models/user.dart';

/// Adapte selon ton environnement :
/// - emulateur Android : http://10.0.2.2:3000
/// - simulateur iOS : http://localhost:3000
/// - device physique : http://<IP-locale-de-ton-backend>:3000
/// - production : ton domaine avec HTTPS
const String kBaseUrl = 'http://10.0.2.2:3000';

const _storage = FlutterSecureStorage();
const _tokenKey = 'mcf_jwt_token';

class SessionState {
  SessionState({this.user, this.token});
  final AppUser? user;
  final String? token;

  bool get isAuthenticated => user != null && token != null;
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState()) {
    _restoreSession();
  }

  final _api = ApiClient(baseUrl: kBaseUrl);

  Future<void> _restoreSession() async {
    final savedToken = await _storage.read(key: _tokenKey);
    if (savedToken != null) {
      _api.token = savedToken;
      state = SessionState(token: savedToken);
    }
  }

  Future<bool> requestOtp({required String phoneNumber}) async {
    final response = await _api.post('/auth/otp/request', {'phoneNumber': phoneNumber});
    return response['isNewUser'] as bool? ?? false;
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String code,
    String? fullName,
  }) async {
    final response = await _api.post('/auth/otp/verify', {
      'phoneNumber': phoneNumber,
      'code': code,
      if (fullName != null) 'fullName': fullName,
    });
    await _persistSession(response);
  }

  Future<void> _persistSession(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    final user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: token);
    _api.token = token;
    state = SessionState(user: user, token: token);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    _api.token = null;
    state = SessionState();
  }

  ApiClient get apiClient => _api;
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(),
);
