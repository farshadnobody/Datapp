import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../swipe/swipe_style.dart';
import 'explore_screen.dart';
import 'likes_screen.dart';
import 'matches_screen.dart';
import 'profile_home_screen.dart';
import 'swipe_screen.dart';
import '../subscription/subscription_state.dart';
import '../subscription/premium_paywall.dart';
import '../promo/promo_overlay.dart';
import '../promo/promo_service.dart';
import '../bootstrap/bootstrap_service.dart';
import '../realtime/realtime_service.dart';
import '../swipe/swipe_outbox.dart';
import '../chat/conversations_store.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _swipeTab = 0;
  static const int _likesTab = 2;
  static const int _chatTab = 3;
  static const List<String> _screenKeys = ['swipe', 'explore', 'likes', 'chat', 'profile'];

  int _index = _swipeTab;
  final Set<int> _visited = {_swipeTab};
  int _chatRefresh = 0;
  int _likesRefresh = 0;

  // هر بار که کاربر (دوباره) وارد تب سواپ می‌شه یکی زیاد می‌شه؛ صفحه‌ی سواپ
  // بر اساسش وضعیتِ لوکیشن رو چک می‌کنه (بدون این‌که لیست دوباره لود بشه).
  final ValueNotifier<int> _swipeEnters = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // یه اتصالِ زنده برای کلِ اپ + یه «درخواستِ اولیه» (به‌جای ۵ تا ۶ درخواستِ جدا).
    RealtimeService.instance.start();
    BootstrapService.instance.markColdStart();
    BootstrapService.instance.refresh(force: true);
    // لیستِ چت‌ها: یه بار موقعِ باز شدنِ اپ (تا اون لحظه از فایلِ ذخیره‌شده)، بعدش فقط با
    // رویدادهای سرور عوض می‌شه.
    ConversationsStore.instance.start();
    SubscriptionState.instance.addListener(_onSubscriptionChanged);
    AppCounters.instance.addListener(_onCountersChanged);
    _rtSub = RealtimeService.instance.events.listen(_onRealtimeEvent);
  }

  StreamSubscription? _rtSub;

  // «کثیف» یعنی از آخرین باری که این تب لود شد چیزی عوض شده؛ تب فقط وقتی دوباره
  // لود می‌شه که کثیف باشه (یا WebSocket وصل نباشه)، نه با هر ورود.
  bool _chatDirty = true;
  bool _likesDirty = true;

  void _onCountersChanged() {
    if (mounted) setState(() {});
  }

  void _onRealtimeEvent(RealtimeEvent e) {
    if (!mounted) return;
    // چت‌ها: ConversationsStore خودش با رویدادها (پیام، متچ، آنمتچ...) به‌روز می‌شه.
    // لایک‌ها: LikesStore (برای اشتراکی‌ها) و BootstrapService رویدادها رو مدیریت می‌کنن؛
    // صفحه‌ی لایک‌ها هم به همون‌ها گوش می‌ده. این‌جا کارِ اضافه‌ای لازم نیست.
  }

  bool _lastPremium = SubscriptionState.instance.isPremium;

  void _onSubscriptionChanged() {
    // فقط وقتی «اشتراکی بودن» عوض شد (نه با هر لایک که شمارنده‌ی سهمیه تغییر می‌کنه).
    final now = SubscriptionState.instance.isPremium;
    if (now == _lastPremium) return;
    _lastPremium = now;
    _likesDirty = true; // با عوض شدنِ اشتراک، لیستِ لایک‌ها (قفل/باز) باید دوباره بیاد
    BootstrapService.instance.refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // از صفحه‌ی پرداخت/تنظیمات برگشتی: وضعیتِ اشتراک رو تازه کن.
    if (state == AppLifecycleState.resumed) {
      // برگشت از پس‌زمینه: یه درخواستِ اولیه (حداقل ۲۰ ثانیه فاصله). اتصالِ زنده خودش
      // دوباره وصل می‌شه و اگه تو این مدت قطع بوده، لیست‌ها رو کثیف حساب می‌کنیم.
      if (!RealtimeService.instance.connected.value) {
        _chatDirty = true;
        _likesDirty = true;
      }
      BootstrapService.instance.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SubscriptionState.instance.removeListener(_onSubscriptionChanged);
    AppCounters.instance.removeListener(_onCountersChanged);
    _rtSub?.cancel();
    _swipeEnters.dispose();
    super.dispose();
  }

  // هنوز API‌ای برای «کی لایکم کرده» / «اکسپلور» نداریم؛ وقتی اضافه شد
  // این دو مقدار رو وصل کن تا نشونه‌ی قرمز نوار پایین (مثل تیندر) نشون داده بشه.
  int get _likesCount => AppCounters.instance.likesCount;
  final bool _exploreDot = false;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    // از سواپ/اکسپلور رفتیم بیرون: ردهای جمع‌شده رو بفرست.
    if (_index <= 1 && i > 1) SwipeOutbox.instance.flush();
    setState(() {
      _index = i;
      _visited.add(i);
      if (i == _swipeTab) _swipeEnters.value++;
      // اتصالِ زنده نداریم: به‌روزرسانیِ رویدادها ممکنه از دست رفته باشه، پس یه بار از سرور.
      if (i == _chatTab && !RealtimeService.instance.connected.value) {
        ConversationsStore.instance.refresh();
      }
      if (i == _likesTab) {
        if (_likesDirty) {
          _likesRefresh++; // مثلاً اشتراک عوض شده: قفل/بازِ لیست
          _likesDirty = false;
        }
        // رایگان: شمارنده‌ی لایک‌ها از یه ساعت قدیمی‌تره؟ بگیر (bootstrap فقط همین‌وقت می‌فرستدش).
        if (!SubscriptionState.instance.isPremium && AppCounters.instance.stale) {
          BootstrapService.instance.refresh();
        }
      }
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
          body: Stack(
            fit: StackFit.expand,
            children: [
          IndexedStack(
            index: _index,
            children: [
              SwipeScreen(
                onOpenMatches: () => _select(_chatTab),
                enterSignal: _swipeEnters,
              ),
              _lazy(1, () => const ExploreScreen()),
              _lazy(
                2,
                () => Theme(
                  data: ThemeData.dark().copyWith(
                    scaffoldBackgroundColor: Colors.black,
                  ),
                  child: ListenableBuilder(
                    listenable: SubscriptionState.instance,
                    builder: (context, _) => LikesScreen(
                      key: ValueKey<String>(
                          '$_likesRefresh-${SubscriptionState.instance.isPremium}'),
                      isPremium: SubscriptionState.instance.isPremium,
                      onUpgrade: () => openUpgrade(context),
                    ),
                  ),
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
              // پاپ‌آپ‌ها و باکس‌های شناورِ تبلیغاتی (از پنلِ ادمین)
              PromoHost(
                screen: _screenKeys[_index],
                onNavigate: (screen) {
                  final i = _screenKeys.indexOf(screen);
                  if (i >= 0) _select(i);
                },
              ),
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

