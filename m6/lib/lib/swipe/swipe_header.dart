import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'swipe_style.dart';

/// بنر سفید بالای صفحه تو حالت ۱ (مثل «Learning your type» تیندر).
///
/// متن اصلی تو پیام کاربر: «۲۰ نفر رو باید لایک یا رد کنید تا سبک شما آموخته
/// شود» — این‌جا خودمونی‌تر و کوتاه‌تر شده تا تو دو خط جا بشه.
class SwipeLearningBanner extends StatelessWidget {
  final int remaining;
  const SwipeLearningBanner({super.key, required this.remaining});

  static const String title = 'داریم سلیقه‌ات رو یاد می‌گیریم';

  static String subtitle(int n) => '$n نفر دیگه رو لایک یا رد کن تا شروع کنیم';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: SwipeColors.bannerRing, width: 4),
            ),
            child: const Icon(Icons.favorite, size: 14, color: SwipeColors.bannerHeart),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SwipeColors.bannerTitle,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    subtitle(remaining),
                    key: ValueKey<int>(remaining),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SwipeColors.bannerSubtitle,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار بالای صفحه تو حالت ۲: فیلتر، «برای تو / نزدیک»، و صاعقه‌ی Boost.
class SwipeTopBar extends StatelessWidget {
  /// 0 = برای تو، 1 = نزدیک
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onFilters;
  final VoidCallback onBoost;

  const SwipeTopBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onFilters,
    required this.onBoost,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onFilters();
          },
          icon: const Icon(Icons.tune, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 2),
        _tab('برای تو', 0),
        const SizedBox(width: 4),
        _tab('نزدیک', 1),
        const Spacer(),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onBoost();
          },
          icon: const Icon(Icons.bolt, color: SwipeColors.bolt, size: 32),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _tab(String label, int index) {
    final selected = selectedTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        onTabChanged(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF2E2E31) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D0D2),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
