import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../swipe/swipe_style.dart';
import 'explore_screen.dart';
import 'matches_screen.dart';
import 'profile_home_screen.dart';
import 'swipe_screen.dart';

/// صفحه‌ی اصلی اپ — پوسته‌ی سبک تیندر با نوار پایین:
/// سواپ | اکسپلور | لایک‌ها | چت | پروفایل
///
/// - «سواپ» کامل ساخته شده (lib/screens/swipe_screen.dart).
/// - «چت» فعلاً همون صفحه‌ی متچ‌هاست (با تم تیره).
/// - «پروفایل» دکمه‌های قبلی صفحه‌ی اصلی (ویرایش پروفایل، عکس‌های خصوصی،
///   خروج) رو داره.
/// - «اکسپلور» ساخته شده (lib/screens/explore_screen.dart) — دسته‌بندیِ
///   نیتِ رابطه + علاقه/سبکِ زندگی، شبیهِ Explore تیندر.
/// - «لایک‌ها» فعلاً placeholder‌ه.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _swipeTab = 0;
  static const int _likesTab = 2;
  static const int _chatTab = 3;

  int _index = _swipeTab;
  final Set<int> _visited = {_swipeTab};
  int _chatRefresh = 0;

  // هنوز API‌ای برای «کی لایکم کرده» / «اکسپلور» نداریم؛ وقتی اضافه شد
  // این دو مقدار رو وصل کن تا نشونه‌ی قرمز نوار پایین (مثل تیندر) نشون داده بشه.
  final int _likesCount = 0;
  final bool _exploreDot = false;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _visited.add(i);
      if (i == _chatTab) _chatRefresh++; // متچ‌های جدید دوباره لود بشن
    });
  }

  Widget _lazy(int i, Widget Function() build) =>
      _visited.contains(i) ? build() : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: kSwipeTextDirection,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: _index,
            children: [
              SwipeScreen(onOpenMatches: () => _select(_chatTab)),
              _lazy(1, () => const ExploreScreen()),
              _lazy(
                2,
                () => const _ComingSoonTab(
                  icon: Icons.favorite_border,
                  title: 'لایک‌ها',
                  subtitle: 'به‌زودی می‌تونی ببینی کی لایکت کرده.',
                ),
              ),
              _lazy(
                _chatTab,
                () => Theme(
                  data: ThemeData.dark().copyWith(
                    scaffoldBackgroundColor: Colors.black,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  child: MatchesScreen(
                    key: ValueKey<int>(_chatRefresh),
                    onOpenLikes: () => _select(_likesTab),
                  ),
                ),
              ),
              _lazy(4, () => const ProfileHomeScreen()),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            index: _index,
            onTap: _select,
            likesCount: _likesCount,
            exploreDot: _exploreDot,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// نوار پایین
// -----------------------------------------------------------------------

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavSpec(this.icon, this.activeIcon, this.label);
}

const List<_NavSpec> _navItems = [
  _NavSpec(Icons.local_fire_department_outlined, Icons.local_fire_department, 'سواپ'),
  _NavSpec(Icons.explore_outlined, Icons.explore, 'اکسپلور'),
  _NavSpec(Icons.favorite_border, Icons.favorite, 'لایک‌ها'),
  _NavSpec(Icons.chat_bubble_outline, Icons.chat_bubble, 'چت'),
  _NavSpec(Icons.person_outline, Icons.person, 'پروفایل'),
];

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final int likesCount;
  final bool exploreDot;

  const _BottomNav({
    required this.index,
    required this.onTap,
    required this.likesCount,
    required this.exploreDot,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: SwipeMetrics.navHeight,
          child: Row(
            children: [
              for (int i = 0; i < _navItems.length; i++)
                Expanded(
                  child: _NavItem(
                    spec: _navItems[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                    badgeCount: i == 2 ? likesCount : 0,
                    dot: i == 1 && exploreDot,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
  final bool dot;

  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.badgeCount,
    required this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : SwipeColors.navUnselected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(selected ? spec.activeIcon : spec.icon, size: 28, color: color),
                if (badgeCount > 0)
                  PositionedDirectional(
                    end: -6,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SwipeColors.badgeRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                if (dot)
                  PositionedDirectional(
                    end: 2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: SwipeColors.badgeRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// تب‌های ساده
// -----------------------------------------------------------------------

class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ComingSoonTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: const Color(0xFF6E6E72)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

