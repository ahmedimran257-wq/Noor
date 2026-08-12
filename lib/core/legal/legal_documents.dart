/// Versioned legal notices shown in the app.
///
/// The public HTML versions live under `site/` and are contract-tested against
/// these identifiers, titles, version and effective date. Policy changes must
/// update both surfaces and bump [LegalDocuments.version].
class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final List<LegalSection> sections;
}

abstract final class LegalDocuments {
  static const version = '2.2.0';
  static const effectiveDate = '11 August 2026';
  static const operatorName = 'Imran Ahmed';
  static const grievanceOfficerName = 'Imran Ahmed';
  static const supportEmail = 'support@silarah.com';
  static const privacyEmail = 'privacy@silarah.com';
  static const safetyEmail = 'safety@silarah.com';
  static const grievanceEmail = 'grievance@silarah.com';

  static const terms = LegalDocument(
    id: 'terms_of_service',
    slug: 'terms',
    title: 'Terms of Service',
    summary:
        'The contract governing eligibility, accounts, subscriptions, safety, content and use of Silarah.',
    sections: [
      LegalSection(
        '1. Agreement and incorporated policies',
        'These Terms form a binding agreement between you and Imran Ahmed, an individual developer operating Silarah in India, for use of the Silarah mobile application, website and related services (the “Service”). By creating an account, accessing the Service or purchasing a subscription, you accept these Terms and the Privacy Policy, Privacy Rights and Grievance Policy, Community Guidelines, Refund Policy, Data Deletion Policy, Verification Policy, Photo Moderation Policy and Guardian/Wali Policy. If you do not accept them, do not use the Service.',
      ),
      LegalSection(
        '2. Eligibility and purpose',
        'You must be at least 18 years old, legally capable of entering this agreement and legally permitted to marry under the law that applies to you. Silarah is intended for adults seeking a genuine matrimonial introduction. It is not an escort, casual-dating, employment, immigration, fundraising or financial-services platform. You may not use the Service if we previously terminated you for a serious safety violation unless we give written permission.',
      ),
      LegalSection(
        '3. Your account and information',
        'You must provide accurate, current information about your identity, age, marital status, location and matrimonial intentions. You are responsible for safeguarding authentication codes and devices and for activity under your account. Do not create an account for another adult without their knowledge and authority. Notify support@silarah.com promptly if you suspect unauthorized access. We may require reverification when information changes or safety risk is detected.',
      ),
      LegalSection(
        '4. Profiles, photos and your licence to us',
        'You retain ownership of content you submit. You grant Silarah a worldwide, non-exclusive, royalty-free licence to host, copy, process, adapt for technical display, moderate and show that content only as needed to operate, secure and improve the Service. The licence ends when the content or account is deleted, except for cached copies and records we must retain for safety, disputes or law. You represent that you have the rights and permissions needed for everything you upload, including images of other people.',
      ),
      LegalSection(
        '5. Discovery, interests and communication',
        'Discovery and compatibility results are recommendations, not promises. Limits on interests, messages, boosts and other features may vary by plan, gender-based product rules, safety state and region, and are displayed in the app before use or purchase. A match or accepted interest does not establish endorsement, identity certainty, compatibility or consent to off-platform contact. Respect blocks, withdrawals and requests to stop communicating.',
      ),
      LegalSection(
        '6. Verification and guardians',
        'Photo, phone, email, account-history and guardian trust checks reduce certain risks but do not establish legal identity and do not constitute a criminal, financial, employment, immigration or comprehensive background check. A badge is not a guarantee that every statement is true or that a member is safe. Guardian mode is optional product functionality and is not legal advice or a determination that a particular wali arrangement is valid under religious or civil law. The separate Verification and Guardian/Wali Policies apply.',
      ),
      LegalSection(
        '7. Subscriptions, renewal and cancellation',
        'Paid plans, included features, price, billing period, trial (if any) and renewal terms are shown before purchase. Mobile subscriptions are processed by the relevant app store and normally renew automatically until cancelled through that store. Removing the app, pausing a profile or deleting a Silarah account does not itself cancel store billing. Cancellation stops future renewal but ordinarily leaves access until the paid period ends. Refund eligibility is governed by applicable consumer law, the store’s rules and our Refund Policy.',
      ),
      LegalSection(
        '8. Prohibited conduct',
        'You must not misrepresent identity or intentions; solicit money, gifts, investments, visas or commercial services; harass, threaten, stalk or discriminate; sexualize, exploit or endanger anyone; share intimate or private material without consent; upload unlawful, infringing or malicious content; scrape, sell or build databases of member data; reverse-engineer or bypass access, moderation, subscription or rate limits; automate outreach; manipulate reports or verification; or use the Service for any unlawful purpose. The Community Guidelines provide further detail.',
      ),
      LegalSection(
        '9. Safety action and appeals',
        'We may limit content, visibility, messaging or features; require verification; preserve evidence; suspend, shadow-limit or terminate accounts; and report matters to stores, payment providers or authorities when reasonably necessary to enforce these Terms, protect people, investigate fraud or comply with law. Some urgent action may occur without advance notice. You may appeal a decision through the in-app support route or safety@silarah.com. We review appeals in good faith but do not guarantee restoration.',
      ),
      LegalSection(
        '10. Account closure and deletion',
        'You may pause visibility or request deletion in Settings. A deletion request enters a 30-day recovery period and is then permanently processed, subject to limited lawful retention described in the Data Deletion and Privacy Policies. We may close inactive or unsafe accounts. Provisions that by nature survive—such as payment obligations, content responsibility, disclaimers, liability limits, dispute terms and lawful retention—continue after closure.',
      ),
      LegalSection(
        '11. Service and member disclaimers',
        'Silarah provides an introduction and communication service on an “as available” basis. We do not arrange or guarantee a meeting, relationship or marriage; verify every claim; control member conduct off-platform; or promise uninterrupted or error-free operation. Always use independent judgment, protect financial and identity information, involve trusted people where appropriate, meet safely and report concerns. Nothing in these Terms excludes warranties or rights that cannot lawfully be excluded.',
      ),
      LegalSection(
        '12. Liability',
        'To the maximum extent permitted by law, Silarah is not liable for indirect, incidental, special, consequential or punitive loss, loss of opportunity, or conduct of another member. Our aggregate liability arising from the Service will not exceed the greater of the amount you paid Silarah in the 12 months before the event or the minimum amount required by applicable law. These limits do not apply to fraud, wilful misconduct, death or personal injury caused by negligence, or any liability that law does not permit us to limit.',
      ),
      LegalSection(
        '13. Governing law and disputes',
        'These Terms are governed by the laws of India, without depriving you of mandatory consumer protections in your country of residence. Before filing a claim, contact grievance@silarah.com and allow 30 days for a good-faith resolution, unless urgent relief is needed. Courts of competent jurisdiction in India will have non-exclusive jurisdiction, subject to any mandatory local forum rights.',
      ),
      LegalSection(
        '14. Changes and contact',
        'We may update these Terms for legal, safety or product reasons. Material changes will be notified in the app or by email and, where required, we will request renewed consent. The version and effective date appear above. Product questions: support@silarah.com. Formal grievances: grievance@silarah.com.',
      ),
    ],
  );

