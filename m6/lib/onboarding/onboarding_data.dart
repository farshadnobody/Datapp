// داده‌های سؤال‌های اونبوردینگ (سبک تیندر).
//
// لیست‌های «_kDefault…» پیش‌فرضِ داخلِ اپن (وقتی هنوز چیزی از سرور نرسیده یا آفلاینی).
// لیست‌هایی که صفحه‌ها می‌خونن (kGenderOptions، kLookingForOptions و ...) متغیرن: وقتی
// bootstrap «گزینه‌های پروفایل» رو از سرور گرفت (فقط اگه نسخه‌اش عوض شده باشه)،
// [applyProfileOptionOverrides] نامِ نمایشی/توضیح رو با تغییرهای پنلِ ادمین جایگزین می‌کنه و
// گزینه‌های «مخفی» رو از لیستِ انتخاب برمی‌داره. شناسه‌ها هیچ‌وقت عوض نمی‌شن.

class OptionItem {
  final String id;
  final String label;
  final String? description; // زیرنویس توضیحی (مثل جهت‌گیری جنسی تو تیندر)
  const OptionItem(this.id, this.label, [this.description]);
}

class OptionCategory {
  final String id;
  final String title;
  final List<OptionItem> items;
  const OptionCategory(this.id, this.title, this.items);
}

// تو مرحله‌ی «به چی علاقه داری»، هر دسته اول فقط همین تعداد تگ اول رو نشون
// می‌ده و بقیه پشت دکمه‌ی «نمایش بیشتر» قایم می‌شن (دقیقاً رفتار تیندر).
// برای اضافه کردن تگ‌های بیشتر (هم برای حالت جمع‌شده، هم برای حالت باز)،
// کافیه به لیست items همون دسته‌ی موردنظر تو _kDefaultInterestCategories زیر
// OptionItem جدید اضافه کنی — پنج‌تای اول خودکار می‌شن حالت جمع‌شده.
const int kInterestPreviewCount = 5;

// مرحله‌ی جنسیت
const List<OptionItem> _kDefaultGenderOptions = [
  OptionItem('man', 'مرد'),
  OptionItem('woman', 'زن'),
  OptionItem('beyond_binary', 'فراتر از دوجنسیتی'),
];

// مرحله‌ی گرایش جنسی
const List<OptionItem> _kDefaultOrientationOptions = [
  OptionItem('straight', 'استریت', 'کسی که فقط به جنس مخالف جذب می‌شه'),
  OptionItem('gay', 'گی', 'کسی که به هم‌جنس خودش جذب می‌شه'),
  OptionItem('lesbian', 'لزبین', 'زنی که از نظر عاطفی/جنسی به زن دیگه جذب می‌شه'),
  OptionItem('bisexual', 'بایسکشوال', 'کسی که به بیش از یک جنسیت جذب می‌شه'),
  OptionItem('asexual', 'اِیسکشوال', 'کسی که جذابیت جنسی رو تجربه نمی‌کنه'),
  OptionItem('demisexual', 'دمی‌سکشوال', 'جذابیت جنسی فقط بعد از ارتباط عاطفی قوی'),
  OptionItem('pansexual', 'پن‌سکشوال', 'جذابیت عاطفی/جنسی بدون توجه به جنسیت طرف'),
  OptionItem('queer', 'کوییر', 'اصطلاحی چتر برای طیفی از گرایش‌ها و هویت‌ها'),
  OptionItem('questioning', 'در حال کشف', 'کسی که در حال کشف گرایش/هویت جنسی خودشه'),
  OptionItem('not_listed', 'تو لیست نیست', 'بگو دقیقاً چی کم داره'),
];

// مرحله‌ی «به دنبال دیدن چه کسانی هستی»
const List<OptionItem> _kDefaultSeeingOptions = [
  OptionItem('men', 'مردها'),
  OptionItem('women', 'زن‌ها'),
  OptionItem('beyond_binary', 'فراتر از دوجنسیتی'),
  OptionItem('everyone', 'همه'),
];

