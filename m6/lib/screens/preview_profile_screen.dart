import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../style/app_colors.dart';
import '../widgets/my_profile_detail_sheet.dart';

/// «Preview Profile» — عکس ۲ تا ۸. دقیقاً همون رفتار کارت‌های Discovery:
/// تپ نیمه‌ی راست/چپ عکس = عکس بعدی/قبلی (با نقطه‌های بالا)، و فلش کنار
/// اسم یه شیت قابل‌کشیدن با بقیه‌ی اطلاعات پروفایل باز می‌کنه.
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

  List<String> get _urls => widget.profile.photos.map((p) => '$backendBaseUrl${p.url}').toList();

  void _onTapUp(TapUpDetails d, double width) {
    final count = _urls.length;
    if (count <= 1) return;
    final goNext = d.localPosition.dx >= width / 2;
    final next = _index + (goNext ? 1 : -1);
    if (next < 0 || next >= count) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _index = next);
  }

  void _openDetail() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDark.cardAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: MyProfileDetailSheet(
            profile: widget.profile,
            promptTextMap: widget.promptTextMap,
            interestLabelMap: widget.interestLabelMap,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        appBar: AppBar(
          backgroundColor: AppDark.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('پیش‌نمایش پروفایل', style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (urls.isEmpty)
                      Container(
                        color: AppDark.card,
                        child: const Center(child: Icon(Icons.person, size: 110, color: AppDark.muted)),
                      )
                    else
                      Image.network(urls[_index.clamp(0, urls.length - 1)], fit: BoxFit.cover),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 220,
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
                      right: 20,
                      bottom: 20,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.profile.name} ${widget.profile.age}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                            ),
                          ),
                          GestureDetector(
                            onTap: _openDetail,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
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
      ),
    );
  }
}
