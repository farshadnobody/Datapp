import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/match_models.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<MatchSummary>? _matches;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final matches = await ApiClient.fetchMatches();
      if (mounted) setState(() => _matches = matches);
    } catch (e) {
      if (mounted) setState(() => _error = 'دریافت متچ‌ها با مشکل مواجه شد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('متچ‌های من')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
          ]),
        ),
      );
    }
    if (_matches == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_matches!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('هنوز متچی نداری — برو تو «کشف» بگرد!', textAlign: TextAlign.center),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _matches!.length,
      itemBuilder: (context, index) {
        final m = _matches![index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: m.photoUrl.isNotEmpty
                    ? Image.network('$backendBaseUrl${m.photoUrl}',
                        fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 48, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(m.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );
      },
    );
  }
}
