import json
import os

new_translations = {
    # ── 1. Account ──
    "settings_label_editProfile": {
        "en": "Edit Profile",
        "ar": "تعديل الملف الشخصي"
    },
    "settings_label_phoneNumber": {
        "en": "Phone Number",
        "ar": "رقم الهاتف"
    },
    "settings_label_phoneCannotChange": {
        "en": "Phone number cannot be changed. Contact support for help.",
        "ar": "لا يمكن تغيير رقم الهاتف. اتصل بالدعم للمساعدة."
    },
    "settings_label_photoPrivacy": {
        "en": "Photo Privacy",
        "ar": "خصوصية الصور"
    },
    "settings_label_verifyProfile": {
        "en": "Verify Profile",
        "ar": "توثيق الحساب"
    },
    "settings_label_selfieChallenge": {
        "en": "Selfie Challenge",
        "ar": "تحدي الصورة الشخصية"
    },
    # Photo Privacy options
    "settings_photo_privacy_public": {
        "en": "Public",
        "ar": "عام"
    },
    "settings_photo_privacy_after_acceptance": {
        "en": "After Acceptance",
        "ar": "بعد القبول"
    },
    "settings_photo_privacy_request_only": {
        "en": "Request Only",
        "ar": "عند الطلب فقط"
    },
    "settings_photo_privacy_everyone": {
        "en": "Everyone",
        "ar": "للجميع"
    },
    "settings_photo_privacy_accepted_interests": {
        "en": "Accepted interests only",
        "ar": "الاهتمامات المقبولة فقط"
    },
    "settings_photo_privacy_request_to_view": {
        "en": "Request to view",
        "ar": "طلب للمشاهدة"
    },

    # ── 2. Notifications ──
    "settings_notify_newInterest": {
        "en": "New Interests",
        "ar": "اهتمامات جديدة"
    },
    "settings_notify_interestAccepted": {
        "en": "Interest Accepted",
        "ar": "قبول الاهتمام"
    },
    "settings_notify_newMessage": {
        "en": "New Messages",
        "ar": "رسائل جديدة"
    },
    "settings_notify_profileApproved": {
        "en": "Profile Approved",
        "ar": "تمت الموافقة على الملف الشخصي"
    },
    "settings_notify_interestExpiring": {
        "en": "Interest Expiring Soon",
        "ar": "أوشكت صلاحية الاهتمام على الانتهاء"
    },
    "settings_notify_activityNudges": {
        "en": "Activity Nudges",
        "ar": "تنبيهات النشاط"
    },
    "settings_notify_activityNudgesSub": {
        "en": "Remind when inactive for 7+ days",
        "ar": "التذكير عند عدم النشاط لأكثر من ٧ أيام"
    },
    "settings_notify_boostReminders": {
        "en": "Boost Reminders",
        "ar": "تذكيرات الترويج"
    },
    "settings_notify_boostRemindersSub": {
        "en": "Remind when your weekly boost is ready",
        "ar": "التذكير عندما يكون ترويجك الأسبوعي جاهزًا"
    },
    "settings_notify_quietHours": {
        "en": "Quiet Hours",
        "ar": "ساعات الهدوء"
    },

    # ── 3. Guardian ──
    "settings_guardian_title": {
        "en": "Guardian Mode",
        "ar": "وضع ولي الأمر"
    },
    "settings_guardian_sub": {
        "en": "Enable Wali oversight for messaging",
        "ar": "تفعيل إشراف الولي على الرسائل"
    },
    "settings_guardian_name_hint": {
        "en": "Guardian Name",
        "ar": "اسم ولي الأمر"
    },
    "settings_guardian_phone_hint": {
        "en": "Guardian Phone",
        "ar": "هاتف ولي الأمر"
    },
    "settings_guardian_relationship": {
        "en": "Relationship",
        "ar": "العلاقة"
    },
    "settings_guardian_mirror": {
        "en": "Mirror Messages",
        "ar": "نسخ الرسائل"
    },
    "settings_guardian_mirror_sub": {
        "en": "Send copies of all messages to guardian",
        "ar": "إرسال نسخ من جميع الرسائل إلى ولي الأمر"
    },
    "settings_guardian_reply": {
        "en": "Allow Guardian to Reply",
        "ar": "السماح لولي الأمر بالرد"
    },
    "settings_guardian_reply_sub": {
        "en": "Guardian may participate in conversations",
        "ar": "يمكن لولي الأمر المشاركة في المحادثات"
    },
    "settings_guardian_save": {
        "en": "Save Guardian Settings",
        "ar": "حفظ إعدادات ولي الأمر"
    },
    "settings_guardian_saved": {
        "en": "Saved",
        "ar": "تم الحفظ"
    },
    # Relationship values
    "settings_relation_father": {
        "en": "Father",
        "ar": "الأب"
    },
    "settings_relation_mother": {
        "en": "Mother",
        "ar": "الأم"
    },
    "settings_relation_brother": {
        "en": "Brother",
        "ar": "الأخ"
    },
    "settings_relation_uncle": {
        "en": "Uncle",
        "ar": "العم/الخال"
    },
    "settings_relation_other": {
        "en": "Other",
        "ar": "آخر"
    },

    # ── 4. Privacy ──
    "settings_privacy_photo_label": {
        "en": "PHOTO VISIBILITY",
        "ar": "ظهور الصور"
    },
    "settings_privacy_photo_sub": {
        "en": "Who can see your photos",
        "ar": "من يمكنه رؤية صورك"
    },
    "settings_privacy_online_label": {
        "en": "ONLINE STATUS",
        "ar": "حالة الاتصال"
    },
    "settings_privacy_online_sub": {
        "en": "Show when you were last active",
        "ar": "إظهار آخر وقت كنت فيه نشطًا"
    },
    "settings_privacy_pause_label": {
        "en": "PROFILE PAUSE",
        "ar": "إيقاف الملف الشخصي مؤقتًا"
    },
    "settings_privacy_pause_sub": {
        "en": "Hide your profile from search",
        "ar": "إخفاء ملفك الشخصي من البحث"
    },
    "settings_privacy_pause_warning": {
        "en": "Your profile is hidden. No one can find you.",
        "ar": "ملفك الشخصي مخفي. لا يمكن لأحد العثور عليك."
    },
    "settings_privacy_visibility_label": {
        "en": "WHO CAN SEE MY PROFILE",
        "ar": "من يمكنه رؤية ملفي الشخصي"
    },
    "settings_privacy_visibility_sub": {
        "en": "Controls who can browse your profile",
        "ar": "التحكم في من يمكنه تصفح ملفك الشخصي"
    },
    "settings_privacy_visibility_all": {
        "en": "All registered users",
        "ar": "جميع المستخدمين المسجلين"
    },
    "settings_privacy_visibility_subscribers": {
        "en": "Subscribers only",
        "ar": "المشتركون فقط"
    },
    # GDPR
    "settings_privacy_download_label": {
        "en": "DOWNLOAD MY DATA",
        "ar": "تنزيل بياناتي"
    },
    "settings_privacy_download_sub": {
        "en": "Export a copy of your personal data under GDPR",
        "ar": "تصدير نسخة من بياناتك الشخصية بموجب اللائحة العامة لحماية البيانات (GDPR)"
    },
    "settings_privacy_download_body": {
        "en": "Under GDPR and other privacy regulations, you can request a complete export of your profile, matching, and activity data. The file will be prepared and sent to your registered address.",
        "ar": "بموجب اللائحة العامة لحماية البيانات (GDPR) ولوائح الخصوصية الأخرى، يمكنك طلب تصدير كامل لملفك الشخصي وبيانات المطابقة والنشاط. سيتم إعداد الملف وإرساله إلى عنوانك المسجل."
    },
    "settings_privacy_download_btn": {
        "en": "Request Data Export",
        "ar": "طلب تصدير البيانات"
    },
    "settings_privacy_export_title": {
        "en": "Export Requested",
        "ar": "تم طلب التصدير"
    },
    "settings_privacy_export_body": {
        "en": "Your request has been received! We are compiling your personal data archive.",
        "ar": "لقد تم استلام طلبك! نحن نعمل على تجميع أرشيف بياناتك الشخصية."
    },
    "settings_privacy_export_subbody": {
        "en": "A download link will be sent to your registered phone/email within 48 hours in compliance with GDPR guidelines.",
        "ar": "سيتم إرسال رابط التنزيل إلى هاتفك/بريدك الإلكتروني المسجل في غضون ٤٨ ساعة امتثالاً لتوجيهات GDPR."
    },
    "settings_privacy_export_btn_close": {
        "en": "Understood",
        "ar": "مفهوم"
    },

    # ── 5. Contact Support ──
    "settings_support_contact": {
        "en": "Contact Support",
        "ar": "الاتصال بالدعم"
    },
    "settings_support_body": {
        "en": "For any questions, concerns, or feedback:",
        "ar": "لأي أسئلة أو مخاوف أو ملاحظات:"
    },
    "settings_support_note": {
        "en": "We aim to respond within 48 hours.",
        "ar": "نهدف إلى الرد في غضون ٤٨ ساعة."
    },
    "settings_support_btn_close": {
        "en": "Close",
        "ar": "إغلاق"
    },
    "settings_brand_credit": {
        "en": "NOOR (نور) · For the sake of Allah",
        "ar": "نور (NOOR) · لوجه الله"
    }
}

def main():
    en_path = r"c:\Users\imran\noor\lib\l10n\app_en.arb"
    ar_path = r"c:\Users\imran\noor\lib\l10n\app_ar.arb"
    
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    with open(ar_path, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
        
    # Append keys
    for key, translation in new_translations.items():
        # Add to EN
        en_data[key] = translation["en"]
        en_data[f"@{key}"] = {}  # Empty metadata for template config
        
        # Add to AR
        ar_data[key] = translation["ar"]
        
    # Sort EN
    sorted_en = {}
    for special in ["@@locale", "@@last_modified"]:
        if special in en_data:
            sorted_en[special] = en_data[special]
            
    for key in sorted(en_data.keys()):
        if not key.startswith("@@"):
            sorted_en[key] = en_data[key]
            
    # Sort AR
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
        
    print("Successfully added all settings translation keys!")

if __name__ == '__main__':
    main()
