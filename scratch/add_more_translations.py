import json

more_translations = {
    # Interest Categories
    "interest_cat_faith": {
        "en": "Faith",
        "ar": "الإيمان والعبادات"
    },
    "interest_cat_lifestyle": {
        "en": "Lifestyle",
        "ar": "نمط الحياة"
    },
    "interest_cat_learning": {
        "en": "Learning",
        "ar": "التعليم والمعرفة"
    },
    "interest_cat_creative": {
        "en": "Creative",
        "ar": "الإبداع والفنون"
    },
    "interest_cat_sports": {
        "en": "Sports",
        "ar": "الرياضة"
    },
    "interest_cat_social": {
        "en": "Social",
        "ar": "الحياة الاجتماعية"
    },
    # Faith Tags
    "interest_tag_quran_recitation": {
        "en": "Quran recitation",
        "ar": "تلاوة القرآن"
    },
    "interest_tag_islamic_lectures": {
        "en": "Islamic lectures",
        "ar": "المحاضرات الإسلامية"
    },
    "interest_tag_dawah": {
        "en": "Dawah",
        "ar": "الدعوة"
    },
    "interest_tag_voluntary_fasting": {
        "en": "Voluntary fasting",
        "ar": "صيام التطوع"
    },
    "interest_tag_tahajjud": {
        "en": "Tahajjud",
        "ar": "قيام الليل / التهجد"
    },
    "interest_tag_umrah_hajj": {
        "en": "Umrah/Hajj",
        "ar": "العمرة / الحج"
    },
    # Lifestyle Tags
    "interest_tag_cooking": {
        "en": "Cooking",
        "ar": "الطبخ"
    },
    "interest_tag_travel": {
        "en": "Travel",
        "ar": "السفر"
    },
    "interest_tag_fitness": {
        "en": "Fitness",
        "ar": "اللياقة البدنية"
    },
    "interest_tag_gardening": {
        "en": "Gardening",
        "ar": "البستنة"
    },
    "interest_tag_volunteering": {
        "en": "Volunteering",
        "ar": "العمل التطوعي"
    },
    "interest_tag_photography": {
        "en": "Photography",
        "ar": "التصوير"
    },
    # Learning Tags
    "interest_tag_reading": {
        "en": "Reading",
        "ar": "القراءة"
    },
    "interest_tag_technology": {
        "en": "Technology",
        "ar": "التكنولوجيا"
    },
    "interest_tag_science": {
        "en": "Science",
        "ar": "العلوم"
    },
    "interest_tag_history": {
        "en": "History",
        "ar": "التاريخ"
    },
    "interest_tag_languages": {
        "en": "Languages",
        "ar": "اللغات"
    },
    "interest_tag_writing": {
        "en": "Writing",
        "ar": "الكتابة"
    },
    # Creative Tags
    "interest_tag_calligraphy": {
        "en": "Calligraphy",
        "ar": "الخط العربي"
    },
    "interest_tag_art": {
        "en": "Art",
        "ar": "الفن"
    },
    "interest_tag_poetry": {
        "en": "Poetry",
        "ar": "الشعر"
    },
    "interest_tag_graphic_design": {
        "en": "Graphic design",
        "ar": "تصميم الجرافيك"
    },
    "interest_tag_crafts": {
        "en": "Crafts",
        "ar": "الأعمال اليدوية"
    },
    # Sports Tags
    "interest_tag_cricket": {
        "en": "Cricket",
        "ar": "الكريكت"
    },
    "interest_tag_football": {
        "en": "Football",
        "ar": "كرة القدم"
    },
    "interest_tag_swimming": {
        "en": "Swimming",
        "ar": "السباحة"
    },
    "interest_tag_hiking": {
        "en": "Hiking",
        "ar": "المشي الجبلي"
    },
    "interest_tag_martial_arts": {
        "en": "Martial arts",
        "ar": "الفنون القتالية"
    },
    "interest_tag_cycling": {
        "en": "Cycling",
        "ar": "ركوب الدراجات"
    },
    # Social Tags
    "interest_tag_community_work": {
        "en": "Community work",
        "ar": "العمل المجتمعي"
    },
    "interest_tag_teaching": {
        "en": "Teaching",
        "ar": "التعليم"
    },
    "interest_tag_mentoring": {
        "en": "Mentoring",
        "ar": "التوجيه والإرشاد"
    },
    "interest_tag_family_gatherings": {
        "en": "Family gatherings",
        "ar": "التجمعات العائلية"
    },
    # Languages
    "lang_english": {"en": "English", "ar": "الإنجليزية"},
    "lang_arabic": {"en": "Arabic", "ar": "العربية"},
    "lang_urdu": {"en": "Urdu", "ar": "الأردية"},
    "lang_hindi": {"en": "Hindi", "ar": "الهندية"},
    "lang_malay": {"en": "Malay", "ar": "الملايوية"},
    "lang_indonesian": {"en": "Indonesian", "ar": "الإندونيسية"},
    "lang_turkish": {"en": "Turkish", "ar": "التركية"},
    "lang_french": {"en": "French", "ar": "الفرنسية"},
    "lang_german": {"en": "German", "ar": "الألمانية"},
    "lang_bengali": {"en": "Bengali", "ar": "البنغالية"},
    "lang_punjabi": {"en": "Punjabi", "ar": "البنجابية"},
    "lang_tamil": {"en": "Tamil", "ar": "التاميلية"},
    "lang_persian": {"en": "Persian", "ar": "الفارسية"},
    "lang_swahili": {"en": "Swahili", "ar": "السواحيلية"},
    "lang_hausa": {"en": "Hausa", "ar": "الهوسا"},
    "lang_pashto": {"en": "Pashto", "ar": "البشتوية"},
    "lang_sindhi": {"en": "Sindhi", "ar": "السندية"},
    "lang_somali": {"en": "Somali", "ar": "الصومالية"},
    "lang_kurdish": {"en": "Kurdish", "ar": "الكردية"},
    "lang_dari": {"en": "Dari", "ar": "الدرية"},
    "lang_javanese": {"en": "Javanese", "ar": "الجاوية"},
    "lang_sundanese": {"en": "Sundanese", "ar": "السوندية"},
    "lang_tagalog": {"en": "Tagalog", "ar": "التاغالوغية"},
    "lang_thai": {"en": "Thai", "ar": "التايلاندية"},
    "lang_burmese": {"en": "Burmese", "ar": "البورمية"},
    "lang_rohingya": {"en": "Rohingya", "ar": "الروهينغية"},
    "lang_wolof": {"en": "Wolof", "ar": "الولوفية"},
    "lang_fulani": {"en": "Fulani", "ar": "الفولانية"},
    "lang_amazigh": {"en": "Amazigh (Berber)", "ar": "الأمازيغية"},
    "lang_mandinka": {"en": "Mandinka", "ar": "الماندينكوية"},
    "lang_uzbek": {"en": "Uzbek", "ar": "الأوزبكية"},
    "lang_kazakh": {"en": "Kazakh", "ar": "الكازاخية"},
    "lang_tajik": {"en": "Tajik", "ar": "الطاجيكية"},
    "lang_kyrgyz": {"en": "Kyrgyz", "ar": "القيرغيزية"},
    "lang_tatar": {"en": "Tatar", "ar": "التتارية"},
    "lang_bosnian": {"en": "Bosnian", "ar": "البوسنية"},
    "lang_albanian": {"en": "Albanian", "ar": "الألبانية"},
    "lang_chechen": {"en": "Chechen", "ar": "الشيشانية"},
    "lang_dutch": {"en": "Dutch", "ar": "الهولندية"},
    "lang_swedish": {"en": "Swedish", "ar": "السويدية"},
    "lang_norwegian": {"en": "Norwegian", "ar": "النرويجية"},
    "lang_italian": {"en": "Italian", "ar": "الإيطالية"},
    "lang_spanish": {"en": "Spanish", "ar": "الإسبانية"},
    "lang_portuguese": {"en": "Portuguese", "ar": "البرتغالية"},
    "lang_gujarati": {"en": "Gujarati", "ar": "الغوجاراتية"},
    "lang_marathi": {"en": "Marathi", "ar": "الماراثية"},
    "lang_malayalam": {"en": "Malayalam", "ar": "المليالمية"},
    "lang_telugu": {"en": "Telugu", "ar": "التيلوغوية"},
    "lang_kannada": {"en": "Kannada", "ar": "الكانادية"},
    "lang_assamese": {"en": "Assamese", "ar": "الآسامية"},
    "lang_odia": {"en": "Odia", "ar": "الأودية"},
    "lang_saraiki": {"en": "Saraiki", "ar": "السرائيكية"},
    "lang_balochi": {"en": "Balochi", "ar": "البلوشية"},
    "lang_amharic": {"en": "Amharic", "ar": "الأمهرية"},
    "lang_tigrinya": {"en": "Tigrinya", "ar": "التغرينية"},
    "lang_yoruba": {"en": "Yoruba", "ar": "اليوروبية"},
    "lang_igbo": {"en": "Igbo", "ar": "الإيجبوية"},
    "lang_chinese": {"en": "Chinese (Mandarin)", "ar": "الصينية (الماندرين)"},
    "lang_russian": {"en": "Russian", "ar": "الروسية"},
    "lang_japanese": {"en": "Japanese", "ar": "اليابانية"},
    "lang_korean": {"en": "Korean", "ar": "الكورية"},
    "lang_other": {"en": "Other", "ar": "أخرى"}
}

def main():
    en_path = r"c:\Users\imran\noor\lib\l10n\app_en.arb"
    ar_path = r"c:\Users\imran\noor\lib\l10n\app_ar.arb"
    
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    with open(ar_path, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
        
    # Append keys
    for key, translation in more_translations.items():
        # Add to EN
        en_data[key] = translation["en"]
        en_data[f"@{key}"] = {}  # Empty metadata
        
        # Add to AR
        ar_data[key] = translation["ar"]
        
    # Sort
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
            
    # Write back
    with open(en_path, 'w', encoding='utf-8') as f:
        json.dump(sorted_en, f, indent=2, ensure_ascii=False)
        
    with open(ar_path, 'w', encoding='utf-8') as f:
        json.dump(sorted_ar, f, indent=2, ensure_ascii=False)
        
    print("Successfully added more translation keys!")

if __name__ == '__main__':
    main()
