import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';

class IdentityResult {
  final List<String> genders;
  final bool showGenderOnProfile;
  final List<String> orientations;
  final bool showOrientationOnProfile;
  IdentityResult({
    required this.genders,
    required this.showGenderOnProfile,
    required this.orientations,
    required this.showOrientationOnProfile,
  });
}

/// شیت کوچیک «Identity» — دو ردیف که به دو صفحه‌ی تمام‌صفحه می‌رن.
Future<IdentityResult?> showIdentitySheet(
  BuildContext context, {
  required List<String> genders,
  required bool showGenderOnProfile,
  required List<String> orientations,
  required bool showOrientationOnProfile,
}) {
  var g = List<String>.from(genders);
  var showG = showGenderOnProfile;
  var o = List<String>.from(orientations);
  var showO = showOrientationOnProfile;
  bool changed = false;

  return showModalBottomSheet<IdentityResult?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppDark.cardAlt,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (context, setSheetState) {
        String genderSummary() => g.isEmpty ? 'انتخاب نشده' : (optionLabel(kGenderOptions, g.first) ?? g.first);
        String orientationSummary() =>
            o.isEmpty ? 'انتخاب نشده' : o.map((id) => optionLabel(kOrientationOptions, id) ?? id).join('، ');

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppDark.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('هویت', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(
                      changed
                          ? IdentityResult(
                              genders: g, showGenderOnProfile: showG, orientations: o, showOrientationOnProfile: showO)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('جنسیت', style: TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(genderSummary(), style: const TextStyle(color: AppDark.muted)),
                  const Icon(Icons.chevron_left, color: AppDark.muted),
                ],
              ),
              onTap: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (_) => GenderSelectScreen(initialGender: g.isEmpty ? null : g.first, showOnProfile: showG),
                  ),
                );
                if (result != null) {
                  setSheetState(() {
                    g = result['gender'] == null ? <String>[] : [result['gender'] as String];
                    showG = result['show'] as bool;
                    changed = true;
                  });
                }
              },
            ),
            const Divider(color: AppDark.border, height: 1, indent: 20, endIndent: 20),
            ListTile(
              title: const Text('گرایش جنسی', style: TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(orientationSummary(),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppDark.muted)),
                  ),
                  const Icon(Icons.chevron_left, color: AppDark.muted),
                ],
              ),
              onTap: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (_) => OrientationSelectScreen(initialOrientations: o, showOnProfile: showO),
                  ),
                );
                if (result != null) {
                  setSheetState(() {
                    o = List<String>.from(result['orientations'] as List);
                    showO = result['show'] as bool;
                    changed = true;
                  });
                }
              },
            ),
          ]),
        );
      }),
    ),
  );
}

/// صفحه‌ی «I Am» — تک‌انتخابی از بین مرد/زن/فراتر از دوجنسیتی.
class GenderSelectScreen extends StatefulWidget {
  final String? initialGender;
  final bool showOnProfile;
  const GenderSelectScreen({super.key, this.initialGender, required this.showOnProfile});

  @override
  State<GenderSelectScreen> createState() => _GenderSelectScreenState();
}

class _GenderSelectScreenState extends State<GenderSelectScreen> {
  String? _gender;
  late bool _show = widget.showOnProfile;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialGender;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        appBar: AppBar(
          backgroundColor: AppDark.bg,
          elevation: 0,
          title: const Text('جنسیت من', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop({'gender': _gender, 'show': _show}),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ...kGenderOptions.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RadioListTile<String>(
                    value: o.id,
                    groupValue: _gender,
                    activeColor: AppDark.accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.label, style: const TextStyle(color: Colors.white)),
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _gender = v);
                    },
                  ),
                )),
            const SizedBox(height: 12),
            const Divider(color: AppDark.border, height: 1),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppDark.accent,
              title: const Text('جنسیتم تو پروفایل نشون داده بشه', style: TextStyle(color: Colors.white)),
              value: _show,
              onChanged: (v) => setState(() => _show = v),
            ),
            const SizedBox(height: 8),
            const Text('بیشتر بدونید درباره‌ی ویژگی جنسیت تیندر.',
                style: TextStyle(color: AppDark.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// صفحه‌ی «Sexual Orientation» — چندانتخابی (حداکثر ۳).
class OrientationSelectScreen extends StatefulWidget {
  final List<String> initialOrientations;
  final bool showOnProfile;
  const OrientationSelectScreen({super.key, required this.initialOrientations, required this.showOnProfile});

  @override
  State<OrientationSelectScreen> createState() => _OrientationSelectScreenState();
}

class _OrientationSelectScreenState extends State<OrientationSelectScreen> {
  late final Set<String> _orientations = {...widget.initialOrientations};
  late bool _show = widget.showOnProfile;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        appBar: AppBar(
          backgroundColor: AppDark.bg,
          elevation: 0,
          title: const Text('گرایش جنسی', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).pop({'orientations': _orientations.toList(), 'show': _show}),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppDark.accent,
              title: const Text('گرایش جنسیم تو پروفایل نشون داده بشه', style: TextStyle(color: Colors.white)),
              value: _show,
              onChanged: (v) => setState(() => _show = v),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('تا ۳ تا انتخاب کن', style: TextStyle(color: AppDark.muted, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            ...kOrientationOptions.map((o) {
              final selected = _orientations.contains(o.id);
              return CheckboxListTile(
                value: selected,
                activeColor: AppDark.accent,
                contentPadding: EdgeInsets.zero,
                title: Text(o.label, style: const TextStyle(color: Colors.white)),
                subtitle: o.description == null
                    ? null
                    : Text(o.description!, style: const TextStyle(color: AppDark.muted, fontSize: 12)),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (v == true) {
                      if (_orientations.length < 3) _orientations.add(o.id);
                    } else {
                      _orientations.remove(o.id);
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