// مرحله‌ی «دنبال چه نوع رابطه‌ای هستی»
const List<OptionItem> _kDefaultLookingForOptions = [
  OptionItem('long_term', 'رابطه‌ی جدی'),
  OptionItem('long_term_open_short', 'جدی، ولی به کوتاه‌مدت هم باز'),
  OptionItem('short_term_open_long', 'کوتاه‌مدت، ولی به جدی هم باز'),
  OptionItem('short_term_fun', 'رابطه‌ی کوتاه و بی‌دغدغه'),
  OptionItem('new_friends', 'دوست‌یابی'),
  OptionItem('figuring_out', 'هنوز مطمئن نیستم'),
];

// مرحله‌ی تحصیلات
const List<OptionItem> _kDefaultEducationOptions = [
  OptionItem('high_school', 'دیپلم'),
  OptionItem('in_college', 'دانشجوی کارشناسی'),
  OptionItem('bachelors', 'کارشناسی'),
  OptionItem('in_grad_school', 'دانشجوی تحصیلات تکمیلی'),
  OptionItem('masters', 'کارشناسی ارشد'),
  OptionItem('phd', 'دکترا'),
  OptionItem('trade_school', 'فنی‌حرفه‌ای'),
  OptionItem('prefer_not_to_say', 'ترجیح می‌دم نگم'),
];

// مرحله‌ی سبک زندگی — هر دسته تک‌انتخابیه
const List<OptionCategory> _kDefaultLifestyleCategories = [
  OptionCategory('drinking', 'چقدر مشروب می‌خوری؟', [
    OptionItem('not_for_me', 'اصلاً'),
    OptionItem('sober', 'ترک کردم'),
    OptionItem('sober_curious', 'دارم کم می‌کنم'),
    OptionItem('special_occasions', 'فقط مناسبت‌های خاص'),
    OptionItem('socially', 'دورهمی‌ها'),
    OptionItem('most_nights', 'اکثر شب‌ها'),
  ]),
  OptionCategory('smoking', 'چقدر سیگار می‌کشی؟', [
    OptionItem('non_smoker', 'اصلاً نمی‌کشم'),
    OptionItem('social_smoker', 'گاهی تو جمع'),
    OptionItem('smoker_when_drinking', 'فقط وقتی مشروب می‌خورم'),
    OptionItem('smoker', 'می‌کشم'),
    OptionItem('trying_to_quit', 'دارم ترک می‌کنم'),
  ]),
  OptionCategory('workout', 'ورزش می‌کنی؟', [
    OptionItem('everyday', 'هرروز'),
    OptionItem('often', 'اکثر روزها'),
    OptionItem('sometimes', 'گاهی وقت‌ها'),
    OptionItem('never', 'هیچ‌وقت'),
  ]),
  OptionCategory('pets', 'حیوون خونگی داری؟', [
    OptionItem('dog', 'سگ'),
    OptionItem('cat', 'گربه'),
    OptionItem('reptile', 'خزنده'),
    OptionItem('amphibian', 'دوزیست'),
    OptionItem('bird', 'پرنده'),
    OptionItem('fish', 'ماهی'),
    OptionItem('no_pet_but_love', 'ندارم ولی دوست دارم'),
    OptionItem('other', 'چیز دیگه'),
    OptionItem('turtle', 'لاک‌پشت'),
    OptionItem('hamster', 'همستر'),
    OptionItem('rabbit', 'خرگوش'),
    OptionItem('pet_free', 'ترجیح می‌دم نداشته باشم'),
    OptionItem('all_the_pets', 'همه رو دوست دارم'),
    OptionItem('want_a_pet', 'می‌خوام بگیرم'),
    OptionItem('allergic', 'حساسیت دارم'),
  ]),
  // این دسته تو مرحله‌ی اونبوردینگ نبود، ولی تو باتم‌شیت «Lifestyle» صفحه‌ی
  // پروفایل هست (بعد از «ورزش می‌کنی؟») — طبق اسکرین‌شات‌های تیندر.
  OptionCategory('social_media', 'چقدر تو شبکه‌های اجتماعی فعالی؟', [
    OptionItem('influencer', 'اینفلوئنسرم'),
    OptionItem('socially_active', 'فعالم'),
    OptionItem('off_the_grid', 'اصلاً نیستم'),
    OptionItem('passive_scroller', 'فقط اسکرول می‌کنم'),
  ]),
];

