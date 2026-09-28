import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth_session.dart';
import 'start_screen.dart';
import 'discovery_screen.dart';
import 'private_photos_screen.dart';
import 'edit_profile_screen.dart';
import 'matches_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحه‌ی اصلی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthSession.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StartScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.explore),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('کشف پروفایل‌ها'),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.favorite_border),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('متچ‌های من'),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchesScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('پروفایل من'),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('عکس‌های خصوصی'),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivatePhotosScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
