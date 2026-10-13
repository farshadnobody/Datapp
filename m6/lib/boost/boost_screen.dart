import 'package:flutter/material.dart';

import '../api_client.dart';
import '../style/app_colors.dart';
import 'boost_state.dart';

/// صفحه‌ی بوست: وضعیتِ بوستِ فعال + تاریخچه. تاریخچه *فقط* وقتی این صفحه باز می‌شه لود می‌شه
/// (فقط شمارنده‌ها؛ هیچ اسمی از لایک‌کننده‌ها نیست).
class BoostScreen extends StatefulWidget {
  const BoostScreen({super.key});
  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  final List<BoostInfo> _items = [];
  bool _loading = true;
  bool _hasMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    BoostState.instance.refresh();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final j = await ApiClient.fetchBoostHistory(offset: _items.length);
      final list = (j['items'] as List? ?? const [])
          .map((e) => BoostInfo.fromJson(Map<String, dynamic>.from(e as Map)));
      _items.addAll(list);
      _hasMore = j['has_more'] == true;
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  String _digits(Object n) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    return '$n'.split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : fa[i];
    }).join();
  }

  String _date(DateTime d) => _digits('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}');

  Widget _chip(String label, int v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppDark.border)),
        child: Text('$label ${_digits(v)}', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
      );

  Widget _chips(BoostInfo b) => Wrap(spacing: 6, runSpacing: 6, children: [
        _chip('بازدید', b.views),
        _chip('لایک', b.likes),
        _chip('سوپرلایک', b.supers),
        _chip('رد', b.passes),
        _chip('متچ', b.matches),
      ]);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        appBar: AppBar(backgroundColor: AppDark.bg, foregroundColor: Colors.white, title: const Text('بوست')),
        body: ListenableBuilder(
          listenable: BoostState.instance,
          builder: (context, _) {
            final s = BoostState.instance;
            final a = s.active;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(16)),
                child: a == null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('بوستِ فعالی نداری', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('موجودی: ${_digits(s.credits)}', style: const TextStyle(color: AppDark.muted)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_digits(a.views)} از ${_digits(a.viewBudget)} بازدید',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (a.views / a.viewBudget).clamp(0.0, 1.0),
                          color: const Color(0xFFF4B0EC),
                          backgroundColor: AppDark.border,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 10),
                        Text('${_digits(a.remaining.inHours)} ساعت تا پایانِ سقفِ زمانی',
                            style: const TextStyle(color: AppDark.muted)),
                        const SizedBox(height: 10),
                        _chips(a),
                      ]),
              ),
              const SizedBox(height: 22),
              const Text('تاریخچه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (_items.isEmpty && !_loading && !_failed)
                const Text('هنوز بوستی نداشتی.', style: TextStyle(color: AppDark.muted)),
              if (_failed) const Text('دریافت تاریخچه با مشکل مواجه شد.', style: TextStyle(color: AppDark.warning)),
              for (final b in _items)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_date(b.startedAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _chips(b),
                  ]),
                ),
              if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_hasMore && !_loading)
                TextButton(onPressed: _load, child: const Text('بیشتر', style: TextStyle(color: AppDark.muted))),
            ]);
          },
        ),
      ),
    );
  }
}
