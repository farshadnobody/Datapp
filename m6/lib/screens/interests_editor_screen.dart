import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';

const int kMaxInterests = 10;

/// صفحه‌ی «Interests» — دقیقاً مثل تیندر: بالا تگ‌های انتخاب‌شده (با
/// ضربدر برای حذف)، پایینش سرچ، و بعدش دسته‌بندی‌ها با «نمایش بیشتر».
/// خروجی: Set<String> نهایی (با زدن دکمه‌ی برگشت پاپ می‌شه).
class InterestsEditorScreen extends StatefulWidget {
  final Set<String> initialInterests;
  const InterestsEditorScreen({super.key, required this.initialInterests});

  @override
  State<InterestsEditorScreen> createState() => _InterestsEditorScreenState();
}

class _InterestsEditorScreenState extends State<InterestsEditorScreen> {
  late final Set<String> _selected = {...widget.initialInterests};
  final Set<String> _expanded = {};
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < kMaxInterests) {
        _selected.add(id);
      }
    });
  }

  String _labelOf(String id) {
    for (final cat in kInterestCategories) {
      final l = optionLabel(cat.items, id);
      if (l != null) return l;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(_selected),
                    ),
                    const Expanded(
                      child: Text('علاقه‌مندی‌ها',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    Text('${_selected.length} از $kMaxInterests', style: const TextStyle(color: AppDark.muted)),
                  ],
                ),
              ),
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selected
                        .map((id) => Chip(
                              label: Text(_labelOf(id)),
                              labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                              backgroundColor: Colors.white,
                              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.black),
                              onDeleted: () => _toggle(id),
                            ))
                        .toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppDark.muted),
                    hintText: 'جستجو',
                    hintStyle: const TextStyle(color: AppDark.muted),
                    filled: true,
                    fillColor: AppDark.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: kInterestCategories.map((cat) {
                    List<OptionItem> items = cat.items;
                    if (query.isNotEmpty) {
                      items = items.where((i) => i.label.contains(query)).toList();
                      if (items.isEmpty) return const SizedBox.shrink();
                    }
                    final expanded = _expanded.contains(cat.id) || query.isNotEmpty;
                    final visible = expanded ? items : items.take(kInterestPreviewCount);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.title,
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: visible.map((item) {
                              final selected = _selected.contains(item.id);
                              return InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _toggle(item.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: selected ? Colors.white : AppDark.border, width: 1.2),
                                    color: selected ? Colors.white : Colors.transparent,
                                  ),
                                  child: Text(item.label,
                                      style: TextStyle(
                                          color: selected ? Colors.black : Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                              );
                            }).toList(),
                          ),
                          if (query.isEmpty && items.length > kInterestPreviewCount)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: InkWell(
                                onTap: () => setState(() {
                                  if (_expanded.contains(cat.id)) {
                                    _expanded.remove(cat.id);
                                  } else {
                                    _expanded.add(cat.id);
                                  }
                                }),
                                child: Row(
                                  children: [
                                    const Expanded(child: Divider(color: AppDark.border, height: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(expanded ? 'نمایش کمتر' : 'نمایش بیشتر',
                                          style: const TextStyle(color: AppDark.muted, fontSize: 13)),
                                    ),
                                    const Expanded(child: Divider(color: AppDark.border, height: 1)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