  static const privacy = LegalDocument(
    id: 'privacy_policy',
    slug: 'privacy',
    title: 'Privacy Policy',
    summary:
        'What Silarah collects, why it is used, who processes it, how long it is kept and the choices available to you.',
    sections: [
      LegalSection(
        '1. Scope and controller',
        'This Policy applies to the Silarah app, silarah.com and related support, safety and verification operations. Imran Ahmed is the individual developer operating Silarah in India and the data fiduciary responsible for deciding why and how personal data is processed. The grievance officer is Imran Ahmed. Privacy questions and rights requests may be sent to privacy@silarah.com; formal grievances may be sent to grievance@silarah.com.',
      ),
      LegalSection(
        '2. Data you provide',
        'We collect account identifiers and contact details; date of birth, gender, marital and family information; city, region, country and optional approximate device location; education, occupation, income-range and lifestyle information; biography, partner preferences and matrimonial timeline; religious information such as sect and practice; photos and verification submissions; interests, blocks, reports, support messages and guardian details; and content you send through chat. Do not submit information you do not have authority to provide.',
      ),
      LegalSection(
        '3. Data generated when you use Silarah',
        'We process authentication and consent records, device and app version, notification tokens, language and settings, feature activity, matches, message delivery and typing state, moderation and fraud signals, subscription status and transaction events, crash diagnostics, IP-derived security information, timestamps and audit logs. Precise device location is requested only for location-based discovery and can be denied; city-based discovery remains available.',
      ),
      LegalSection(
        '4. Sensitive and verification data',
        'Religious beliefs, temporary verification captures and some matrimonial information may be sensitive under applicable law. We use religious information for compatibility only with explicit consent where required. The optional photo check creates three temporary guided captures for an authorized human to compare with the current profile photo. We do not create facial embeddings or templates, perform government-ID matching, estimate age from a face, or use these captures for advertising.',
      ),
      LegalSection(
        '5. Purposes and legal bases',
        'We use data to create and secure accounts; provide discovery, interests, messaging, photo privacy, guardian and subscription features; personalize results; perform verification and moderation; deliver service and safety notifications; prevent abuse and fraud; provide support; maintain records; diagnose failures; and comply with law. Depending on your location, we rely on performance of our contract, consent (including explicit consent for sensitive data), legitimate interests in operating and protecting the Service, and legal obligations. You may withdraw consent prospectively, although some features may then be unavailable.',
      ),
      LegalSection(
        '6. Visibility to other members and guardians',
        'Profile fields you choose to publish are visible to eligible registered members according to discovery and privacy settings. Photos follow your selected mode: public, visible after mutual interest, or request-to-view. Messages are visible to conversation participants and may be visible to a properly linked guardian where guardian chat mirroring is enabled. Reports disclose necessary content to authorized safety staff, not to the reported member except as needed for a fair process.',
      ),
      LegalSection(
        '7. Service providers and disclosures',
        'We use vetted processors to run the Service: Supabase for authentication, database, private storage, realtime and server functions; Google Firebase for push delivery, phone authentication where enabled and crash reporting; RevenueCat and the applicable app store for subscriptions and transaction state; Brevo for transactional email; Cloudflare for website delivery, DNS and security; Google ML Kit for on-device capture guidance and photo-safety signals; and Photon/Wikidata for location and language lookup. These providers process only data needed for their role under their own contractual and legal obligations. We may also disclose data with your direction, during a corporate transaction, to protect people and the Service, or when lawfully required. We do not sell personal data and do not run third-party behavioural advertising.',
      ),
      LegalSection(
        '8. International processing',
        'Our providers may process data in countries other than yours. Where required, we use contractual safeguards and assess provider security and transfer mechanisms. Local law may allow public authorities to request data. Contact privacy@silarah.com for information about safeguards relevant to your region.',
      ),
      LegalSection(
        '9. Retention',
        'Active-account profile, preference, photo, match and message data is retained while needed to provide the Service. A requested account enters a 30-day recovery period before purge. Temporary photo-verification captures are deleted from active verification storage after review and no later than 48 hours after submission. We retain the decision, date, reviewer audit and deletion result without retaining the captures. Information and removed content that applicable intermediary rules require us to preserve may be retained for 180 days, or longer when a lawful order requires it. Reports, blocks, transaction records, consent records, security logs and backups may otherwise remain only for applicable limitation, tax, payment, abuse-prevention and legal periods, then be deleted or de-identified. Backup deletion completes through normal provider rotation. We periodically review retention and avoid keeping identifiable data merely because it may be useful.',
      ),
      LegalSection(
        '10. Security',
        'We use encrypted transport, private storage for temporary verification captures, row-level access controls, short-lived signed media access, role-based staff access, audit logs, rate limits and secret management. No online system is risk-free. Use a secure device, protect OTP codes and report suspected compromise promptly. We will make legally required breach notifications.',
      ),
      LegalSection(
        '11. Your rights and choices',
        'Depending on applicable law, you may access, correct, export or delete data; withdraw consent; object to or restrict processing; request portability; nominate another person where that right applies; and complain to a regulator. In-app controls let you edit your profile, change photo visibility, pause discovery, manage notifications, block members, download a machine-readable ZIP archive and request deletion. Withdrawal must be as easy as giving consent, but processing already lawfully completed is not reversed. We may proportionately verify identity before completing a request. We will respond within the legally required period and explain any lawful refusal. Email privacy@silarah.com for an omitted category or assisted request.',
      ),
      LegalSection(
        '12. Adults only',
        'Silarah is not directed to anyone under 18 and we do not knowingly allow minors to hold accounts. If you believe a minor has provided data, contact safety@silarah.com so we can investigate and remove it.',
      ),
      LegalSection(
        '13. Changes and contact',
        'Material changes will be notified in-app or by email and renewed consent will be requested where required. The effective date and version identify the applicable notice. Privacy: privacy@silarah.com. Safety: safety@silarah.com. Grievances: grievance@silarah.com.',
      ),
    ],
  );

