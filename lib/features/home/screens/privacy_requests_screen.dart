import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';
import '../../../l10n/ui_copy.dart';

/// Injectable boundary for authenticated intake; production access still uses RLS.
abstract interface class PrivacyRequestsProvider {
  Future<List<Map<String, dynamic>>> load();
  Future<void> submit({
    required String requestKey,
    required String kind,
    required String details,
  });
}

class _SupabasePrivacyRequestsProvider implements PrivacyRequestsProvider {
  const _SupabasePrivacyRequestsProvider();

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw StateError('authentication_required');
    return await SupabaseService.client
        .from('privacy_requests')
        .select('id,kind,status,response,created_at,due_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
  }

  @override
  Future<void> submit({
    required String requestKey,
    required String kind,
    required String details,
  }) async {
    await SupabaseService.client.rpc('submit_my_privacy_request', params: {
      'p_request_key': requestKey,
      'p_kind': kind,
      'p_details': details,
    });
  }
}

/// Authenticated intake; submissions never imply that erasure has completed.
class PrivacyRequestsScreen extends StatefulWidget {
  const PrivacyRequestsScreen({super.key, this.provider});

  final PrivacyRequestsProvider? provider;
  @override
  State<PrivacyRequestsScreen> createState() => _PrivacyRequestsScreenState();
}

class _PrivacyRequestsScreenState extends State<PrivacyRequestsScreen> {
  final _details = TextEditingController();
  String _kind = 'access';
  String _key = const Uuid().v4();
  String? _submittedPayload;
  bool _busy = false;
  bool _loading = true;
  int _loadGeneration = 0;
  String? _error;
  String? _loadError;
  List<Map<String, dynamic>> _requests = [];
  late final PrivacyRequestsProvider _provider =
      widget.provider ?? const _SupabasePrivacyRequestsProvider();

  static const _kindLabels = {
    'access': 'Access',
    'correction': 'Correction',
    'erasure': 'Erasure',
    'withdrawal': 'Withdrawal',
    'nomination': 'Nomination',
    'grievance': 'Grievance',
  };
  static const _statusLabels = {
    'received': 'Received',
    'reviewing': 'Under review',
    'resolved': 'Resolved',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    try {
      final rows = await _provider.load();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _requests = rows;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadError =
            'Requests could not be loaded. Retry or contact privacy@silarah.com.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final details = _details.text.trim();
    if (details.length < 10) {
      setState(() =>
          _error = 'Please describe your request in at least 10 characters.');
      return;
    }
    final payload = '$_kind\n$details';
    if (_submittedPayload != null && _submittedPayload != payload) {
      _key = const Uuid().v4();
    }
    _submittedPayload = payload;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _provider.submit(requestKey: _key, kind: _kind, details: details);
      if (!mounted) return;
      _details.clear();
      _key = const Uuid().v4();
      _submittedPayload = null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: UiText(
              'Request received. Keep the reference below to follow its progress.')));
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'We could not confirm receipt. Retry safely, or contact privacy@silarah.com. A maximum of five new requests can be submitted per day.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UiText('Privacy requests')),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const UiText('Your data. Your choices.',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const UiText(
                    'Request access, correction, erasure, consent withdrawal, nomination or raise a privacy grievance. We aim to respond within 7 days. Check this page for our response. For assistance: privacy@silarah.com.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('privacy-request-kind'),
                  initialValue: _kind,
                  isExpanded: true,
                  itemHeight: null,
                  decoration:
                      const InputDecoration(label: UiText('Request type')),
                  items: _kindLabels.entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: UiText(entry.value)))
                      .toList(),
                  onChanged:
                      _busy ? null : (value) => setState(() => _kind = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                    key: const ValueKey('privacy-request-details'),
                    controller: _details,
                    enabled: !_busy,
                    maxLength: 2000,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                        label: UiText('How can we help?'),
                        helper: UiText(
                            'Do not include passwords, OTPs, ID documents or payment details.'))),
                if (_kind == 'withdrawal' || _kind == 'erasure')
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: UiText(
                          'This submits a request for review; it does not immediately stop processing or delete your account. You can pause discovery or request account deletion in Settings. Store subscriptions must be cancelled separately.')),
                if (_kind == 'nomination')
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: UiText(
                          'Tell us you want to nominate someone to exercise your rights on death or incapacity. We will explain verification and request only necessary details. Do not upload their documents here.')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: UiText(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                FilledButton(
                    key: const ValueKey('privacy-request-submit'),
                    onPressed: _busy ? null : _submit,
                    child: UiText(_busy ? 'Submitting…' : 'Submit request')),
                const SizedBox(height: 32),
                Row(children: [
                  const Expanded(
                      child: UiText('Your requests',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600))),
                  IconButton(
                      onPressed: _loading ? null : _load,
                      tooltip: UiCopy.localize(context, 'Refresh requests'),
                      icon: const Icon(Icons.refresh))
                ]),
                if (_loading) const UiText('Loading requests…'),
                if (_loadError != null)
                  UiText(_loadError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (!_loading && _loadError == null && _requests.isEmpty)
                  const UiText('No requests to show. Pull down to refresh.'),
                ..._requests.map((request) => Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UiText.verbatim(
                                '${UiCopy.localize(context, _kindLabels[request['kind']] ?? 'Privacy request')} · ${UiCopy.localize(context, _statusLabels[request['status']] ?? 'Status unavailable')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SelectableText(UiCopy.localize(
                                    context, 'Reference: {reference}')
                                .replaceAll('{reference}',
                                    '\u2068${request['id']}\u2069')),
                            UiText.verbatim(UiCopy.localize(
                                    context, 'Response target: {date}')
                                .replaceAll('{date}',
                                    _dueDate(context, request['due_at']))),
                            if ((request['response'] as String? ?? '')
                                .isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  // Staff-authored content is not a UI lookup key.
                                  child: UiText.verbatim(
                                      request['response'] as String)),
                          ],
                        )))),
              ],
            )),
      );

  String _dueDate(BuildContext context, Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return UiCopy.localize(context, 'Date unavailable');
    return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }
}
