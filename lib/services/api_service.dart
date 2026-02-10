import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/expense.dart';

class ApiService {
  static const String baseUrl = 'https://dummyjson.com';

  /// Fetches a list of products and maps them to Expense model
  static Future<List<Expense>> fetchExpenses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products?limit=15'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> products = jsonData['products'] ?? [];

        return products.map((item) {
          return Expense(
            id: item['id'].toString(),
            title: item['title'] as String? ?? 'Unknown Product',
            amount: (item['price'] as num?)?.toDouble() ?? 0.0,
            date: DateTime.now().subtract(
              Duration(days: item['id'] % 30), // fake recent dates
            ),
          );
        }).toList();
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching expenses: $e');
    }
  }

// Optional: If you want to add "add expense" later (DummyJSON doesn't support POST)
// For now, we keep it local or just show fetched data
}