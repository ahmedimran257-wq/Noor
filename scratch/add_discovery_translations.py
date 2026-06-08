import json

discovery_translations = {
    "discovery_bookmark_saved": {
        "en": "{name} saved",
        "ar": "تم حفظ {name}"
    },
    "discovery_bookmark_removed": {
        "en": "{name} removed",
        "ar": "تم إزالة {name}"
    },
    "discovery_empty_subtitle": {
        "en": "Try expanding your search filters\nor check back tomorrow.",
        "ar": "حاول توسيع فلاتر البحث\nأو تحقق مجدداً غداً."
    },
    "discovery_limit_title": {
        "en": "Daily limit reached",
        "ar": "تم الوصول للحد اليومي"
    },
    "discovery_limit_subtitle": {
        "en": "You've browsed 15 profiles today.\nUpgrade to unlock unlimited browsing.",
        "ar": "لقد تصفحت ١٥ ملفاً شخصياً اليوم.\nاشترك لفتح تصفح غير محدود."
    },
    "discovery_limit_button": {
        "en": "Upgrade Now",
        "ar": "اشترك الآن"
    },
    "discovery_completeness_title": {
        "en": "Complete Your Profile",
        "ar": "أكمل ملفك الشخصي"
    },
    "discovery_completeness_subtitle": {
        "en": "Profiles above 40% get 3× more interests.\nComplete your profile to start browsing.",
        "ar": "الملفات الشخصية التي تتجاوز ٤٠٪ تحصل على اهتمام أكثر بـ ٣ مرات.\nأكمل ملفك الشخصي لبدء التصفح."
    },
    "discovery_completeness_button": {
        "en": "Complete Profile",
        "ar": "أكمل الملف الشخصي"
    }
}

def main():
    en_path = r"c:\Users\imran\noor\lib\l10n\app_en.arb"
    ar_path = r"c:\Users\imran\noor\lib\l10n\app_ar.arb"
    
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    with open(ar_path, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
        
    for key, translation in discovery_translations.items():
        en_data[key] = translation["en"]
        en_data[f"@{key}"] = {}
        ar_data[key] = translation["ar"]
        
    sorted_en = {}
    for special in ["@@locale", "@@last_modified"]:
        if special in en_data:
            sorted_en[special] = en_data[special]
    for key in sorted(en_data.keys()):
        if not key.startswith("@@"):
            sorted_en[key] = en_data[key]
            
    sorted_ar = {}
    for special in ["@@locale", "@@last_modified"]:
        if special in ar_data:
            sorted_ar[special] = ar_data[special]
    for key in sorted(ar_data.keys()):
        if not key.startswith("@@"):
            sorted_ar[key] = ar_data[key]
            
    with open(en_path, 'w', encoding='utf-8') as f:
        json.dump(sorted_en, f, indent=2, ensure_ascii=False)
        
    with open(ar_path, 'w', encoding='utf-8') as f:
        json.dump(sorted_ar, f, indent=2, ensure_ascii=False)
        
    print("Successfully added discovery translation keys!")

if __name__ == '__main__':
    main()
