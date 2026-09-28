import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'code_request_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dating App')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.favorite, size: 72, color: Colors.pink),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('ورود', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CodeRequestScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('ثبت‌نام یا فراموشی رمز',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
