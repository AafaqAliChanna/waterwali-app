import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _token;
  String? _userId;
  String? _name;
  String? _role;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _token != null;
  String? get errorMessage => _errorMessage;

  String? get token => _token;
  String? get userId => _userId;
  String? get name => _name;
  String? get role => _role;
  bool get isCustomer => _role == 'CUSTOMER';
  bool get isDriver => _role == 'DRIVER';

  // Turns a raw exception (server message, or a low-level network
  // exception like SocketException) into something a real user should
  // actually see, instead of leaking "ClientException: Failed to fetch".
  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed to fetch') ||
        lower.contains('connection refused') ||
        lower.contains('clientexception')) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    return raw;
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authData = await _apiService.login(phone, password);
      _token = authData.token;
      _userId = authData.userId;
      _name = authData.name;
      _role = authData.role;
      await _storage.write(key: 'jwt_token', value: _token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String phone, String password, String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authData = await _apiService.register(name, phone, password, role);
      _token = authData.token;
      _userId = authData.userId;
      _name = authData.name;
      _role = authData.role;
      await _storage.write(key: 'jwt_token', value: _token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'jwt_token');
    if (storedToken == null) {
      _isInitializing = false;
      notifyListeners();
      return;
    }
    try {
      final authData = await _apiService.getCurrentUser(storedToken);
      _token = authData.token;
      _userId = authData.userId;
      _name = authData.name;
      _role = authData.role;
    } catch (e) {
      debugPrint('AUTO-LOGIN ERROR: $e');
      // Stored token is invalid or expired — clear it and fall back to login.
      await _storage.delete(key: 'jwt_token');
      _token = null;
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _name = null;
    _role = null;
    await _storage.delete(key: 'jwt_token');
    notifyListeners();
  }
}