  static const community = LegalDocument(
    id: 'community_guidelines',
    slug: 'community-guidelines',
    title: 'Community Guidelines',
    summary:
        'Behaviour and content standards designed to keep matrimonial introductions sincere, dignified and safe.',
    sections: [
      LegalSection('1. Genuine matrimonial intent',
          'Use Silarah only for serious matrimonial introductions. Casual dating, sexual services, recruitment, commercial promotion, fundraising, visa arrangements and investment solicitation are not permitted.'),
      LegalSection('2. Be truthful',
          'Use your own identity and current photos. Accurately state age, marital status, location and material circumstances. Do not impersonate, catfish, create duplicate deceptive accounts, conceal that an account is guardian-managed, or manipulate verification.'),
      LegalSection('3. Respect and consent',
          'Communicate with adab and respect. Do not pressure anyone to reply, share photos, move off-platform, meet, marry or involve family. A match or accepted interest is not consent to sexual, abusive or persistent contact. Stop when asked and respect blocks.'),
      LegalSection('4. Sexual and exploitative content',
          'Nudity, sexual activity, fetish content, sexual solicitation, unwanted sexual messages and intimate-image abuse are prohibited. Content involving or appearing to involve a minor is forbidden and may be reported to authorities. Do not request or share intimate material.'),
      LegalSection('5. Harassment, hate and violence',
          'Threats, stalking, bullying, humiliation, coercive control, blackmail, doxxing, glorification of violence and hateful attacks based on protected characteristics are prohibited. Compatibility preferences must not be expressed as abuse or dehumanization.'),
      LegalSection('6. Money, scams and unsafe requests',
          'Never request or send money, gift cards, cryptocurrency, bank credentials or OTP codes through a matrimonial interaction. Romance scams, fabricated emergencies, investment schemes, paid matchmaking solicitation and immigration fraud result in removal and may be reported.'),
      LegalSection('7. Privacy and off-platform safety',
          'Do not publish another person’s contact, identity, chat, photo or document without authority. Use in-app chat until trust is established, verify independently, tell a trusted person before meeting and choose a public place. Silarah staff will never ask for your OTP or password.'),
      LegalSection('8. Platform integrity',
          'Do not scrape profiles, automate interests or messages, evade quotas or bans, sell accounts, abuse reports, reverse-engineer safety systems, upload malware or attempt unauthorized access. Do not use information obtained from Silarah to build lists, advertise or discriminate unlawfully.'),
      LegalSection('9. Reporting, evidence and emergencies',
          'Use block and report tools for violations. Preserve relevant messages and explain the concern honestly. False or retaliatory reports are violations. If anyone faces immediate danger, contact local emergency services; Silarah is not an emergency service.'),
      LegalSection('10. Enforcement and appeal',
          'Responses are proportionate to risk and may include warning, content removal, feature limits, verification, visibility limits, suspension or permanent termination. Serious or repeated harm can lead to immediate removal. You may appeal through safety@silarah.com with the account email and relevant facts.'),
    ],
  );

