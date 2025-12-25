import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangalore Transit',
      debugShowCheckedModeBanner: false,
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
  final fromController = TextEditingController();
  final toController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bangalore Transit")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: "From Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: "To Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final from = fromController.text;
                  final to = toController.text;

                  final response = await http.post(
                    Uri.parse("http://10.0.2.2:4000/route"), // Android emulator
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"from": from, "to": to}),
                  );

                  debugPrint(response.body);
                },
                child: const Text("Find Route"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
