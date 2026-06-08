import json

photo_translations = {
    "photo_title_self": {
        "en": "Add your photos",
        "ar": "إضافة صورك"
    },
    "photo_title_guardian": {
        "en": "Add their photos",
        "ar": "إضافة صورهم"
    },
    "photo_subtitle_self": {
        "en": "At least one photo is required. Maximum four.",
        "ar": "مطلوب صورة واحدة على الأقل. الحد الأقصى أربع."
    },
    "photo_subtitle_guardian": {
        "en": "Add photos of your {relation}. At least one is required.",
        "ar": "أضف صور {relation}. مطلوب صورة واحدة على الأقل."
    },
    "photo_banner_text": {
        "en": "Each photo is scanned to ensure a visible face. Group photos are not allowed as your primary photo.",
        "ar": "يتم مسح كل صورة للتأكد من وجود وجه ظاهر. لا يسمح بالصور الجماعية كصورة أساسية."
    },
    "photo_label_primary": {
        "en": "Primary photo",
        "ar": "الصورة الأساسية"
    },
    "photo_label_photo2": {
        "en": "Photo 2",
        "ar": "الصورة ٢"
    },
    "photo_label_photo3": {
        "en": "Photo 3",
        "ar": "الصورة ٣"
    },
    "photo_label_selfie": {
        "en": "Verification selfie",
        "ar": "سيلفي التحقق"
    },
    "photo_error_no_face_detected": {
        "en": "No face visible — please retry with a clear face photo",
        "ar": "الوجه غير ظاهر — يرجى المحاولة مرة أخرى بصورة وجه واضحة"
    },
    "photo_error_pick_failed": {
        "en": "Could not pick photo: {error}",
        "ar": "تعذر اختيار الصورة: {error}"
    }
}

def main():
    en_path = r"c:\Users\imran\noor\lib\l10n\app_en.arb"
    ar_path = r"c:\Users\imran\noor\lib\l10n\app_ar.arb"
    
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    with open(ar_path, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
        
    for key, translation in photo_translations.items():
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
        
    print("Successfully added photo translation keys!")

if __name__ == '__main__':
    main()
