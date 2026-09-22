import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../style/app_colors.dart';
import '../widgets/my_profile_detail_sheet.dart';

/// «Preview Profile» — همون‌طوری که تو تیندر واقعیه: یه صفحه‌ی پیمایش‌پذیرِ
/// یکپارچه، نه یه شیت روی عکس. بالا کارت عکس (تو یه باکس مشکی با حاشیه‌ی
/// خاکستریِ پس‌زمینه)، زیرش هدر اسم + دکمه‌ی پایین‌فلش، و زیرترش باکس‌های
/// اطلاعات. با زدن فلش بالا (روی خود عکس) صفحه به همون‌جا اسکرول می‌شه؛ با
/// زدن دکمه‌ی پایین‌فلشِ هدر، برمی‌گرده بالا و عکس کامل دیده می‌شه.
class PreviewProfileScreen extends StatefulWidget {
  final MyProfile profile;
  final Map<String, String> promptTextMap;
  final Map<String, String> interestLabelMap;

  const PreviewProfileScreen({
    super.key,
    required this.profile,
    required this.promptTextMap,
    required this.interestLabelMap,
  });

  @override
  State<PreviewProfileScreen> createState() => _PreviewProfileScreenState();
}

class _PreviewProfileScreenState extends State<PreviewProfileScreen> {
  int _index = 0;
  final _scrollController = ScrollController();

  static const double _photoCardHeight = 560;

  List<String> get _urls => widget.profile.photos.map((p) => '$backendBaseUrl${p.url}').toList();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails d, double width) {
    final count = _urls.length;
    if (count <= 1) return;
    // توجه: عمداً برعکسِ تیندرِ اصلی (که چپ‌به‌راست/LTR‌ـه) پیاده شده — چون
    // تو اپ ماست که کاملاً راست‌به‌چپه، لمس نیمه‌ی راستِ عکس باید «قبلی» و
    // نیمه‌ی چپ باید «بعدی» باشه تا با جهت طبیعی خوندن هم‌خونی داشته باشه.
    final goNext = d.localPosition.dx < width / 2;
    final next = _index + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _index = next);
  }

  void _scrollToDetails() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      _photoCardHeight,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // پس‌زمینه‌ی خاکستریِ تیره پشت کارت مشکیِ عکس («یه باکس مشکی که یه
        // خاکستری پس‌زمینشه» طبق توضیح کاربر).
        backgroundColor: AppDark.cardAlt,
        body: SafeArea(
          bottom: false,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('پیش‌نمایش پروفایل', style: TextStyle(color: Colors.white, fontSize: 17)),
                ]),
              ),
              SizedBox(
                height: _photoCardHeight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (urls.isEmpty)
                            Container(
                              color: Colors.black,
                              child: const Center(child: Icon(Icons.person, size: 110, color: AppDark.muted)),
                            )
                          else
                            Image.network(urls[_index.clamp(0, urls.length - 1)], fit: BoxFit.cover),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 200,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0x00000000), Color(0xCC000000)],
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                                          color: i == _index ? Colors.white : const Color(0x66FFFFFF),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 20,
                            right: 16,
                            bottom: 18,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${widget.profile.name} ${widget.profile.age}',
                                    style:
                                        const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _scrollToDetails,
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.keyboard_arrow_up, size: 30, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${widget.profile.name}، ${widget.profile.age}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    GestureDetector(
                      onTap: _scrollToTop,
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: MyProfileDetailSheet(
                  profile: widget.profile,
                  promptTextMap: widget.promptTextMap,
                  interestLabelMap: widget.interestLabelMap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
