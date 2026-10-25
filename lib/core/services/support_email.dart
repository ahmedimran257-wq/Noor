/// Which Silarah inbox a member is writing to from Help & Support.
enum SupportInbox {
  support(
    'support@silarah.com',
    'Help with my Silarah account',
    'Tell us what happened and what you expected instead. A screenshot helps.',
  ),
  safety(
    'safety@silarah.com',
    'Safety concern on Silarah',
    'Tell us what happened, who was involved if you know, and when. '
        'If anyone is in immediate danger, contact local emergency services first.',
  ),
  grievance(
    'grievance@silarah.com',
    'Formal grievance',
    'Describe your grievance and the outcome you are asking for. '
        'We acknowledge every grievance within 24 hours.',
  );

  const SupportInbox(this.address, this.subject, this.prompt);

  final String address;
  final String subject;
  final String prompt;
}

/// Builds the mailto link for a Help & Support inbox, with a short prefilled
/// body that gives the team what it needs to find the account.
///
/// Encodes with %20 rather than [Uri.queryParameters]: that form-encodes
/// spaces as `+`, which Gmail and Apple Mail show literally in the subject.
Uri supportEmailUri(
  SupportInbox inbox, {
  String? appVersion,
  String? device,
  String? memberId,
}) {
  final details = [
    if (appVersion != null && appVersion.isNotEmpty) 'App: Silarah $appVersion',
    if (device != null && device.isNotEmpty) 'Device: $device',
    if (memberId != null && memberId.length >= 8)
      'Member reference: ${memberId.substring(0, 8)}',
  ];
  final body = [
    'Assalamu alaikum Silarah team,',
    '',
    inbox.prompt,
    '',
    '',
    '',
    if (details.isNotEmpty) ...[
      '— Please keep these details so we can find your account —',
      ...details,
      '',
    ],
    'Please never send OTP codes, passwords or card details.',
  ].join('\n');
  return Uri.parse(
    'mailto:${inbox.address}'
    '?subject=${Uri.encodeComponent(inbox.subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}
