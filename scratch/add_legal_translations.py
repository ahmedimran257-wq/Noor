import json
import os

new_translations = {
    "legal_subtitle": {
        "en": "Please read and agree to continue.",
        "ar": "يرجى القراءة والموافقة للمتابعة."
    },
    "legal_summary_1": {
        "en": "Your data is encrypted and never sold to third parties.",
        "ar": "بياناتك مشفرة ولا يتم مشاركتها أو بيعها لأطراف ثالثة."
    },
    "legal_summary_2": {
        "en": "Your photos are reviewed before your profile goes live.",
        "ar": "تتم مراجعة صورك يدويًا لضمان سلامة مجتمعنا."
    },
    "legal_summary_3": {
        "en": "Harassment, fake profiles, and scams result in permanent bans.",
        "ar": "المضايقات، الحسابات المزيفة، أو السلوكيات غير اللائقة تؤدي للحظر الدائم."
    },
    "legal_summary_4": {
        "en": "This platform is for marriage intentions only. Dignity is the standard.",
        "ar": "هذه المنصة مخصصة لنية الزواج فقط. الوقار هو معيارنا."
    },
    "legal_summary_5": {
        "en": "You may delete your account and all data at any time.",
        "ar": "يمكنك حذف حسابك وجميع بياناتك نهائيًا في أي وقت."
    }
}

def main():
    en_path = r"c:\Users\imran\noor\lib\l10n\app_en.arb"
    ar_path = r"c:\Users\imran\noor\lib\l10n\app_ar.arb"
    
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    with open(ar_path, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
        
    for key, translation in new_translations.items():
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
        
    print("Successfully added legal translation keys!")

if __name__ == '__main__':
    main()
