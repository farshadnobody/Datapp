import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/chat_models.dart';
import '../style/app_colors.dart';
import '../widgets/safety_toolkit_sheet.dart';
import 'match_profile_screen.dart';

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
  WebSocketChannel? _channel;
  bool _sending = false;
  bool _hasText = false;

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

  Future<void> _load() async {
    try {
      final messages = await ApiClient.fetchMessages(widget.match.publicId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'دریافت پیام‌ها با مشکل مواجه شد.';
          _loading = false;
        });
      }
    }
  }

  // اگه اتصال زنده برقرار نشه یا قطع بشه، اپ همچنان با REST کار می‌کنه —
  // فقط پیام‌های جدید فوری نمیان، باید صفحه رو دستی رفرش کنی.
  void _connectSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiClient.webSocketUrl));
      _channel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event);
            if (data['type'] == 'message' && data['from'] == widget.match.publicId) {
              setState(() {
                _messages = [
                  ..._messages,
                  ChatMessage(
                    id: 0,
                    fromMe: false,
                    body: data['body'],
                    sentAt: DateTime.tryParse(data['sent_at']?.toString() ?? '') ??
                        DateTime.now(),
                  ),
                ];
              });
              _scrollToBottom();
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _sending = true);

    // خوش‌بینانه اضافه‌ش می‌کنیم (بدون منتظر موندن برای جواب سرور)؛ اگه
    // ارسال شکست خورد، برش می‌داریم.
    final optimistic = ChatMessage(id: -1, fromMe: true, body: text, sentAt: DateTime.now());
    setState(() => _messages = [..._messages, optimistic]);
    _scrollToBottom();

    try {
      await ApiClient.sendMessage(widget.match.publicId, text);
    } catch (e) {
      setState(() => _messages = _messages.where((m) => m != optimistic).toList());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ارسال پیام با مشکل مواجه شد.')));
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
        matchPublicId: widget.match.publicId, matchName: widget.match.name);
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
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
        itemCount: _messages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildMatchedHeader();
          final m = _messages[index - 1];
          final prev = index - 2 >= 0 ? _messages[index - 2] : null;
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