  static const childSafety = LegalDocument(
    id: 'child_safety_standards',
    slug: 'child-safety',
    title: 'Child Safety Standards',
    summary:
        'The adult-only eligibility, reporting, review and enforcement standards used to prevent child sexual abuse and exploitation.',
    sections: [
      LegalSection(
        '1. Adults only',
        'Silarah is strictly for adults aged 18 and over. Members must be legally able to use the service, and adults may not create matrimonial profiles for minors. An account belonging to, representing or appearing to represent a person under 18 may be restricted while age is assessed. Attempts to conceal age, provide a false date of birth or help a minor evade eligibility controls are prohibited.',
      ),
      LegalSection(
        '2. Zero tolerance for exploitation',
        'Silarah prohibits grooming, sexualization of minors, solicitation, trafficking, sextortion, child sexual abuse material (CSAM), synthetic or altered exploitative imagery, requests for such material, and links, instructions or communities that facilitate abuse. This prohibition applies to profiles, photos, biographies, interests, messages, external links and any other feature of the Service.',
      ),
      LegalSection(
        '3. Content and conduct',
        'Members must not upload, request, send, describe, promote, normalize, trade or threaten to distribute exploitative content involving a minor. Attempts to move a suspected minor off-platform, conceal an age concern, evade a safety restriction, intimidate a reporter or preserve prohibited material for personal use are serious violations. Apparent joking, role-play or coded language does not excuse conduct that creates a child-safety risk.',
      ),
      LegalSection(
        '4. Reporting and immediate danger',
        'Members can block and report a profile or conversation in the app and may contact safety@silarah.com for a child-safety concern. Reports should identify the relevant account and explain the concern without downloading, forwarding or redistributing suspected CSAM. If a child is in immediate danger, contact local emergency services or the appropriate child-protection authority first; Silarah is not an emergency service.',
      ),
      LegalSection(
        '5. Review and enforcement',
        'We may immediately restrict access, preserve necessary evidence, remove content, suspend or permanently ban accounts, prevent re-registration and escalate serious matters. Safety action may occur without advance notice when needed to protect a child, prevent distribution or preserve an investigation. A report is assessed using the available account, content, device, moderation and behavioural context, with access limited to authorized safety handling.',
      ),
      LegalSection(
        '6. CSAM response and authorities',
        'When we become aware of apparent CSAM, we take steps to restrict access, preserve only what is necessary and lawful, and report to the relevant authority or designated reporting organization where required. Silarah responds to valid legal requests and cooperates with lawful investigations consistent with applicable law, member rights and evidence-preservation duties. We do not promise a particular investigative or prosecutorial outcome.',
      ),
      LegalSection(
        '7. Privacy and data handling',
        'Child-safety reports and preserved evidence are sensitive and access-restricted. We disclose them only to personnel, service providers, reporting organizations or authorities who need the information for safety handling, legal compliance or a valid investigation. Retention is limited to operational, evidentiary, abuse-prevention and legal needs and follows the Privacy and Data Deletion Policies.',
      ),
      LegalSection(
        '8. Appeals and good-faith reporting',
        'A restricted member may appeal through safety@silarah.com using the account email and relevant facts, but must not email prohibited imagery. An appeal does not automatically restore access or prevent a legally required report. Good-faith reporters are protected from retaliation; knowingly false, malicious or retaliatory reports may themselves result in enforcement.',
      ),
      LegalSection(
        '9. Related standards and contact',
        'These standards operate with the Terms of Service, Privacy Policy, Community Guidelines and Photo Moderation Policy. The designated child-safety contact is safety@silarah.com, and ordinary product support is available at support@silarah.com. Material changes will be published and communicated where legally required.',
      ),
    ],
  );

