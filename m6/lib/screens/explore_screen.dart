import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../explore/explore_category_screen.dart';
import '../explore/explore_data.dart';
import '../style/app_colors.dart';

/// تب «اکسپلور» — دقیقاً شبیهِ صفحه‌ی Explore تیندر: یه گریدِ دوستونه‌ی
/// تخت از تایل‌های خاکستریِ تیره، هرکدوم یه ایموجیِ بزرگ و عنوان؛ با تپ روی هر تایل، استکِ سواپِ مخصوصِ همون دسته باز می‌شه.
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
      color: AppDark.bg,
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'با آدم‌هایی با اهدافِ مشابه آشنا شو',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                ),
              ),
            ),
            // لیستِ دسته‌ها از پنلِ ادمین میاد (ExploreConfig)؛ وقتی bootstrap نسخه‌ی جدید گرفت
            // همین‌جا خودش دوباره ساخته می‌شه.
            AnimatedBuilder(
              animation: ExploreConfig.instance,
              builder: (context, _) {
                final cats = ExploreConfig.instance.categories;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final cat = cats[i];
                        return _ExploreTile(category: cat, onTap: () => _openCategory(context, cat));
                      },
                      childCount: cats.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// تایلِ گریدِ اکسپلور — کارتِ خاکستریِ تیره‌ی گردگوشه، با یه ایموجیِ بزرگ
/// بالا و ردیفِ عنوان/عدد پایین، دقیقاً شبیهِ تایل‌های Explore تیندر.
class _ExploreTile extends StatelessWidget {
  final ExploreCategory category;
  final VoidCallback onTap;
  const _ExploreTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF24201F),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    category.imageAsset,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    // تا وقتی عکسِ سه‌بعدیِ این دسته اضافه نشده، ایموجیِ ساده
                    // نشون داده می‌شه که چیزی نشکنه.
                    errorBuilder: (context, error, stackTrace) => Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 54),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
