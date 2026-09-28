import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../models/match_models.dart';
import 'location_picker_screen.dart';
import 'matches_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  List<DiscoveryCandidate> _stack = [];
  final Set<String> _excluded = {};
  ProfileOptions? _options;
  bool _loading = true;
  String? _error;

  int _minAge = 18;
  int _maxAge = 100;
  double? _maxDistanceKm; // null = بدون محدودیت

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;

  late AnimationController _exitController;
  Offset _exitTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )
      ..addListener(() {
        setState(() {
          _dragOffset = Offset.lerp(Offset.zero, _exitTarget, _exitController.value)!;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishSwipe();
        }
      });
    _init();
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // یه سقف زمانی کلی رو کل مرحله‌ی لوکیشن می‌ذاریم — چون بعضی پلتفرم‌ها
    // (خصوصاً دسکتاپ/وب) گاهی تو دیالوگ مجوز GPS گیر می‌کنن و هیچ‌وقت جواب
    // نمی‌دن؛ بدون این سقف، کل صفحه برای همیشه تو حالت لودینگ می‌مونه.
    await _tryUpdateLocation().timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    try {
      final options = await ApiClient.fetchProfileOptions();
      if (mounted) setState(() => _options = options);
    } catch (_) {
      // نبود این اختیاریه — فقط برای نشون دادن متن سؤال‌های پرامپت لازمه.
    }
    await _loadMore();
  }

  Future<void> _tryUpdateLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // بی‌خیال؛ بدون فاصله ادامه می‌دیم.
      }
      final position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low))
          .timeout(const Duration(seconds: 8));
      await ApiClient.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // موقعیت اختیاریه؛ اگه نشد، Discovery فقط بدون فاصله کار می‌کنه.
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await ApiClient.fetchDiscovery(
        minAge: _minAge,
        maxAge: _maxAge,
        maxDistanceKm: _maxDistanceKm,
        exclude: _excluded.toList(),
      );
      if (mounted) setState(() => _stack = [..._stack, ...candidates]);
    } on NetworkException {
      if (mounted) setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'profile_required'
            ? 'اول باید پروفایلت رو تکمیل کنی.'
            : 'دریافت لیست با مشکل مواجه شد.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = _dragOffset.dx / 300;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    const threshold = 100;
    if (_dragOffset.dx > threshold) {
      _animateExit(right: true);
    } else if (_dragOffset.dx < -threshold) {
      _animateExit(right: false);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0;
      });
    }
  }

  void _animateExit({required bool right}) {
    if (_stack.isEmpty || _exitController.isAnimating) return;
    HapticFeedback.mediumImpact();
    _exitTarget = Offset(right ? 600 : -600, _dragOffset.dy);
    _exitController.forward(from: 0);
  }

  // نکته: قبلاً swipe فقط کارت رو از صف حذف می‌کنه (تو همون session) — از الان
  // واقعاً به بک‌اند ثبت می‌شه (منتظرش نمی‌مونیم تا UI قفل نشه) و اگه لایک
  // متقابل باشه، پیام «متچ شدی!» نشون داده می‌شه.
  void _finishSwipe() {
    if (_stack.isEmpty) return;
    final swiped = _stack.first;
    final direction = _exitTarget.dx > 0 ? 'like' : 'pass';

    _excluded.add(swiped.publicId);
    setState(() {
      _stack = _stack.skip(1).toList();
      _dragOffset = Offset.zero;
      _dragAngle = 0;
    });
    _exitController.reset();
    if (_stack.length < 5) {
      _loadMore();
    }

    ApiClient.swipe(swiped.publicId, direction).then((result) {
      if (result.matched && result.match != null && mounted) {
        _showMatchDialog(result.match!);
      }
    }).catchError((_) {
      // اگه ثبت swipe شکست بخوره، فقط بی‌خیال می‌شیم — کارت که رد شده برنمی‌گرده،
      // ولی چیز حیاتی‌ای هم از دست نرفته.
    });
  }

  void _showMatchDialog(MatchSummary match) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('متچ شدی!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (match.photoUrl.isNotEmpty)
                ClipOval(
                  child: Image.network(
                    '$backendBaseUrl${match.photoUrl}',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Text('تو و ${match.name} همدیگه رو لایک کردین!',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text('ادامه‌ی کشف'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchesScreen()),
                  );
                },
                child: const Text('دیدن متچ‌ها'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> get _promptTextMap {
    if (_options == null) return {};
    return {for (final p in _options!.prompts) p.id: p.text};
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  void _openFilters() {
    int tempMin = _minAge;
    int tempMax = _maxAge;
    double? tempDistance = _maxDistanceKm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('فیلترها',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('بازه‌ی سن: $tempMin تا $tempMax'),
                RangeSlider(
                  min: 18,
                  max: 100,
                  divisions: 82,
                  values: RangeValues(tempMin.toDouble(), tempMax.toDouble()),
                  onChanged: (values) => setSheetState(() {
                    tempMin = values.start.round();
                    tempMax = values.end.round();
                  }),
                ),
                const SizedBox(height: 8),
                Text(tempDistance == null
                    ? 'حداکثر فاصله: بدون محدودیت'
                    : 'حداکثر فاصله: ${tempDistance!.round()} کیلومتر'),
                Slider(
                  min: 1,
                  max: 200,
                  divisions: 199,
                  value: tempDistance ?? 200,
                  onChanged: (v) => setSheetState(() => tempDistance = v >= 200 ? null : v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    setState(() {
                      _minAge = tempMin;
                      _maxAge = tempMax;
                      _maxDistanceKm = tempDistance;
                      _stack = [];
                    });
                    _loadMore();
                  },
                  child: const Text('اعمال فیلتر'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _openDetail(DiscoveryCandidate candidate) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ProfileDetailSheet(
          candidate: candidate,
          promptTextMap: _promptTextMap,
          interestLabelMap: _interestLabelMap,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('کشف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'انتخاب موقعیت رو نقشه',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
              );
              if (changed == true) {
                setState(() => _stack = []);
                _loadMore();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.tune), onPressed: _openFilters),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _stack.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stack.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMore, child: const Text('تلاش دوباره')),
          ]),
        ),
      );
    }
    if (_stack.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.explore_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'کسی برای نشون دادن نمونده. فیلترهات رو باز کن یا بعداً سر بزن.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _openFilters, child: const Text('تنظیم فیلترها')),
          ]),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = min(_stack.length, 3) - 1; i >= 1; i--)
                  Transform.translate(
                    offset: Offset(0, i * 8),
                    child: Transform.scale(
                      scale: 1 - i * 0.03,
                      child: _buildCardContent(_stack[i]),
                    ),
                  ),
                _buildTopCard(_stack.first),
              ],
            ),
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildTopCard(DiscoveryCandidate candidate) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: () => _openDetail(candidate),
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _dragAngle,
          child: Stack(
            children: [
              _buildCardContent(candidate),
              if (_dragOffset.dx > 0)
                Positioned(
                  top: 24,
                  left: 24,
                  child: Opacity(
                    opacity: (_dragOffset.dx / 100).clamp(0, 1),
                    child: _buildBadge('لایک', Colors.green, -0.3),
                  ),
                ),
              if (_dragOffset.dx < 0)
                Positioned(
                  top: 24,
                  right: 24,
                  child: Opacity(
                    opacity: (-_dragOffset.dx / 100).clamp(0, 1),
                    child: _buildBadge('رد', Colors.red, 0.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCardContent(DiscoveryCandidate candidate) {
    final photoUrl =
        candidate.photos.isNotEmpty ? '$backendBaseUrl${candidate.photos.first.url}' : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Image.network(photoUrl, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 96, color: Colors.white),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${candidate.name}, ${candidate.age}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    if (candidate.distanceKm != null)
                      Text('${candidate.distanceKm} کیلومتر دورتر',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(Icons.close, Colors.red, () => _animateExit(right: false)),
          _actionButton(Icons.info_outline, Colors.blue, () {
            if (_stack.isNotEmpty) _openDetail(_stack.first);
          }, small: true),
          _actionButton(Icons.favorite, Colors.green, () => _animateExit(right: true)),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap, {bool small = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: CircleAvatar(
        radius: small ? 20 : 28,
        backgroundColor: Colors.white,
        child: Icon(icon, color: color, size: small ? 20 : 28),
      ),
    );
  }
}

class _ProfileDetailSheet extends StatelessWidget {
  final DiscoveryCandidate candidate;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;
  final ScrollController scrollController;

  const _ProfileDetailSheet({
    required this.candidate,
    required this.promptTextMap,
    required this.interestLabelMap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        if (candidate.photos.isNotEmpty)
          SizedBox(
            height: 320,
            child: PageView(
              children: candidate.photos
                  .map((p) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network('$backendBaseUrl${p.url}', fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        Text('${candidate.name}, ${candidate.age}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (candidate.distanceKm != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${candidate.distanceKm} کیلومتر دورتر',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        if (candidate.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(candidate.bio),
        ],
        if (candidate.interests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.interests
                .map((id) => Chip(label: Text(interestLabelMap[id] ?? id)))
                .toList(),
          ),
        ],
        for (final prompt in candidate.prompts) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(promptTextMap[prompt.promptId] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(prompt.answer),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