  static const refund = LegalDocument(
    id: 'refund_policy',
    slug: 'refund-policy',
    title: 'Refund Policy',
    summary:
        'How subscription cancellation, store-managed refunds, duplicate charges and entitlement changes are handled.',
    sections: [
      LegalSection('1. Scope',
          'This Policy applies to paid Silarah subscriptions and features. The price, currency, billing period, renewal date, trial and included benefits shown in the purchase screen control the transaction, subject to mandatory consumer law.'),
      LegalSection('2. App Store purchases',
          'Apple processes App Store payments and decides refund eligibility. Request a refund at reportaproblem.apple.com or through Apple Support. Silarah cannot issue an Apple refund directly. Cancelling an Apple subscription prevents future renewal but does not automatically refund the current period.'),
      LegalSection('3. Google Play purchases',
          'Google Play processes Android payments. Use Google Play order history or Google Play Help to cancel or request a refund. Where platform controls permit, Silarah support may review a Google Play purchase and submit a refund/revoke action, but approval and timing remain subject to Google’s rules and applicable law.'),
      LegalSection('4. Eligibility and fair review',
          'Refunds are not automatically due because you did not find a match, changed your mind, did not use the Service, were incompatible with another member, or had an account action for violating policy. We or the store will consider unauthorized or duplicate charges, material failure to deliver purchased functionality, misleading purchase information and rights under local consumer law. Evidence such as order ID, date, platform and problem description may be required; never send full card details.'),
      LegalSection('5. Cancellation, deletion and entitlements',
          'Deleting the app, pausing a profile or deleting a Silarah account does not cancel an app-store subscription. Cancel through the store before renewal. A granted refund may immediately revoke Premium access. A cancellation without refund normally leaves access until the end of the paid period.'),
      LegalSection('6. Trials and renewals',
          'If a trial is offered, its duration and conversion price appear before purchase. Unless the store says otherwise, it converts to a paid auto-renewing subscription unless cancelled before the displayed deadline. Store account settings are the authoritative source for renewal status.'),
      LegalSection('7. How to get help',
          'For a billing investigation, email support@silarah.com with your Silarah account email, store, order ID and charge date. We aim to acknowledge support requests promptly, but store review and bank settlement times are outside our control. This Policy does not limit non-waivable statutory rights.'),
    ],
  );

  static const deletion = LegalDocument(
    id: 'data_deletion_policy',
    slug: 'data-deletion',
    title: 'Data Deletion Policy',
    summary:
        'How to delete an account or specific data, what the 30-day recovery period means and what limited records may remain.',
    sections: [
      LegalSection('1. In-app account deletion',
          'Signed-in users can open Profile → Settings → Delete Account, choose a reason and type DELETE to confirm. The account is disabled and enters a 30-day recovery period. Signing back in during that period may cancel the request where recovery is still available. After the period, the purge process deletes the authentication account and associated profile data.'),
      LegalSection('2. Web and email requests',
          'If you cannot access the app, email privacy@silarah.com from the account address with the subject “Delete my Silarah account”. We may request proportionate verification before acting. Do not attach an identity document unless our privacy team specifically provides a secure upload route. A public request route is available at silarah.com/data-deletion/.'),
      LegalSection('3. What is deleted',
          'The purge removes or de-identifies the account, profile, preferences, photos and private storage, interests, matches, messages, notification tokens and other user-linked service data, subject to the exceptions below. Content already lawfully received or saved outside Silarah by another member cannot be recalled from that person’s device.'),
      LegalSection('4. Limited retention',
          'We may retain the minimum information necessary for legal obligations, payment and tax records, fraud and abuse prevention, security logs, dispute resolution, enforcement history and proof of consent. Retained records are access-restricted, not used for discovery or marketing, and deleted or de-identified when the applicable purpose or legal period ends. Encrypted backups expire through normal rotation rather than being edited record by record.'),
      LegalSection('5. Specific-data requests',
          'You can edit many profile fields and delete or replace photos without deleting the account. For access, correction, export, restriction or deletion of a particular category, email privacy@silarah.com. We will explain if deletion would make a requested feature unavailable or if law permits us to refuse part of the request.'),
      LegalSection('6. Subscriptions are separate',
          'Account deletion does not cancel billing controlled by Apple or Google. Cancel the subscription in the relevant store before deleting the account. Deletion does not itself create a refund; see the Refund Policy.'),
      LegalSection('7. Timing and confirmation',
          'We begin processing verified requests without undue delay. In-app deletion is scheduled after the stated 30-day recovery period; complex privacy requests follow the deadline required by applicable law. We will confirm completion where contact details remain available. Contact privacy@silarah.com if the process does not behave as described.'),
    ],
  );