// مرحله‌ی «بچه می‌خوای؟» — تو باتم‌شیت «Basics» صفحه‌ی پروفایل کنار برج و
// تحصیلات و سبک ارتباطی میاد. تو فلوی اونبوردینگ فعلاً پرسیده نمی‌شه.
const List<OptionItem> _kDefaultWantChildrenOptions = [
  OptionItem('want_children', 'بچه می‌خوام'),
  OptionItem('dont_want_children', 'بچه نمی‌خوام'),
  OptionItem('have_and_want_more', 'دارم و بازم می‌خوام'),
  OptionItem('have_dont_want_more', 'دارم و دیگه نمی‌خوام'),
  OptionItem('not_sure', 'هنوز مطمئن نیستم'),
];

/// برچسب یه id رو از یه لیست OptionItem پیدا می‌کنه؛ اگه نبود null.
/// جای این‌که هر فایل جدا همین تابع رو دوباره بنویسه، یه بار همین‌جاست.
String? optionLabel(List<OptionItem> items, String? id) {
  if (id == null) return null;
  for (final i in items) {
    if (i.id == id) return i.label;
  }
  // گزینه‌ای که ادمین مخفی کرده تو لیستِ انتخاب نیست، ولی مقدارِ قبلاً ذخیره‌شده‌ی کاربرها
  // باید همچنان با نامش نشون داده بشه.
  return _hiddenOptionLabels[id];
}

/// id → نامِ نمایشیِ گزینه‌های مخفی‌شده (فقط برای نمایشِ مقدارهای ذخیره‌شده).
final Map<String, String> _hiddenOptionLabels = {};

// لیست‌هایی که صفحه‌ها می‌خونن؛ پیش‌فرض همون لیستِ داخلِ اپ.
List<OptionItem> kGenderOptions = _kDefaultGenderOptions;
List<OptionItem> kOrientationOptions = _kDefaultOrientationOptions;
List<OptionItem> kSeeingOptions = _kDefaultSeeingOptions;
List<OptionItem> kLookingForOptions = _kDefaultLookingForOptions;
List<OptionItem> kEducationOptions = _kDefaultEducationOptions;
List<OptionItem> kWantChildrenOptions = _kDefaultWantChildrenOptions;
List<OptionCategory> kLifestyleCategories = _kDefaultLifestyleCategories;
List<OptionCategory> kAboutYouCategories = _kDefaultAboutYouCategories;
List<OptionCategory> kInterestCategories = _kDefaultInterestCategories;

