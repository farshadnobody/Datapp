import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding/onboarding_data.dart';
import '../onboarding/language_options.dart';
import '../style/app_colors.dart';

// -----------------------------------------------------------------------
// اجزای مشترک
// -----------------------------------------------------------------------

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppDark.cardAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

/// هندل کوچیک بالای شیت (همون خط خاکستری وسط).
Widget _sheetHandle() {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(color: AppDark.border, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

Widget _sheetHeader({required String title, String? subtitle, required VoidCallback onDone, bool doneEnabled = true}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppDark.muted, fontSize: 13, height: 1.4)),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: doneEnabled ? onDone : null,
          child: Text('تمام',
              style: TextStyle(
                  color: doneEnabled ? Colors.white : AppDark.muted, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

Widget _pill({required String label, required bool selected, required VoidCallback onTap}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.white : AppDark.border, width: 1.2),
        color: selected ? Colors.white : Colors.transparent,
      ),
      // نکته: قبلاً وزن فونت گزینه‌ی انتخاب‌شده رو بولدتر می‌کردیم که باعث
      // می‌شد عرض پیل عوض بشه و گزینه‌ی کناری‌اش تو Wrap بپره ردیف بعد؛
      // برای همین وزن فونت همیشه ثابته و فقط رنگ/پس‌زمینه تغییر می‌کنه.
      child: Text(label,
          style: TextStyle(
              color: selected ? Colors.black : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
    ),
  );
}

// -----------------------------------------------------------------------
// قد
// -----------------------------------------------------------------------

Future<int?> showHeightSheet(BuildContext context, {int? initialCm}) {
  final controller = TextEditingController(text: initialCm?.toString() ?? '');
  return _showSheet<int?>(
    context,
    StatefulBuilder(builder: (context, setSheetState) {
      final value = int.tryParse(controller.text);
      final valid = value != null && value >= 100 && value <= 250;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(),
          _sheetHeader(
            title: 'قد',
            subtitle: 'همین الان فرصت خوبیه که قدت رو به پروفایلت اضافه کنی.',
            doneEnabled: controller.text.isEmpty || valid,
            onDone: () => Navigator.of(context).pop(valid ? value : null),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سانتی‌متر', style: TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'cm',
                    hintStyle: const TextStyle(color: AppDark.muted),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppDark.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (initialCm != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppDark.border),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(-1), // یعنی «حذف قد»
                  child: const Text('حذف قد'),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ]),
      );
    }),
  );
}

// -----------------------------------------------------------------------
// شغل
// -----------------------------------------------------------------------

Future<Map<String, String>?> showJobSheet(BuildContext context, {String? initialTitle, String? initialCompany}) {
  final titleController = TextEditingController(text: initialTitle ?? '');
  final companyController = TextEditingController(text: initialCompany ?? '');
  return _showSheet<Map<String, String>?>(
    context,
    Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        _sheetHeader(
          title: 'شغل',
          subtitle: 'کارت رو معرفی کن تا تصویر روشن‌تری از خودت بدی.',
          onDone: () => Navigator.of(context).pop({
            'title': titleController.text.trim(),
            'company': companyController.text.trim(),
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'عنوان شغلی',
                  hintStyle: const TextStyle(color: AppDark.muted),
                  filled: true,
                  fillColor: AppDark.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'شرکت یا حوزه‌ی کاری',
                  hintStyle: const TextStyle(color: AppDark.muted),
                  filled: true,
                  fillColor: AppDark.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ]),
    ),
  );
}

// -----------------------------------------------------------------------
// دنبال چه نوع رابطه‌ای هستی
// -----------------------------------------------------------------------

Future<String?> showLookingForSheet(BuildContext context, {String? initial}) {
  return _showSheet<String?>(
    context,
    SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        Row(
          children: [
            const Expanded(
              child: Text('دنبال چی هستی؟',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerRight,
          child: Text('اگه عوض بشه اشکالی نداره. یه چیزی برای همه هست.',
              style: TextStyle(color: AppDark.muted, fontSize: 13)),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: kLookingForOptions.map((o) {
            final selected = initial == o.id;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(o.id);
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppDark.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppDark.accent : AppDark.border, width: selected ? 2 : 1.2),
                ),
                child: Text(o.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected ? Colors.black : Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            );
          }).toList(),
        ),
      ]),
    ),
  );
}

// -----------------------------------------------------------------------
// Basics: برج، تحصیلات، بچه، سبک ارتباطی
// -----------------------------------------------------------------------

class BasicsResult {
  final String? zodiac;
  final String? educationLevel;
  final String? wantChildren;
  final String? communication;
  final String? loveLanguage;
  BasicsResult({this.zodiac, this.educationLevel, this.wantChildren, this.communication, this.loveLanguage});
}

