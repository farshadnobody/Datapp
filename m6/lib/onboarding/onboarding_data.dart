// داده‌های ثابتِ سؤال‌های اونبوردینگ (سبک تیندر).
//
// این‌ها فعلاً هاردکدن، نه از بک‌اند. اگه می‌خوای شخصی‌سازی/کنترل از سمت
// سرور داشته باشی (مثلاً بعداً یه گزینه اضافه/کم کنی بدون آپدیت اپ)، باید
// این لیست‌ها رو هم به /api/profile/options اضافه کنی و اینجا فقط fallback
// بمونه.

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
// کافیه به لیست items همون دسته‌ی موردنظر تو kInterestCategories زیر
// OptionItem جدید اضافه کنی — پنج‌تای اول خودکار می‌شن حالت جمع‌شده.
const int kInterestPreviewCount = 5;

// مرحله‌ی جنسیت
const List<OptionItem> kGenderOptions = [
  OptionItem('man', 'مرد'),
  OptionItem('woman', 'زن'),
  OptionItem('beyond_binary', 'فراتر از دوجنسیتی'),
];

// مرحله‌ی گرایش جنسی
const List<OptionItem> kOrientationOptions = [
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
const List<OptionItem> kSeeingOptions = [
  OptionItem('men', 'مردها'),
  OptionItem('women', 'زن‌ها'),
  OptionItem('beyond_binary', 'فراتر از دوجنسیتی'),
  OptionItem('everyone', 'همه'),
];

// مرحله‌ی «دنبال چه نوع رابطه‌ای هستی»
const List<OptionItem> kLookingForOptions = [
  OptionItem('long_term', 'رابطه‌ی جدی'),
  OptionItem('long_term_open_short', 'جدی، ولی به کوتاه‌مدت هم باز'),
  OptionItem('short_term_open_long', 'کوتاه‌مدت، ولی به جدی هم باز'),
  OptionItem('short_term_fun', 'رابطه‌ی کوتاه و بی‌دغدغه'),
  OptionItem('new_friends', 'دوست‌یابی'),
  OptionItem('figuring_out', 'هنوز مطمئن نیستم'),
];

// مرحله‌ی تحصیلات
const List<OptionItem> kEducationOptions = [
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
const List<OptionCategory> kLifestyleCategories = [
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
    OptionItem('bird', 'پرنده'),
    OptionItem('fish', 'ماهی'),
    OptionItem('other', 'چیز دیگه'),
    OptionItem('no_pet_but_love', 'ندارم ولی دوست دارم'),
    OptionItem('want_a_pet', 'می‌خوام بگیرم'),
    OptionItem('all_the_pets', 'همه رو دوست دارم'),
    OptionItem('allergic', 'حساسیت دارم'),
    OptionItem('pet_free', 'ترجیح می‌دم نداشته باشم'),
  ]),
];

// مرحله‌ی «چی تو رو، تو می‌کنه» — هر دسته تک‌انتخابیه
const List<OptionCategory> kAboutYouCategories = [
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
const List<OptionCategory> kInterestCategories = [
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