String? _nonEmptyString(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// [json] همون جوابِ «options» از bootstrap (یا /api/profile/options)ـه. لیست‌های سرور (نام،
/// توضیح، گزینه‌های جدید/حذف‌شده، ترتیب) جایگزینِ لیست‌های پیش‌فرضِ اپ می‌شن و گزینه‌های
/// `hidden: true` از لیستِ انتخاب کنار می‌رن. هر خطایی بیاد، لیست‌های قبلی دست‌نخورده می‌مونن.
void applyProfileOptionOverrides(Map<String, dynamic> json) {
  try {
    final hidden = <String, String>{};

    // لیستِ سرور مرجعه: گزینه‌های جدیدِ ادمین اضافه می‌شن، حذف‌شده‌ها نیستن، مخفی‌ها از لیستِ
    // انتخاب کنار می‌رن و ترتیب همونیه که سرور فرستاده. لیستِ پیش‌فرضِ اپ فقط وقتی استفاده
    // می‌شه که از سرور چیزی نرسیده باشه.
    List<OptionItem> mergeItems(List<OptionItem> base, dynamic serverList) {
      if (serverList is! List || serverList.isEmpty) return base;
      final out = <OptionItem>[];
      for (final e in serverList) {
        if (e is! Map) continue;
        final id = e['id'];
        final label = _nonEmptyString(e['label']);
        if (id is! String || label == null) continue;
        if (e['hidden'] == true) {
          hidden.putIfAbsent(id, () => label);
          continue;
        }
        out.add(OptionItem(id, label, _nonEmptyString(e['description'])));
      }
      return out.isEmpty ? base : out;
    }

    List<OptionCategory> mergeCats(List<OptionCategory> base, dynamic serverList) {
      if (serverList is! List || serverList.isEmpty) return base;
      final baseById = {for (final c in base) c.id: c};
      final out = <OptionCategory>[];
      for (final e in serverList) {
        if (e is! Map) continue;
        final id = e['id'];
        if (id is! String) continue;
        final b = baseById[id];
        out.add(OptionCategory(
          id,
          _nonEmptyString(e['title']) ?? b?.title ?? id,
          mergeItems(b?.items ?? const <OptionItem>[], e['items']),
        ));
      }
      return out.isEmpty ? base : out;
    }

    kGenderOptions = mergeItems(_kDefaultGenderOptions, json['genders']);
    kSeeingOptions = mergeItems(_kDefaultSeeingOptions, json['interested_in']);
    kOrientationOptions = mergeItems(_kDefaultOrientationOptions, json['orientations']);
    kLookingForOptions = mergeItems(_kDefaultLookingForOptions, json['looking_for_options']);
    kEducationOptions = mergeItems(_kDefaultEducationOptions, json['education_options']);
    kWantChildrenOptions = mergeItems(_kDefaultWantChildrenOptions, json['want_children_options']);
    kLifestyleCategories = mergeCats(_kDefaultLifestyleCategories, json['lifestyle_categories']);
    kAboutYouCategories = mergeCats(_kDefaultAboutYouCategories, json['about_you_categories']);
    kInterestCategories = mergeCats(_kDefaultInterestCategories, json['interest_categories']);
    _hiddenOptionLabels
      ..clear()
      ..addAll(hidden);
  } catch (_) {
    // دیتای خراب: همون لیست‌های قبلی می‌مونن.
  }
}

// مرحله‌ی «چی تو رو، تو می‌کنه» — هر دسته تک‌انتخابیه
const List<OptionCategory> _kDefaultAboutYouCategories = [
  OptionCategory('communication', 'سبک ارتباطیت چیه؟', [
    OptionItem('big_texter', 'اهل پیام دادنم'),
    OptionItem('phone_caller', 'ترجیح می‌دم زنگ بزنم'),
    OptionItem('video_chatter', 'تماس تصویری'),
    OptionItem('bad_texter', 'تو پیام دادن ضعیفم'),
    OptionItem('better_in_person', 'حضوری بهترم'),
  ]),
  OptionCategory('love_language', 'محبت رو چطوری می‌گیری؟', [
    OptionItem('thoughtful_gestures', 'کارهای کوچیک و فکرشده'),
    OptionItem('presents', 'هدیه گرفتن'),
    OptionItem('touch', 'تماس فیزیکی'),
    OptionItem('compliments', 'تعریف شنیدن'),
    OptionItem('time_together', 'وقت گذروندن با هم'),
  ]),
  OptionCategory('zodiac', 'بُرجت چیه؟', [
    OptionItem('capricorn', 'جدی'),
    OptionItem('aquarius', 'دلو'),
    OptionItem('pisces', 'حوت'),
    OptionItem('aries', 'حمل'),
    OptionItem('taurus', 'ثور'),
    OptionItem('gemini', 'جوزا'),
    OptionItem('cancer', 'سرطان'),
    OptionItem('leo', 'اسد'),
    OptionItem('virgo', 'سنبله'),
    OptionItem('libra', 'میزان'),
    OptionItem('scorpio', 'عقرب'),
    OptionItem('sagittarius', 'قوس'),
  ]),
];

// مرحله‌ی علاقه‌مندی‌ها — دسته‌بندی‌شده، چندانتخابی (حداکثر تو کد کنترل می‌شه)
const List<OptionCategory> _kDefaultInterestCategories = [
  OptionCategory('creativity', 'خلاقیت', [
    OptionItem('photography', 'عکاسی'),
    OptionItem('painting', 'نقاشی'),
    OptionItem('writing', 'نویسندگی'),
    OptionItem('dancing', 'رقص'),
    OptionItem('singing', 'خوانندگی'),
    OptionItem('handicraft', 'صنایع دستی'),
    OptionItem('poetry', 'شعر'),
    OptionItem('design', 'طراحی'),
  ]),
  OptionCategory('going_out', 'بیرون رفتن', [
    OptionItem('cafe_hopping', 'کافه‌گردی'),
    OptionItem('cinema', 'سینما'),
    OptionItem('live_music', 'کنسرت'),
    OptionItem('theater', 'تئاتر'),
    OptionItem('art_galleries', 'گالری هنری'),
    OptionItem('parties', 'پارتی'),
    OptionItem('board_game_cafe', 'کافه بازی'),
  ]),
  OptionCategory('staying_in', 'خونه‌نشینی', [
    OptionItem('reading', 'کتاب‌خوندن'),
    OptionItem('cooking', 'آشپزی'),
    OptionItem('gaming', 'بازی ویدیویی'),
    OptionItem('binge_watching', 'سریال‌بینی'),
    OptionItem('board_games', 'بازی رومیزی'),
    OptionItem('gardening', 'باغبانی'),
  ]),
  OptionCategory('sports_fitness', 'ورزش', [
    OptionItem('gym', 'باشگاه'),
    OptionItem('running', 'دویدن'),
    OptionItem('football', 'فوتبال'),
    OptionItem('swimming', 'شنا'),
    OptionItem('yoga', 'یوگا'),
    OptionItem('climbing', 'سنگ‌نوردی'),
    OptionItem('cycling', 'دوچرخه‌سواری'),
    OptionItem('martial_arts', 'ورزش رزمی'),
  ]),
  OptionCategory('outdoors', 'طبیعت و سفر', [
    OptionItem('hiking', 'کوه‌پیمایی'),
    OptionItem('camping', 'کمپینگ'),
    OptionItem('travel', 'سفر'),
    OptionItem('road_trips', 'سفر جاده‌ای'),
    OptionItem('beach', 'دریا و ساحل'),
    OptionItem('nature', 'طبیعت‌گردی'),
  ]),
  OptionCategory('music', 'موسیقی', [
    OptionItem('pop', 'پاپ'),
    OptionItem('rock', 'راک'),
    OptionItem('hiphop', 'هیپ‌هاپ'),
    OptionItem('traditional', 'سنتی'),
    OptionItem('electronic', 'الکترونیک'),
    OptionItem('jazz', 'جاز'),
  ]),
  OptionCategory('food_drink', 'غذا و نوشیدنی', [
    OptionItem('foodie', 'اهل غذا خوردنم'),
    OptionItem('street_food', 'فست‌فود خیابونی'),
    OptionItem('coffee', 'قهوه'),
    OptionItem('baking', 'شیرینی‌پزی'),
    OptionItem('vegetarian', 'گیاه‌خواری'),
    OptionItem('mocktails', 'موکتل'),
  ]),
  OptionCategory('values', 'ارزش‌ها', [
    OptionItem('volunteering', 'داوطلبانه کار کردن'),
    OptionItem('environmentalism', 'محیط‌زیست'),
    OptionItem('animal_rights', 'حقوق حیوانات'),
    OptionItem('equality', 'برابری'),
    OptionItem('mental_health_awareness', 'آگاهی سلامت روان'),
  ]),
  OptionCategory('wellness', 'سلامتی و آرامش', [
    OptionItem('self_care', 'مراقبت از خود'),
    OptionItem('meditation', 'مدیتیشن'),
    OptionItem('trying_new_things', 'تجربه‌ی چیزهای جدید'),
    OptionItem('astrology', 'طالع‌بینی'),
    OptionItem('skincare', 'مراقبت از پوست'),
  ]),
];

// پرامپت‌های پیشنهادی برای «یه سؤال کوتاه جواب بده» (اگه بک‌اند
// prompts فرستاد، همون اولویت داره — این فقط fallback محلیه)
const List<OptionItem> kFallbackPrompts = [
  OptionItem('vacation_unless', 'تعطیلات واقعی نیست مگه اینکه...'),
  OptionItem('same_weird', 'ما شبیه همیم اگه...'),
  OptionItem('hype_myself', 'خودمو اینجوری روحیه می‌دم...'),
  OptionItem('villain_origin', 'داستان تبدیل‌شدنم به آدم بد اینه...'),
  OptionItem('friend_group', 'تو جمع دوستام همیشه من...'),
  OptionItem('cancel_plans_for', 'برنامه‌هامو کنسل می‌کنم برای...'),
  OptionItem('happiest_when', 'بیشترین خوشحالیمو وقتی حس می‌کنم که...'),
  OptionItem('green_flag', 'بزرگ‌ترین نقطه‌قوتم تو رابطه اینه...'),
  OptionItem('know_about_me', 'باید درباره‌م بدونی که...'),
  OptionItem('ideal_weekend', 'آخر هفته‌ی ایده‌آلم شامل...'),
];