Future<BasicsResult?> showBasicsSheet(
  BuildContext context, {
  String? zodiac,
  String? educationLevel,
  String? wantChildren,
  String? communication,
  String? loveLanguage,
}) {
  String? zodiacSel = zodiac;
  String? eduSel = educationLevel;
  String? childrenSel = wantChildren;
  String? commSel = communication;
  String? loveSel = loveLanguage;
  final zodiacItems = kAboutYouCategories.firstWhere((c) => c.id == 'zodiac').items;
  final commItems = kAboutYouCategories.firstWhere((c) => c.id == 'communication').items;
  final loveItems = kAboutYouCategories.firstWhere((c) => c.id == 'love_language').items;

  return _showSheet<BasicsResult?>(
    context,
    StatefulBuilder(builder: (context, setSheetState) {
      Widget group(String title, List<OptionItem> items, String? selected, ValueChanged<String?> onPick) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items
                    .map((o) => _pill(
                          label: o.label,
                          selected: selected == o.id,
                          onTap: () => setSheetState(() => onPick(selected == o.id ? null : o.id)),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      }

      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            _sheetHandle(),
            _sheetHeader(
              title: 'Basics',
              subtitle: 'با اضافه کردن اطلاعات بیشتر، بهترین خودتو نشون بده.',
              onDone: () => Navigator.of(context).pop(BasicsResult(
                zodiac: zodiacSel,
                educationLevel: eduSel,
                wantChildren: childrenSel,
                communication: commSel,
                loveLanguage: loveSel,
              )),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  group('برجت چیه؟', zodiacItems, zodiacSel, (v) => zodiacSel = v),
                  group('میزان تحصیلاتت چیه؟', kEducationOptions, eduSel, (v) => eduSel = v),
                  group('بچه می‌خوای؟', kWantChildrenOptions, childrenSel, (v) => childrenSel = v),
                  group('سبک ارتباطیت چیه؟', commItems, commSel, (v) => commSel = v),
                  group('محبت رو چطوری می‌گیری؟', loveItems, loveSel, (v) => loveSel = v),
                ],
              ),
            ),
          ],
        ),
      );
    }),
  );
}

// -----------------------------------------------------------------------
// Lifestyle: حیوون خونگی، مشروب، سیگار، ورزش، شبکه‌های اجتماعی
// -----------------------------------------------------------------------

Future<Map<String, String>?> showLifestyleSheet(BuildContext context, Map<String, String> initial) {
  final selections = Map<String, String>.from(initial);

  return _showSheet<Map<String, String>?>(
    context,
    StatefulBuilder(builder: (context, setSheetState) {
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            _sheetHandle(),
            _sheetHeader(
              title: 'Lifestyle',
              subtitle: 'با اضافه کردن سبک زندگیت، بهترین خودتو نشون بده.',
              onDone: () => Navigator.of(context).pop(selections),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: kLifestyleCategories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: cat.items
                              .map((item) => _pill(
                                    label: item.label,
                                    selected: selections[cat.id] == item.id,
                                    onTap: () => setSheetState(() {
                                      if (selections[cat.id] == item.id) {
                                        selections.remove(cat.id);
                                      } else {
                                        selections[cat.id] = item.id;
                                      }
                                    }),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

// -----------------------------------------------------------------------
// زبان‌هایی که بلدم
// -----------------------------------------------------------------------

Future<List<String>?> showLanguagesSheet(BuildContext context, List<String> initial) {
  final selected = List<String>.from(initial);
  final searchController = TextEditingController();

  return _showSheet<List<String>?>(
    context,
    StatefulBuilder(builder: (context, setSheetState) {
      final query = searchController.text.trim();
      final filtered = query.isEmpty
          ? kLanguageOptions
          : kLanguageOptions.where((o) => o.label.contains(query)).toList();

      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            _sheetHandle(),
            _sheetHeader(
              title: 'زبان‌هایی که بلدم',
              subtitle: 'تا ۵ زبان انتخاب کن و به پروفایلت اضافه کن (${selected.length} از ۵)',
              onDone: () => Navigator.of(context).pop(selected),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AppDark.muted),
                  hintText: 'جستجوی زبان',
                  hintStyle: const TextStyle(color: AppDark.muted),
                  filled: true,
                  fillColor: AppDark.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: filtered.map((o) {
                      final isSelected = selected.contains(o.id);
                      return _pill(
                        label: o.label,
                        selected: isSelected,
                        onTap: () => setSheetState(() {
                          if (isSelected) {
                            selected.remove(o.id);
                          } else if (selected.length < 5) {
                            selected.add(o.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }),
  );
}
