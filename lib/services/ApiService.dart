import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
  );

  static Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> sendChatMessage(String message) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chatbot/message'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    return jsonDecode(response.body);
  }

  static Future<List> getTickets() async {
    final headers = await getAuthHeaders();
    final response = await http.get(Uri.parse('$baseUrl/tickets'), headers: headers);
    return jsonDecode(response.body);
  }

  Future<Object?> login(String trim, String trim2) async {
    return null;
  }
}