import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/profile_models.dart';
import '../style/app_colors.dart';
import '../widgets/discovery_profile_detail_sheet.dart';

/// پروفایلِ کاملِ طرفِ چت — از تپ روی عکس/اسمش تو هدرِ صفحه‌ی چت باز می‌شه.
/// برخلاف «پیش‌نمایش پروفایلِ من» اینجا اسکرول قفل نیست و فلش صرفاً دکمه‌ی
/// بستن‌ه (برمی‌گردونه به همون چت). آخرِ اسکرول هم دکمه‌های
/// اشتراک‌گذاری/Unmatch/Block/Report هست.
///
/// اگه Unmatch یا Block موفق بشه، این صفحه با pop(true) بسته می‌شه —
/// صفحه‌ی چتی که این رو باز کرده باید همون true رو بگیره و خودش هم ببنده.
class MatchProfileScreen extends StatefulWidget {
  final MatchSummary match;

  const MatchProfileScreen({super.key, required this.match});

  @override
  State<MatchProfileScreen> createState() => _MatchProfileScreenState();
}

class _MatchProfileScreenState extends State<MatchProfileScreen> {
  DiscoveryCandidate? _candidate;
  Map<String, String> _promptTextMap = {};
  Map<String, String> _interestLabelMap = {};
  bool _loading = true;
  String? _error;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.fetchDiscoveryProfile(widget.match.publicId),
        ApiClient.fetchProfileOptions(),
      ]);
      final candidate = results[0] as DiscoveryCandidate;
      final options = results[1] as ProfileOptions;
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _promptTextMap = {for (final p in options.prompts) p.id: p.text};
        _interestLabelMap = {for (final i in options.interests) i.id: i.label};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'دریافت پروفایل با مشکل مواجه شد.';
        _loading = false;
      });
    }
  }

  List<String> get _photoUrls {
    final c = _candidate;
    if (c == null) return [];
    return c.photos.map((p) => '$backendBaseUrl${p.url}').toList();
  }

  void _onTapUp(TapUpDetails d, double width) {
    final count = _photoUrls.length;
    if (count <= 1) return;
    final goNext = d.localPosition.dx >= width / 2;
    final next = _photoIndex + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _photoIndex = next);
  }

  void _share() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: 'پروفایل ${widget.match.name} رو تو اپ ببین 👀'));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('متن اشتراک‌گذاری کپی شد.')));
  }

  Future<bool?> _confirm({required String title, required String body, required String confirmLabel}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.cardAlt,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: AppDark.muted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: AppDark.warning, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _unmatch() async {
    final ok = await _confirm(
      title: 'Unmatch از ${widget.match.name}؟',
      body: 'دیگه تو لیست متچ‌هات نمی‌بینیدش، و طرف هم دیگه نمی‌تونه بهت پیام بده.',
      confirmLabel: 'Unmatch',
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.unmatch(widget.match.publicId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این قابلیت هنوز آماده نیست.')));
    }
  }

  Future<void> _block() async {
    final ok = await _confirm(
      title: 'مسدود کردنِ ${widget.match.name}؟',
      body: 'دیگه همدیگه رو نمی‌بینید — نه تو چت، نه تو کشف.',
      confirmLabel: 'مسدود کن',
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.blockUser(widget.match.publicId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این قابلیت هنوز آماده نیست.')));
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppDark.cardAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportReasonSheet(matchName: widget.match.name),
    );
    if (reason == null || !mounted) return;
    try {
      await ApiClient.reportUser(widget.match.publicId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارشت ثبت شد — نگران نباش، طرف خبردار نمی‌شه.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ثبت گزارش با مشکل مواجه شد.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _candidate == null ? widget.match.name : '${_candidate!.name}, ${_candidate!.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.keyboard_arrow_down, size: 22, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppDark.muted)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
        ]),
      );
    }
    final c = _candidate!;
    final urls = _photoUrls;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (urls.isEmpty)
                      Container(
                        color: AppDark.cardAlt,
                        child: const Center(child: Icon(Icons.person, size: 96, color: AppDark.muted)),
                      )
                    else
                      Image.network(urls[_photoIndex.clamp(0, urls.length - 1)],
                          fit: BoxFit.cover, gaplessPlayback: true),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
                      ),
                    ),
                    if (urls.length > 1)
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Row(
                            children: List.generate(urls.length, (i) {
                              return Expanded(
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: i == _photoIndex ? Colors.white : const Color(0x66FFFFFF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          DiscoveryProfileDetailSheet(
            candidate: c,
            promptTextMap: _promptTextMap,
            interestLabelMap: _interestLabelMap,
          ),
          const SizedBox(height: 4),
          _ActionButton(label: 'اشتراک‌گذاریِ پروفایلِ ${c.name}', onTap: _share),
          const SizedBox(height: 10),
          _ActionButton(label: 'Unmatch', onTap: _unmatch),
          const SizedBox(height: 10),
          _ActionButton(label: 'مسدودسازیِ ${c.name}', onTap: _block),
          const SizedBox(height: 10),
          _ActionButton(label: 'گزارشِ ${c.name}', onTap: _report, danger: true),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionButton({required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDark.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: danger ? AppDark.warning : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportReasonSheet extends StatelessWidget {
  final String matchName;
  const _ReportReasonSheet({required this.matchName});

  static const _reasons = [
    ('inappropriate_content', 'محتوای نامناسب'),
    ('fake_profile', 'پروفایل جعلی'),
    ('harassment', 'آزار یا رفتار توهین‌آمیز'),
    ('scam', 'کلاه‌برداری یا اسپم'),
    ('underage', 'کمتر از سن مجاز به نظر می‌رسه'),
    ('other', 'دلیل دیگه'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('گزارشِ $matchName',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('چرا می‌خوای گزارشش کنی؟', style: TextStyle(color: AppDark.muted, fontSize: 14)),
            const SizedBox(height: 12),
            for (final r in _reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.$2, style: const TextStyle(color: Colors.white, fontSize: 15)),
                trailing: const Icon(Icons.chevron_left, color: AppDark.muted),
                onTap: () => Navigator.of(context).pop(r.$1),
              ),
          ],
        ),
      ),
    );
  }
}
