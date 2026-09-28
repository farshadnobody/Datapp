import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../likes/likes_data.dart';

/// تب «لایک‌ها» — دقیقاً شبیهِ صفحه‌ی Likes You تیندر:
///   • هدر با تعدادِ کسایی که لایکت کرده‌ان.
///   • برای کاربرِ غیرِپرمیوم: بنرِ آپگرید + گریدِ بلورشده‌ی قفل (فقط
///     شمارش، بدونِ هویت).
///   • برای کاربرِ پرمیوم: گریدِ دوستونه‌ی ناهم‌اندازه، هرکارت با بجِ
///     لایک/سوپرلایک و نقطه‌ی سبزِ «اخیراً آنلاین».
///   • تپ روی کارتِ باز = صفحه‌ی پروفایل با Pass/Like؛ لایک‌کردن چون
///     طرف قبلاً لایک‌مون کرده، بلافاصله مچ می‌شه.
class LikesScreen extends StatefulWidget {
  /// وضعیتِ اشتراکِ کاربر؛ با state واقعیِ خرید/اشتراکِ اپ وصلش کن.
  final bool isPremium;
  final VoidCallback? onUpgrade;

  const LikesScreen({super.key, this.isPremium = false, this.onUpgrade});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  late Future<List<LikeEntry>> _future;
  final List<LikeEntry> _likes = [];

  @override
  void initState() {
    super.initState();
    _future = fetchLikesYou().then((v) {
      _likes
        ..clear()
        ..addAll(v);
      return v;
    });
  }

  void _onTapCard(LikeEntry entry) {
    HapticFeedback.lightImpact();
    if (!widget.isPremium) {
      _showPaywallSheet();
      return;
    }
    _openProfile(entry);
  }