  static const privacyRights = LegalDocument(
    id: 'privacy_rights_and_grievance_policy',
    slug: 'privacy-rights',
    title: 'Privacy Rights & Grievance Policy',
    summary:
        'How to access, export, correct or erase data, withdraw consent, submit a complaint and appeal a grievance decision.',
    sections: [
      LegalSection('1. Scope and request channels',
          'This Policy explains the rights-request and grievance process for Silarah members and people whose data may be processed by the Service. Signed-in members should use the account controls where available because authentication provides proportionate identity verification. You may also email privacy@silarah.com for access, correction, consent or deletion requests, grievance@silarah.com for formal complaints, and safety@silarah.com for urgent safety content. Never send passwords, OTP codes, payment credentials or identity documents by ordinary email.'),
      LegalSection('2. Downloading a portable copy',
          'Profile → Settings → Privacy → Download my data creates an authenticated ZIP archive immediately and opens the device save or share sheet. It includes a machine-readable JSON copy of account and profile data, current accessible profile photos, interests, matches, messages, settings, consent records, subscription events, notifications, guardian links, verification decisions, blocks and reports created by you. Repeated generation is briefly rate-limited to protect account data and control database cost.'),
      LegalSection('3. Export limits and assisted access',
          'The self-service archive excludes passwords, OTP codes, raw notification credentials, temporary verification captures, other members’ confidential reports, staff identities, privileged legal material and details that would undermine anti-abuse controls. Those exclusions do not automatically determine the result of a formal legal request. Email privacy@silarah.com if you require an omitted category, an explanation of processing, a summary of data, the identities or categories of processors, or an accessible alternative format. We may redact third-party data and apply lawful exceptions.'),
      LegalSection('4. Correction, erasure and withdrawal',
          'You can correct many profile fields and replace or remove photos in the app. You can pause discovery without deleting the account, or request account deletion in Settings. Consent may be withdrawn through the relevant control or privacy@silarah.com, and withdrawing it must be as easy as giving it. Withdrawal applies prospectively and may disable a feature that cannot operate without the data. Erasure may be limited where retention remains necessary for law, safety, fraud prevention, claims, payments or another permitted purpose.'),
      LegalSection('5. Identity verification and request tracking',
          'We verify a request using the signed-in session, the registered email or proportionate account facts. We do not ask for more data than reasonably needed and will provide a secure route if stronger verification is genuinely necessary. Include the account email, request type and relevant dates. We may ask you to identify the profile field, message, transaction or decision concerned. Duplicate or abusive automated requests may be consolidated without preventing a genuine legal right.'),
      LegalSection('6. Grievance timelines in India',
          'Formal grievances are acknowledged within 24 hours and ordinarily resolved within 7 days under the applicable Indian intermediary rules. Complaints concerning specified removal requests follow the legally shorter deadline, including 36 hours for qualifying unlawful-content complaints and 2 hours for qualifying intimate imagery, nudity, sexual impersonation or similar urgent material. These timelines do not guarantee a requested outcome and may change when amended law imposes a shorter period.'),
      LegalSection('7. Grievance information and evidence',
          'The grievance officer is Imran Ahmed. Send a concise description, account email, dates, relevant profile or conversation reference and the outcome requested to grievance@silarah.com. Do not forward suspected child sexual abuse material or non-consensual intimate imagery by email; identify where it appears so authorized staff can preserve and restrict it safely. We may acknowledge receipt, request necessary clarification, issue a reasoned outcome, preserve required evidence, restrict content or accounts, and notify an authority when law requires.'),
      LegalSection('8. Appeals and external remedies',
          'If you disagree with a grievance decision, reply with the original reference and explain the error. Where the Indian Grievance Appellate Committee has jurisdiction, an eligible appeal may be filed through its prescribed online mechanism within the legally applicable period, currently 30 days from receipt of the grievance officer’s decision. Privacy complaints may also be taken to the competent data-protection authority when its relevant powers and procedures are in force. Nothing here removes a non-waivable court, consumer or regulatory remedy.'),
      LegalSection('9. Security, records and changes',
          'Rights requests and grievance records are access-restricted and used to verify, investigate, respond, audit compliance, prevent abuse and meet legal duties. Required intermediary records and removed content may be preserved for 180 days or a longer period directed by a lawful order; other request records are retained only as needed for proof, security, limitation and legal obligations. Material changes to this process will be published with a new policy version and notified or presented for renewed consent where required.'),
    ],
  );

