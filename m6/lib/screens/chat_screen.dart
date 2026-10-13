import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../realtime/realtime_service.dart';
import '../models/match_models.dart';
import '../chat/chat_cache.dart';
import '../models/chat_models.dart';
import '../style/app_colors.dart';
import '../subscription/premium_paywall.dart';
import '../subscription/subscription_state.dart';
import '../widgets/safety_toolkit_sheet.dart';
import 'match_profile_screen.dart';
import '../chat/conversations_store.dart';

class ChatScreen extends StatefulWidget {
  final MatchSummary match;
  const ChatScreen({super.key, required this.match});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _hasText = false;

  // صفحه‌بندیِ ۵۰تایی: hasMore = پیام‌های قدیمی‌ترِ قابل‌دیدن هست؛ locked = قدیمی‌ترها
  // فقط با اشتراک (کاربرِ رایگان فقط ۵۰ پیامِ آخر رو می‌بینه).
  bool _hasMore = false;
  bool _locked = false;
  bool _loadingMore = false;

  // کشِ محلیِ پیام‌ها: epoch = شمارنده‌ی «پاک کردنِ گفتگو» (از سرور)
  int _epoch = 0;
  StreamSubscription? _rtSub;
  Timer? _saveTimer;

  // حداقل فاصله‌ی بین دو پیام (سرور هم ۱ پیام در ثانیه اجازه می‌ده).
  DateTime _lastSendAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  /// اول از کشِ روی گوشی (فوری)، بعد فقط «پیام‌های جدیدتر از آخرین شناسه» از سرور.
  /// اگه کش نداریم (یا سرور بگه reset)، یه صفحه‌ی ۵۰تایی کامل.
  Future<void> _load() async {
    final cached = await ChatCache.load(widget.match.publicId);
    if (cached != null && mounted) {
      setState(() {
        _messages = cached.messages;
        _hasMore = cached.hasMore;
        _locked = cached.locked;
        _epoch = cached.epoch;
        _trimForFreeUser();
        _loading = false;
      });
      _scrollToBottom();
    }
    await _syncFromServer(initial: cached == null);
  }

  /// پیام‌های جدید رو از سرور می‌گیره و با لیستِ فعلی ترکیب می‌کنه.
  Future<void> _syncFromServer({bool initial = false}) async {
    try {
      var after = 0;
      for (final m in _messages) {
        if (m.id > after) after = m.id;
      }
      final page = await ApiClient.fetchMessages(
        widget.match.publicId,
        after: after > 0 ? after : null,
        epoch: after > 0 ? _epoch : null,
      );
      if (!mounted) return;
      setState(() {
        _epoch = page.epoch;
        if (page.reset || after == 0) {
          // کشِ ما بی‌اعتباره (یا اصلاً کش نداشتیم): لیستِ سرور جایگزین می‌شه.
          _messages = page.messages;
          _hasMore = page.hasMore;
          _locked = page.locked;
        } else if (page.messages.isNotEmpty) {
          final have = _messages.map((m) => m.id).toSet();
          _messages = [..._messages, ...page.messages.where((m) => !have.contains(m.id))];
        }
        _trimForFreeUser();
        _loading = false;
        _error = null;
      });
      _scrollToBottom();
      _persist();
    } catch (e) {
      if (e is ApiException && e.code == 'not_matched') {
        _closeBecauseUnmatched();
        return;
      }
      if (mounted && _messages.isEmpty && initial) {
        setState(() {
          _error = 'دریافت پیام‌ها با مشکل مواجه شد.';
          _loading = false;
        });
      } else if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  /// ذخیره‌ی کشِ محلی (با ۱ ثانیه تأخیر تا پشتِ هم نوشته نشه).
  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _persistNow);
  }

  void _persistNow() {
    ChatCache.save(widget.match.publicId, _messages,
        epoch: _epoch, hasMore: _hasMore, locked: _locked);
  }

