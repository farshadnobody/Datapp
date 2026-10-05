import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../style/app_colors.dart';
import 'chat_screen.dart';
import '../widgets/app_network_image.dart';
import '../chat/conversations_store.dart';
import '../bootstrap/bootstrap_service.dart';
import '../likes/likes_store.dart';
import '../subscription/subscription_state.dart';

/// لیست چت — سرِ صفحه، نوارِ جستجو، ردیفِ «متچ‌های جدید» (+ کارتِ تیزرِ
/// لایک‌ها)، و پایینش لیستِ «پیام‌ها». دیتا از `GET /api/conversations` و
/// `GET /api/likes/summary` میاد — این دو اندپوینت هنوز تو بک‌اند نیستن
/// (به ApiClient اضافه‌شون کردم، همین‌جا منتظرِ 404/خطا می‌مونه تا وصل
/// بشن).
class MatchesScreen extends StatefulWidget {
  final VoidCallback? onOpenLikes;
  const MatchesScreen({super.key, this.onOpenLikes});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<ConversationSummary> _conversations = [];
  LikesSummary? _likes;
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // لیستِ چت‌ها از ConversationsStore میاد (فایلِ ذخیره‌شده + رویدادهای سرور)؛ این صفحه
    // هر بار که باز می‌شه چیزی از سرور نمی‌گیره.
    ConversationsStore.instance.addListener(_syncFromStore);
    AppCounters.instance.addListener(_syncFromStore);
    LikesStore.instance.addListener(_syncFromStore);
    _syncFromStore();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    ConversationsStore.instance.removeListener(_syncFromStore);
    AppCounters.instance.removeListener(_syncFromStore);
    LikesStore.instance.removeListener(_syncFromStore);
    _searchController.dispose();
    super.dispose();
  }

  void _syncFromStore() {
    if (!mounted) return;
    final store = ConversationsStore.instance;
    // تیزرِ لایک‌ها: از شمارنده‌ی روی گوشی (رایگان) یا لایک‌های ذخیره‌شده (اشتراکی)؛
    // درخواستِ جدا به /api/likes/summary نمی‌ره.
    final premium = SubscriptionState.instance.isPremium;
    final previews = premium
        ? LikesStore.instance.entries
            .map((e) => e.candidate.photos.isNotEmpty ? e.candidate.photos.first.url : '')
            .where((u) => u.isNotEmpty)
            .take(3)
            .toList()
        : <String>[];
    setState(() {
      _conversations = store.items;
      _loading = store.loading && store.items.isEmpty;
      _error = store.error;
      _likes = LikesSummary(
        count: AppCounters.instance.likesCount,
        superLikeCount: AppCounters.instance.superLikeCount,
        previewPhotoUrls: previews,
      );
    });
  }

  /// تلاشِ دوباره (دکمه‌ی «دوباره» وقتی خطا بود).
  Future<void> _load() => ConversationsStore.instance.refresh();

  MatchSummary _toMatchSummary(ConversationSummary c) =>
      MatchSummary(publicId: c.publicId, name: c.name, photoUrl: c.photoUrl, matchedAt: c.matchedAt);

  Future<void> _openChat(ConversationSummary c) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ChatScreen(match: _toMatchSummary(c))));
    // لازم نیست رفرش کنیم: پیامی که فرستادیم، پاک‌کردنِ گفتگو و آنمتچ/بلاک خودشون
    // ConversationsStore رو به‌روز می‌کنن.
  }

  List<ConversationSummary> get _filtered {
    if (_query.isEmpty) return _conversations;
    final q = _query.toLowerCase();
    return _conversations.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildBody()),
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

    final all = _filtered;
    // جدا کردنِ «متچ‌های جدید» از «مکالمه‌های فعال» از روی state بک‌اند
    // (new_match / active)، نه از روی این‌که پیامی تو لیست هست یا نه.
    final newMatches = all.where((c) => c.isNewMatch).toList();
    final withMessages = all.where((c) => !c.isNewMatch).toList()
      ..sort((a, b) => (b.lastMessageAt ?? b.matchedAt ?? DateTime(0))
          .compareTo(a.lastMessageAt ?? a.matchedAt ?? DateTime(0)));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('چت', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.shield_outlined, color: Colors.white),
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('به‌زودی اضافه می‌شه.'))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppDark.cardAlt, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppDark.muted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'جست‌وجو در ${_conversations.length} متچ',
                        hintStyle: const TextStyle(color: AppDark.muted),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (newMatches.isNotEmpty || (_likes?.count ?? 0) > 0) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Text('متچ‌های جدید',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if ((_likes?.count ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _LikesTeaserCard(likes: _likes!, onTap: widget.onOpenLikes),
                    ),
                  for (final c in newMatches)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _NewMatchCard(conversation: c, onTap: () => _openChat(c)),
                    ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
            child: Text('پیام‌ها', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (withMessages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text('هنوز پیامی رد و بدل نشده — رو یکی از متچ‌های بالا بزن و شروع کن!',
                  style: TextStyle(color: AppDark.muted, fontSize: 13, height: 1.5)),
            )
          else
            for (final c in withMessages) _MessageRow(conversation: c, onTap: () => _openChat(c)),
        ],
      ),
    );
  }
}

class _NewMatchCard extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;
  const _NewMatchCard({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = conversation.photoUrl.isEmpty ? '' : '$backendBaseUrl${conversation.photoUrl}';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 96,
                height: 116,
                child: url.isEmpty
                    ? Container(color: AppDark.cardAlt, child: const Icon(Icons.person, color: AppDark.muted))
                    : AppNetworkImage(url, thumb: true, placeholderColor: AppDark.card),
              ),
            ),
            const SizedBox(height: 6),
            Text(conversation.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LikesTeaserCard extends StatelessWidget {
  final LikesSummary likes;
  final VoidCallback? onTap;
  const _LikesTeaserCard({required this.likes, this.onTap});

  @override
  Widget build(BuildContext context) {
    final previewUrl = likes.previewPhotoUrls.isEmpty ? null : likes.previewPhotoUrls.first;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 96,
                height: 116,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (previewUrl != null)
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: AppNetworkImage(previewUrl, thumb: true, placeholderColor: AppDark.card),
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE9B44C), Color(0xFFB2478A)],
                          ),
                        ),
                      ),
                    Container(color: const Color(0x55000000)),
                    const Center(child: Icon(Icons.lock, color: Colors.white, size: 22)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('${likes.count} لایک', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;
  const _MessageRow({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final url = c.photoUrl.isEmpty ? '' : '$backendBaseUrl${c.photoUrl}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppDark.cardAlt,
                  backgroundImage: url.isEmpty ? null : NetworkImage(url),
                  child: url.isEmpty ? const Icon(Icons.person, color: AppDark.muted) : null,
                ),
                if (c.recentlyActive)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3FCF6E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (c.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFF3D9CF0), size: 16),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    c.lastMessageBody ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppDark.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (c.yourTurn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('نوبتِ توئه', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
