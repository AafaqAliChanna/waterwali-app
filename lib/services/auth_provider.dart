import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  String? _token;
  int? _userId;
  String? _name;
  String? _role;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // NEW: exposed so other services (OrderService, etc.) can attach
  // "Authorization: Bearer <token>" to their own API calls.
  String? get token => _token;
  int? get userId => _userId;
  String? get name => _name;
  String? get role => _role;
  bool get isCustomer => _role == 'CUSTOMER';
  bool get isDriver => _role == 'DRIVER';

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
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
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