  /// به WebSocketِ سراسریِ اپ گوش می‌دیم (اتصالِ جدا برای چت نمی‌سازیم). اگه اتصال
  /// نبود، اپ همچنان با REST کار می‌کنه و با برگشتنِ اتصال، پیام‌های جا مونده گرفته می‌شن.
  void _connectSocket() {
    _rtSub = RealtimeService.instance.events.listen((e) {
      final data = e.data;
      switch (e.type) {
        case 'connected':
          if (data['reconnect'] == true) _syncFromServer(); // وقتی قطع بودیم چیزی جا نمونده باشه
          break;
        case 'unmatched':
          if (data['from'] == widget.match.publicId) _closeBecauseUnmatched();
          break;
        case 'chat_cleared':
          if (data['from'] == widget.match.publicId) {
            _clearLocal();
            ChatCache.clear(widget.match.publicId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('طرفِ مقابل گفتگو رو برای هر دو نفر پاک کرد.')));
            }
            _syncFromServer(); // epoch جدید رو بگیر
          }
          break;
        case 'message':
          if (data['from'] != widget.match.publicId || !mounted) break;
          final id = (data['id'] as num?)?.toInt() ?? 0;
          if (id > 0 && _messages.any((m) => m.id == id)) break; // تکراری
          setState(() {
            _messages = [
              ..._messages,
              ChatMessage(
                id: id,
                fromMe: false,
                body: '${data['body']}',
                sentAt: DateTime.tryParse(data['sent_at']?.toString() ?? '') ?? DateTime.now(),
              ),
            ];
            _trimForFreeUser();
          });
          _scrollToBottom();
          _persist();
          break;
      }
    });
  }

  /// گفتگو پاک شد (توسط من یا طرفِ مقابل): همه‌ی پیام‌های روی صفحه خالی می‌شن.
  void _clearLocal() {
    if (!mounted) return;
    setState(() {
      _messages = [];
      _hasMore = false;
      _locked = false;
    });
    ChatCache.clear(widget.match.publicId); // کشِ محلی هم دیگه معتبر نیست
    ConversationsStore.instance.noteCleared(widget.match.publicId);
  }

  /// کاربرِ رایگان فقط N پیامِ آخر رو تو صفحه داره؛ با اومدنِ پیامِ جدید، قدیمی‌ترها از
  /// صفحه برداشته می‌شن (و با اشتراک می‌شه دوباره دیدشون). سرور هم همین رو اعمال می‌کنه.
  void _trimForFreeUser() {
    final sub = SubscriptionState.instance;
    if (!sub.loaded || sub.isPremium) return;
    final cap = sub.freeChatHistory > 0 ? sub.freeChatHistory : 50;
    if (_messages.length > cap) {
      _messages = _messages.sublist(_messages.length - cap);
      _locked = true;
      _hasMore = false;
    }
  }

  /// بارگذاریِ ۵۰ پیامِ قدیمی‌تر (فقط وقتی hasMore؛ کاربرِ رایگان اینجا نمی‌رسه).
  Future<void> _loadOlder() async {
    if (_loadingMore || !_hasMore) return;
    int? oldest;
    for (final m in _messages) {
      if (m.id > 0 && (oldest == null || m.id < oldest)) oldest = m.id;
    }
    if (oldest == null) return;
    setState(() => _loadingMore = true);
    final before = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent - _scrollController.position.pixels
        : 0.0;
    try {
      final page = await ApiClient.fetchMessages(widget.match.publicId, before: oldest);
      if (!mounted) return;
      setState(() {
        _messages = [...page.messages, ..._messages];
        _hasMore = page.hasMore;
        _locked = page.locked;
        _loadingMore = false;
      });
      _persist();
      // جای اسکرول ثابت بمونه (پیام‌هایی که می‌خوند نپرن).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent - before);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('دریافتِ پیام‌های قبلی با مشکل مواجه شد.')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _closing = false;

  /// مکالمه تو بک‌اند بسته شده (Unmatch از هر طرف) → چت رو می‌بندیم و لیست رو
  /// رفرش می‌کنه (matches_screen بعد از pop دوباره لود می‌کنه).
  void _closeBecauseUnmatched() {
    if (_closing || !mounted) return;
    _closing = true;
    ConversationsStore.instance.noteRemoved(widget.match.publicId);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('این متچ دیگه فعال نیست.')));
    Navigator.of(context).maybePop();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // حداقل ۱ ثانیه بین دو پیام (سرور هم همین سقف رو داره؛ این‌جا فقط درخواستِ
    // بی‌فایده نمی‌ره و متنِ کاربر پاک نمی‌شه).
    if (DateTime.now().difference(_lastSendAt) < const Duration(seconds: 1)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('یه کم آروم‌تر! بین هر دو پیام یه ثانیه صبر کن.'),
            duration: Duration(seconds: 1)));
      return;
    }
    _lastSendAt = DateTime.now();

    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _sending = true);

    // خوش‌بینانه اضافه‌ش می‌کنیم (بدون منتظر موندن برای جواب سرور)؛ اگه
    // ارسال شکست خورد، برش می‌داریم.
    final optimistic = ChatMessage(id: -1, fromMe: true, body: text, sentAt: DateTime.now());
    setState(() {
      _messages = [..._messages, optimistic];
      _trimForFreeUser();
    });
    _scrollToBottom();

    try {
      final sent = await ApiClient.sendMessage(widget.match.publicId, text);
      // پیامِ موقت رو با پیامِ واقعی (دارای شناسه) عوض می‌کنیم؛ شناسه برای صفحه‌بندی
      // و لایکِ پیام لازمه.
      if (mounted) {
        setState(() {
          _messages = [for (final m in _messages) identical(m, optimistic) ? sent : m];
        });
        _persist();
        // لیستِ چت‌ها بدونِ درخواست به‌روز می‌شه (آخرین پیام + اولین پیام = «فعال» شدنِ متچ).
        ConversationsStore.instance.noteSent(widget.match.publicId, sent.body, sent.sentAt);
      }
    } catch (e) {
      setState(() => _messages = _messages.where((m) => !identical(m, optimistic)).toList());
      if (e is ApiException && e.code == 'not_matched') {
        // یکی از دو طرف آنمتچ کرده؛ مکالمه دیگه تو بک‌اند بسته‌ست.
        _closeBecauseUnmatched();
        return;
      }
      // پیام ارسال نشد: متنش رو برمی‌گردونیم تا کاربر دوباره تایپ نکنه.
      if (mounted && _controller.text.isEmpty) _controller.text = text;
      if (mounted) {
        final msg = e is ApiException && e.code == 'too_many_requests'
            ? 'یه کم آروم‌تر! خیلی سریع پیام فرستادی.'
            : e is ApiException && e.code == 'message_too_long'
                ? 'پیامت خیلی طولانیه.'
                : 'ارسال پیام با مشکل مواجه شد.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(ChatMessage m) async {
    HapticFeedback.selectionClick();
    final liked = !m.liked;
    setState(() {
      _messages = [for (final x in _messages) x.id == m.id ? x.copyWith(liked: liked) : x];
    });
    try {
      await ApiClient.toggleMessageLike(m.id, liked);
      _persist();
    } catch (_) {
      // بی‌سروصدا برمی‌گردونیم — بک‌اند هنوز این اندپوینت رو نداره.
      if (mounted) {
        setState(() {
          _messages = [for (final x in _messages) x.id == m.id ? x.copyWith(liked: !liked) : x];
        });
      }
    }
  }

  Future<void> _openProfile() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => MatchProfileScreen(match: widget.match)));
    if (result == true && mounted) {
      // Unmatch/Block موفق بوده — برمی‌گردیم به لیست چت.
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openSafetyToolkit() async {
    HapticFeedback.lightImpact();
    final result = await showSafetyToolkitSheet(context,
        matchPublicId: widget.match.publicId,
        matchName: widget.match.name,
        onConversationCleared: _clearLocal);
    if (result == true) {
      // آنمتچ/بلاک: از لیستِ چت‌ها (روی گوشی) برداشته می‌شه، بدونِ درخواست.
      ConversationsStore.instance.noteRemoved(widget.match.publicId);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _persistNow();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _photoUrl() =>
      widget.match.photoUrl.isEmpty ? '' : '$backendBaseUrl${widget.match.photoUrl}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Divider(color: AppDark.border, height: 1),
              Expanded(child: _buildMessages()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final url = _photoUrl();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          GestureDetector(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppDark.cardAlt,
              backgroundImage: url.isEmpty ? null : NetworkImage(url),
              child: url.isEmpty ? const Icon(Icons.person, color: AppDark.muted, size: 18) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openProfile,
              child: Text(widget.match.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: _openSafetyToolkit,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppDark.muted)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
        ]),
      );
    }

    return Directionality(
      // چیدمانِ حباب‌های چت مستقل از جهتِ متنِ صفحه — آواتار همیشه سمتِ
      // چپِ پیامِ دریافتی، پیامِ خودمون همیشه سمتِ راست.
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
        itemCount: _messages.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildOlderTile();
          if (index == 1) {
            // «با X متچ شدی» فقط وقتی همه‌ی پیام‌ها بارگذاری شده (بالای لیست واقعاً ابتدای گفتگوئه).
            return (_hasMore || _locked) ? const SizedBox.shrink() : _buildMatchedHeader();
          }
          final m = _messages[index - 2];
          final prev = index - 3 >= 0 ? _messages[index - 3] : null;
          final showDivider =
              prev == null || m.sentAt.difference(prev.sentAt).abs() > const Duration(hours: 3);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDivider) _buildTimeDivider(m.sentAt),
              _buildBubbleRow(m),
            ],
          );
        },
      ),
    );
  }

  /// بالای لیست: «پیام‌های قبلی» (اگه بیشتر هست) یا «قفلِ اشتراک» (کاربرِ رایگان).
  Widget _buildOlderTile() {
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: _loadingMore
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _loadOlder,
                  child: const Text('نمایشِ پیام‌های قبلی'),
                ),
        ),
      );
    }
    if (_locked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: GestureDetector(
            onTap: () => showPremiumPaywall(context, PaywallReason.chatHistory),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppDark.cardAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline, color: Color(0xFFFFC629), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'برای دیدنِ پیام‌های قدیمی‌تر، اشتراکِ ویژه لازمه.',
                      style: TextStyle(color: AppDark.muted, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMatchedHeader() {
    final matchedAt = widget.match.matchedAt;
    final dateText = matchedAt == null ? '' : _formatShortDate(matchedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppDark.cardAlt,
            backgroundImage: _photoUrl().isEmpty ? null : NetworkImage(_photoUrl()),
            child: _photoUrl().isEmpty ? const Icon(Icons.person, color: AppDark.muted, size: 30) : null,
          ),
          const SizedBox(height: 10),
          Text(
            dateText.isEmpty
                ? 'با ${widget.match.name} متچ شدی!'
                : 'با ${widget.match.name} تو $dateText متچ شدی',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppDark.muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDivider(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text('${_weekdayName(dt)} ${_formatTime(dt)}',
            style: const TextStyle(color: AppDark.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBubbleRow(ChatMessage m) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: m.fromMe ? Colors.white : AppDark.cardAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(m.body,
          style: TextStyle(color: m.fromMe ? Colors.black : Colors.white, fontSize: 15, height: 1.3)),
    );

    if (m.fromMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppDark.cardAlt,
            backgroundImage: _photoUrl().isEmpty ? null : NetworkImage(_photoUrl()),
            child: _photoUrl().isEmpty ? const Icon(Icons.person, color: AppDark.muted, size: 13) : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _toggleLike(m),
            child: Icon(
              m.liked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: m.liked ? AppDark.accent : AppDark.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('گیف‌ها به‌زودی اضافه می‌شن.')));
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppDark.cardAlt, shape: BoxShape.circle),
              child: const Text('GIF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppDark.cardAlt, borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.centerRight,
              child: TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                minLines: 1,
                maxLines: 4,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(SubscriptionState.instance.maxMessageChars),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'پیامت رو بنویس...',
                  hintStyle: TextStyle(color: AppDark.muted),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          if (_hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppDark.accent, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _weekdayNamesFa = ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'];
const _monthNamesShort = [
  'ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', 'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر'
];

String _weekdayName(DateTime dt) => _weekdayNamesFa[dt.weekday - 1];

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$min $ampm';
}

String _formatShortDate(DateTime dt) => '${dt.day} ${_monthNamesShort[dt.month - 1]}';
