import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/expense.dart'; // assuming this exists
// import 'services/api_service.dart'; // comment out if not using real backend yet

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system, // or .light / .dark
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  List<Expense> _expenses = [];
  DateTime _selectedDate = DateTime.now();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? expensesJson = prefs.getString('expenses');

      if (expensesJson != null && expensesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(expensesJson);
        setState(() {
          _expenses = decoded.map((e) => Expense.fromJson(e)).toList();
          _expenses.sort((a, b) => b.date.compareTo(a.date)); // newest first
        });
      }

      // If you still want to try API fallback (optional)
      // final apiExpenses = await ApiService.fetchExpenses();
      // ... merge logic if needed
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _expenses.map((e) => e.toJson()).toList();
      await prefs.setString('expenses', jsonEncode(jsonList));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _addExpense() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: _selectedDate,
    );

    setState(() {
      _expenses.insert(0, newExpense); // add at top
    });

    _saveExpenses();

    _titleController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now(); // reset date

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense added')),
    );
  }

  Future<void> _deleteExpense(int index) async {
    final expense = _expenses[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _expenses.removeAt(index);
      });
      await _saveExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    }
  }

  Future<void> _presentDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalToday = _expenses
        .where((e) =>
    e.date.year == DateTime.now().year &&
        e.date.month == DateTime.now().month &&
        e.date.day == DateTime.now().day)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expense Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Quick summary card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Today\'s expenses: ₹${totalToday.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? const Center(
              child: Text(
                'No expenses yet.\nTap + to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (ctx, index) {
                final expense = _expenses[index];
                return Dismissible(
                  key: ValueKey(expense.id),  // ensure id is unique (String recommended)
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteExpense(index);  // ← call your method here
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    title: Text(expense.title),
                    trailing: Text('₹${expense.amount.toStringAsFixed(2)}'),
                    subtitle: Text(expense.date.toLocal().toString().split(' ')[0]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Add'),
        icon: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('New Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _presentDatePicker,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _addExpense,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}