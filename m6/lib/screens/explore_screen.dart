import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../explore/explore_category_screen.dart';
import '../explore/explore_data.dart';
import '../swipe/swipe_style.dart';

/// تب «اکسپلور» — دقیقاً شبیهِ صفحه‌ی Explore تیندر: به‌جایِ یه فیدِ پیوسته،
/// یه سری تایل که هرکدوم به استکِ سواپِ مخصوصِ خودشون می‌رن.
///
/// هدر دو بخش داره:
/// - «دسته‌های نیتِ رابطه» (معادلِ My Vibe تیندر) — ردیفِ افقیِ چیپ.
/// - «دسته‌های علاقه و سبکِ زندگی» (معادلِ Passions تیندر) — گریدِ کارت‌های
///   رنگی.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  void _openCategory(BuildContext context, ExploreCategory category) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExploreCategoryScreen(category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(top: topPad > 0 ? 0 : 8),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'اکسپلور',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'دسته‌های نیتِ رابطه',
                subtitle: 'دنبالِ چه نوع رابطه‌ای‌ای؟ آدم‌های هم‌نیت رو ببین.',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: kIntentCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final cat = kIntentCategories[i];
                    return _IntentTile(category: cat, onTap: () => _openCategory(context, cat));
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'دسته‌های علاقه و سبکِ زندگی',
                subtitle: 'با آدم‌هایی که همون علایق رو دارن آشنا شو.',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final cat = kInterestLifestyleCategories[i];
                    return _InterestTile(category: cat, onTap: () => _openCategory(context, cat));
                  },
                  childCount: kInterestLifestyleCategories.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: SwipeColors.navUnselected, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// تایلِ بخشِ نیتِ رابطه — چیپِ بلندِ گردگوشه با آیکون و متن، شبیهِ کارت‌های
/// «My Vibe» تیندر.
class _IntentTile extends StatelessWidget {
  final ExploreCategory category;
  final VoidCallback onTap;
  const _IntentTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 128,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: category.gradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(category.icon, color: Colors.white, size: 26),
              Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تایلِ بخشِ علاقه/سبکِ زندگی — کارتِ گریدِ گرادیانتی با آیکونِ بزرگِ محو در
/// پس‌زمینه، شبیهِ تایل‌های Passion تیندر.
class _InterestTile extends StatelessWidget {
  final ExploreCategory category;
  final VoidCallback onTap;
  const _InterestTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: category.gradient,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -10,
                bottom: -14,
                child: Icon(category.icon, size: 84, color: Colors.white.withOpacity(0.16)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(category.icon, color: Colors.white, size: 24),
                    Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
