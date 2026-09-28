import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/chat_models.dart';
import '../models/profile_models.dart';
import '../widgets/profile_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
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

  Future<void> _openProfile() async {
    HapticFeedback.lightImpact();
    try {
      final results = await Future.wait([
        ApiClient.fetchDiscoveryProfile(widget.match.publicId),
        ApiClient.fetchProfileOptions(),
      ]);
      final candidate = results[0] as DiscoveryCandidate;
      final options = results[1] as ProfileOptions;
      if (!mounted) return;

      final promptTextMap = {for (final p in options.prompts) p.id: p.text};
      final interestLabelMap = {for (final i in options.interests) i.id: i.label};

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => ProfileDetailSheet(
            candidate: candidate,
            promptTextMap: promptTextMap,
            interestLabelMap: interestLabelMap,
            scrollController: scrollController,
            // onSwipe عمداً پاس داده نمی‌شه — چون از قبل متچ شدین، دکمه‌ی
            // لایک/رد این‌جا معنی نداره.
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('دریافت پروفایل با مشکل مواجه شد.')));
      }
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _openProfile,
          child: Text(widget.match.name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'مشاهده‌ی پروفایل',
            onPressed: _openProfile,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
        ]),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('هنوز پیامی نیست — اولین قدم رو بردار!'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        return Align(
          alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: m.fromMe ? Colors.pink.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(m.body),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'پیامت رو بنویس...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