  void _showPaywallSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaywallSheet(
        likeCount: _likes.length,
        onUpgrade: () {
          Navigator.pop(context);
          widget.onUpgrade?.call();
        },
      ),
    );
  }

  Future<void> _openProfile(LikeEntry entry) async {
    final liked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _LikeProfileDetail(entry: entry)),
    );
    if (liked == null) return;

    // منبع حقیقت بک‌اندِ: لایک/رد *واقعاً* ثبت می‌شه (قبلاً فقط لوکال بود و
    // «متچ» فیک نشون داده می‌شد). فقط بعد از جوابِ سرور لیست عوض می‌شه.
    try {
      final result = await ApiClient.swipe(entry.candidate.publicId, liked ? 'like' : 'pass');
      if (!mounted) return;
      setState(() => _likes.remove(entry));
      if (result.matched) {
        // لایکِ pending الان تبدیل به متچ شده (از Likes You حذف شد).
        _showMatchDialog(entry);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'already_matched' || e.code == 'profile_not_found') {
        await _refresh(); // وضعیت تو بک‌اند عوض شده؛ لیست رو از سرور می‌گیریم.
      } else {
        _toast('ثبت انجام نشد. دوباره تلاش کن.');
      }
    } catch (_) {
      if (mounted) _toast('ارتباط با سرور برقرار نشد.');
    }
  }

  Future<void> _refresh() async {
    try {
      final fresh = await fetchLikesYou();
      if (!mounted) return;
      setState(() {
        _likes
          ..clear()
          ..addAll(fresh);
      });
    } catch (_) {}
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _showMatchDialog(LikeEntry entry) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'یه مچِ جدید داری!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'تو و ${entry.candidate.name} همدیگه رو لایک کردین',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE9190C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('باشه', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<List<LikeEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.white70));
            }
            if (_likes.isEmpty) {
              return _EmptyLikes(topPad: topPad);
            }
            final superLikes = _likes.where((e) => e.isSuperLike).toList();
            final normalLikes = _likes.where((e) => !e.isSuperLike).toList();
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: topPad > 0 ? 0 : 8),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                      child: const Text(
                        'لایک‌ها',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      '${_likes.length} نفر پروفایلتو لایک کرده‌ان',
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                    ),
                  ),
                ),
                if (!widget.isPremium)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _UpgradeBanner(onTap: _showPaywallSheet),
                    ),
                  ),
                // سوپرلایک‌ها جدا از لایک‌های معمولی (بک‌اند is_super_like رو
                // می‌فرسته). وقتی متچ بشن، خودشون از این دو لیست حذف می‌شن.
                if (superLikes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.star_rounded,
                      color: Color(0xFF3D9CF0),
                      title: 'سوپرلایک‌ها',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: _MasonryLikesGrid(
                        entries: superLikes,
                        isPremium: widget.isPremium,
                        onTap: _onTapCard,
                      ),
                    ),
                  ),
                ],
                if (normalLikes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.favorite_rounded,
                      color: Color(0xFFFFC629),
                      title: 'لایک‌ها',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: _MasonryLikesGrid(
                        entries: normalLikes,
                        isPremium: widget.isPremium,
                        onTap: _onTapCard,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionHeader({required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// گریدِ دوستونه‌ی ناهم‌اندازه — کارت‌ها یکی‌درمیون بلندتر/کوتاه‌ترن،
/// دقیقاً همون حسِ ویژوالِ گریدِ Likes You تیندر (نه یه گریدِ چهارگوشِ ساده).
class _MasonryLikesGrid extends StatelessWidget {
  final List<LikeEntry> entries;
  final bool isPremium;
  final ValueChanged<LikeEntry> onTap;

  const _MasonryLikesGrid({
    required this.entries,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final left = <LikeEntry>[];
    final right = <LikeEntry>[];
    for (var i = 0; i < entries.length; i++) {
      (i.isEven ? left : right).add(entries[i]);
    }

    Widget column(List<LikeEntry> items, int colOffset) => Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _LikeCard(
                entry: items[i],
                isPremium: isPremium,
                tall: (i + colOffset).isEven,
                onTap: () => onTap(items[i]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left, 0)),
        const SizedBox(width: 12),
        Expanded(child: column(right, 1)),
      ],
    );
  }
}

class _LikeCard extends StatelessWidget {
  final LikeEntry entry;
  final bool isPremium;
  final bool tall;
  final VoidCallback onTap;

  const _LikeCard({
    required this.entry,
    required this.isPremium,
    required this.tall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = entry.candidate;
    final photoUrl = c.photos.isNotEmpty ? resolveLikePhotoUrl(c.photos.first.url) : '';
    final locked = !isPremium;
    final isActive = c.activityStatus == 'active';

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: tall ? 0.66 : 0.82,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: entry.isSuperLike ? Border.all(color: const Color(0xFF3D9CF0), width: 2.5) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: photoUrl.isEmpty
                    ? Container(
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(Icons.person, color: Color(0xFF48484A), size: 44),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(Icons.person, color: Color(0xFF48484A), size: 44),
                        ),
                      ),
              ),
              // بلورِ قفل — دقیقاً همون رفتارِ Likes You تیندر برای کاربرِ
              // غیرِپرمیوم: عکس دیده می‌شه ولی هویت مشخص نیست.
              if (locked)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(color: Colors.black.withOpacity(0.25)),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
              if (locked)
                const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 30))
              else
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Row(
                    children: [
                      if (isActive) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFF3AA25C), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          '${c.name}, ${c.age}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              // بجِ لایک/سوپرلایک — قلبِ طلایی برای لایکِ معمولی، ستاره‌ی
              // آبی برای Super Like (کارتِ سوپرلایک حاشیه‌ی آبی هم داره).
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: entry.isSuperLike ? const Color(0xFF3D9CF0) : const Color(0xFFFFC629),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.isSuperLike ? Icons.star_rounded : Icons.favorite_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحه‌ی پروفایلِ کاملِ یه لایک — فقط برای کاربرِ پرمیوم قابلِ‌دسترسیه
/// (چون تپ روی کارتِ قفل‌شده به‌جاش پی‌وال باز می‌کنه). لایک‌کردن اینجا
/// چون طرف قبلاً لایک‌مون کرده، بلافاصله مچ می‌شه — دقیقاً رفتارِ تیندر.
class _LikeProfileDetail extends StatelessWidget {
  final LikeEntry entry;
  const _LikeProfileDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = entry.candidate;
    final photoUrl = c.photos.isNotEmpty ? resolveLikePhotoUrl(c.photos.first.url) : '';
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          photoUrl.isEmpty
              ? Container(color: const Color(0xFF2C2C2E))
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2C2C2E)),
                ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 6,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (entry.isSuperLike)
            Positioned(
              top: topPad + 14,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF3D9CF0), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('سوپرلایک کرده', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 118,
            child: Text(
              '${c.name}, ${c.age}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundActionButton(
                  icon: Icons.close,
                  bg: const Color(0xFF3C3C3E),
                  onTap: () => Navigator.pop(context, false),
                ),
                const SizedBox(width: 28),
                _RoundActionButton(
                  icon: Icons.favorite,
                  bg: const Color(0xFFE9190C),
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  const _RoundActionButton({required this.icon, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: SizedBox(width: 60, height: 60, child: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFC629), Color(0xFFCC8A00)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.white, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ببین کی لایکت کرده',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// شیتِ آپگرید — دقیقاً نقشِ پی‌والِ صفحه‌ی Likes You تیندر: هیچ عکسِ
/// بازی نشون نمی‌ده، فقط تعدادِ لایک‌ها رو با یه CTA برای ارتقا می‌فروشه.
class _PaywallSheet extends StatelessWidget {
  final int likeCount;
  final VoidCallback onUpgrade;
  const _PaywallSheet({required this.likeCount, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(0xFFFFC629), shape: BoxShape.circle),
              child: const Icon(Icons.favorite, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              '$likeCount نفر لایکت کرده‌ان',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'با ارتقا به اشتراکِ ویژه، همین الان ببین کیا لایکت کرده‌ان و به‌جای سواپِ تصادفی، مستقیم مچ کن.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC629),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onUpgrade,
                child: const Text(
                  'ارتقا به نسخه‌ی ویژه',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('شاید بعداً', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLikes extends StatelessWidget {
  final double topPad;
  const _EmptyLikes({required this.topPad});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.favorite_border, color: Color(0xFF48484A), size: 56),
              SizedBox(height: 16),
              Text(
                'هنوز کسی لایکت نکرده',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'همین‌طور که سواپ می‌کنی، لایک‌های جدید همین‌جا نشون داده می‌شن',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