  static const verification = LegalDocument(
    id: 'verification_policy',
    slug: 'verification-policy',
    title: 'Trust & Verification Policy',
    summary:
        'What photo, phone, email, guardian and account-history checks establish, how temporary captures are handled and how decisions can be challenged.',
    sections: [
      LegalSection('1. Purpose and types of check',
          'Silarah may offer profile-photo review, SMS phone confirmation, email confirmation, guardian connection and established-member indicators. These are separate trust signals. They do not establish legal identity and are not a comprehensive background check.'),
      LegalSection('2. What we collect',
          'For the optional photo check, we process three temporary guided captures (look at camera, gentle smile and blink), the current primary profile photo, submission timestamps, decision status, reviewer notes and deletion audit. We do not request a government ID for this check and do not create or retain facial embeddings or templates.'),
      LegalSection('3. Automated and manual processing',
          'On-device face signals provide capture guidance only. Smile and blink detection may be bypassed through the accessibility fallback. Every submission is decided by an authorized human reviewer comparing the temporary captures with the current profile photo; an on-device score can never grant or reject the badge.'),
      LegalSection('4. Fair-use requirements',
          'Submit your own current, unaltered image. Normal glasses, hijab, niqab and culturally modest clothing are allowed. Do not use filters, screens, masks intended to deceive or another person. Poor lighting, multiple people, mismatch or suspected manipulation may require resubmission or rejection.'),
      LegalSection('5. Badge meaning and limitations',
          'A badge means only that the stated Silarah check passed at a point in time. It does not certify character, intentions, marital status, finances, criminal history, immigration status or safety, and it does not replace independent judgment. We may remove or repeat verification when material information changes or risk is detected.'),
      LegalSection('6. Access, security and retention',
          'Temporary captures are stored privately, shown only through short-lived staff previews, and are never displayed to members or guardians. They are deleted from active verification storage after review and no later than 48 hours after submission. The decision, timestamps, reviewer audit and deletion result may remain for integrity, appeals and legal obligations without retaining the captures.'),
      LegalSection('7. Decision and appeal',
          'The app provides a reason or next step when possible. You may retry after correcting quality issues or appeal through safety@silarah.com. Include your account email and decision date, but do not email identity documents. Staff may request a new secure submission. Appeals do not guarantee approval.'),
      LegalSection('8. Regional availability and phone confirmation',
          'The initial service launch is limited to enabled launch markets shown in the app; phone confirmation is currently limited to enabled launch-country numbers. Silarah will never ask for your email or phone OTP outside the official in-app verification flow. Women do not need phone confirmation for free messaging. Premium is activated before phone confirmation becomes available. Men then complete SMS confirmation before sending. A phone badge appears only after successful SMS confirmation, never from a purchase alone. While Premium is active, a confirmed number can be changed from Profile → Trust checks → Phone number using a new OTP. Changing it does not cancel or shorten the store subscription.'),
    ],
  );

  static const photoModeration = LegalDocument(
    id: 'photo_moderation_policy',
    slug: 'photo-moderation-policy',
    title: 'Photo Moderation Policy',
    summary:
        'Rules and automated safety checks for profile photos, plus review, privacy and appeal procedures.',
    sections: [
      LegalSection('1. Scope',
          'This Policy applies to profile and gallery photos. It is separate from the optional profile-photo trust check. Passing automated photo moderation does not grant a trust badge, and a trust badge does not exempt a photo from these rules.'),
      LegalSection('2. What profile photos must show',
          'Photos must be genuine, usable images relevant to the account member. Group and culturally modest photos, including hijab, niqab and traditional clothing, are permitted when otherwise compliant. You must have permission to upload images containing other adults. Images whose primary purpose is text, scenery, advertising, a random object or impersonation may be rejected as unsuitable for a matrimonial profile.'),
      LegalSection('3. Prohibited images',
          'Do not upload nudity, sexual activity, sexually explicit or fetish content, lingerie-focused or sexualized imagery, swimwear or bikini imagery intended or assessed as unsuitable for this matrimonial context, exploitation, violence, hate symbols, illegal content, intimate images shared without consent, images of minors used deceptively, contact advertising, watermarked stolen photos or malicious files.'),
      LegalSection('4. Automated checks',
          'Before publication, the app validates that the file is a decodable image, uses on-device object signals to assess human presence and uses an on-device safety classifier to detect explicit content. Server validation checks that the upload is authorized and accompanied by a valid moderation result. We do not publish model thresholds because doing so would help evasion. Automated systems can be wrong and may change as safety improves.'),
      LegalSection('5. Approval and review',
          'Photos assessed as compliant may publish without advance administrator approval. High-confidence explicit-content results are blocked and may be placed in a restricted moderation queue for authorized review. Members and staff may report or review a previously approved photo when new context or risk appears. We may remove, blur or restrict a photo while investigating.'),
      LegalSection('6. Photo privacy',
          'Moderation approval and visibility are different controls. You can select public, mutual-interest or request-to-view privacy. Access decisions are enforced by signed media access and account permissions, but recipients may still capture what they can view. Do not upload a photo you cannot tolerate an authorized recipient seeing.'),
      LegalSection('7. Decisions and appeals',
          'The app gives a practical reason when possible, such as unsupported image, no person detected or explicit content. Try a different clear image if the result is a quality error. To challenge a moderation decision, email safety@silarah.com with the account email and approximate upload time; do not attach prohibited content to ordinary email.'),
      LegalSection('8. Enforcement',
          'Repeated attempts to upload prohibited content, manipulate scores or bypass upload controls may lead to feature limits, suspension or termination. Apparent child sexual exploitation or other serious unlawful material may be preserved and reported as required by law.'),
    ],
  );

