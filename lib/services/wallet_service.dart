import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet_model.dart';
import 'api_service.dart';

class WalletService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<Wallet> getWallet(String token) async {
    final url = Uri.parse('$_baseUrl/wallet/me');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Wallet.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Could not load wallet balance.');
    }
  }

  Future<Wallet> topup(String token, double amount) async {
    final url = Uri.parse('$_baseUrl/wallet/topup');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode == 200) {
      return Wallet.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Top-up failed. Please try again.');
    }
  }
}