  static const guardian = LegalDocument(
    id: 'guardian_wali_policy',
    slug: 'guardian-policy',
    title: 'Guardian / Wali Policy',
    summary:
        'How guardian linking, chat visibility, active participation, consent and unlinking work on Silarah.',
    sections: [
      LegalSection('1. Optional support feature',
          'Guardian mode lets an adult member involve a trusted guardian or wali in matrimonial conversations. It is optional unless the member chooses it or a lawful safety requirement applies. Silarah does not appoint a wali or decide whether a person has religious or legal authority for a marriage.'),
      LegalSection('2. Adult member control and consent',
          'The adult profile owner (the “ward” in this Policy) chooses whether to enable guardian mode, supplies guardian details and selects available permissions. A guardian must know they are being linked and use their own authorized account. Do not secretly enrol, monitor or control another adult.'),
      LegalSection('3. Linking and verification',
          'A link may require a matching invitation, contact verification or other security checks. Guardian contact information is not publicly displayed. Silarah may pause or reject a link when identity, authority, consent or account safety cannot be established.'),
      LegalSection('4. Passive and active modes',
          'In passive mode, a guardian may receive read-only access to linked conversations and relevant match context. In active mode, where offered and enabled, a guardian may approve a match or send a message in the linked workflow. Guardian-originated activity is recorded and should be distinguishable; a guardian may not secretly impersonate the member.'),
      LegalSection('5. Privacy of all participants',
          'When guardian chat mirroring is enabled, conversation participants should expect messages in that conversation to be visible to the linked guardian. Guardian access is limited by account permissions and row-level controls. Guardians must not copy, publish or misuse member information and must comply with the Terms and Community Guidelines.'),
      LegalSection('6. Unlinking and access changes',
          'The adult member may disable guardian mode or change permissions in Settings, subject to security checks and any action already completed. Unlinking stops future authorized access but cannot erase copies a guardian lawfully received or actions already recorded. Silarah may unlink or restrict a guardian for misuse or safety risk.'),
      LegalSection('7. Safety and disagreements',
          'Guardian involvement does not replace the adult member’s consent, independent judgment or local legal requirements. Threats, coercive control, forced marriage, harassment or misuse of private messages are prohibited. Use block/report tools and contact safety@silarah.com; contact local emergency or specialist services where anyone is at risk.'),
      LegalSection('8. No legal or religious determination',
          'Family and wali requirements vary by school of thought and jurisdiction. Silarah provides communication tools, not legal, religious or marriage solemnization advice. Members and families should consult qualified local advisers for their circumstances.'),
    ],
  );

  static const all = <LegalDocument>[
    terms,
    privacy,
    community,
    childSafety,
    refund,
    deletion,
    privacyRights,
    verification,
    photoModeration,
    guardian,
  ];

  static LegalDocument fromType(String type) {
    final normalized = switch (type) {
      'tos' => 'terms',
      'guidelines' => 'community-guidelines',
      'child-safety' || 'csae' => 'child-safety',
      'refund' => 'refund-policy',
      'deletion' => 'data-deletion',
      'rights' || 'grievance' || 'data-access' => 'privacy-rights',
      'kyc' || 'verification' => 'verification-policy',
      'photos' || 'photo-moderation' => 'photo-moderation-policy',
      'guardian' || 'wali' => 'guardian-policy',
      _ => type,
    };
    return all.firstWhere(
      (document) => document.slug == normalized || document.id == normalized,
      orElse: () => privacy,
    );
  }
}
