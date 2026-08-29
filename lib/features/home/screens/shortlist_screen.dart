import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/services/authorized_profile_service.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/shortlist_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import 'profile_detail_screen.dart';
import 'subscription_screen.dart';

String shortlistCategoryLabel(ShortlistCategory category) => switch (category) {
      ShortlistCategory.saved => 'Saved',
      ShortlistCategory.strongMatch => 'Strong match',
      ShortlistCategory.discussWithFamily => 'Discuss with family',
      ShortlistCategory.followUp => 'Follow up',
    };

Future<ShortlistDetail?> showShortlistEditor(
  BuildContext context, {
  required String savedUserId,
  required String firstName,
  ShortlistDetail? initial,
}) {
  return showModalBottomSheet<ShortlistDetail>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShortlistEditorSheet(
      savedUserId: savedUserId,
      firstName: firstName,
      initial: initial,
    ),
  );
}

class ShortlistScreen extends StatefulWidget {
  const ShortlistScreen({super.key});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  bool _loading = true;
  String? _error;
  List<DiscoveryProfile> _profiles = const [];
  Map<String, ShortlistDetail> _details = const {};
  ShortlistCategory? _filter;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    if (!context.read<SubscriptionCubit>().state.canOrganizeShortlists) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        BookmarkService.load(force: force),
        ShortlistService.instance.load(force: force),
      ]);
      final ids = results[0] as Set<String>;
      final details = results[1] as Map<String, ShortlistDetail>;
      final profiles =
          await AuthorizedProfileService.loadDiscoveryProfiles(ids.take(50));
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _edit(DiscoveryProfile profile) async {
    final result = await showShortlistEditor(
      context,
      savedUserId: profile.id,
      firstName: profile.firstName,
      initial: _details[profile.id],
    );
    if (result != null && mounted) {
      setState(() => _details = {..._details, profile.id: result});
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: UiText(context.uiCopy('Private shortlist')),
        actions: [
          IconButton(
            tooltip: context.uiCopy('Refresh'),
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !subscription.canOrganizeShortlists
          ? _LockedShortlist(onUpgrade: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
              if (mounted) unawaited(_load(force: true));
            })
          : _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: AppColors.softCoral, size: 36),
              const SizedBox(height: 12),
              UiText(context.uiCopy('Your shortlist could not be loaded.'),
                  style: AppTypography.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(force: true),
                child: UiText(context.uiCopy('Try again')),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filter == null
        ? _profiles
        : _profiles
            .where((profile) =>
                (_details[profile.id]?.category ?? ShortlistCategory.saved) ==
                _filter)
            .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.champagneGold.withValues(alpha: 0.16),
                    AppColors.verifiedTeal.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_person_outlined,
                        color: AppColors.champagneGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(context.uiCopy('Only you can see this'),
                              style: AppTypography.bodyMedium),
                          const SizedBox(height: 3),
                          UiText(
                            context.uiCopy(
                                'Categories, family notes and reminders are private and are never shown to the saved member.'),
                            style: AppTypography.caption.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 54,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: context.uiCopy('All saved'),
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...ShortlistCategory.values.map((category) => _FilterChip(
                        label: context.uiCopy(shortlistCategoryLabel(category)),
                        selected: _filter == category,
                        onTap: () => setState(() => _filter = category),
                      )),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: UiText(
                    context.uiCopy(
                        'Save a profile, then organize it here for a thoughtful family discussion.'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(height: 1.5),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final profile = visible[index];
                  return _ShortlistProfileCard(
                    profile: profile,
                    detail: _details[profile.id],
                    onEdit: () => _edit(profile),
                    onOpen: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileDetailScreen(
                            profile: profile,
                            heroTag: 'shortlist-profile-${profile.id}',
                          ),
                        ),
                      );
                      if (mounted) unawaited(_load(force: true));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LockedShortlist extends StatelessWidget {
  const _LockedShortlist({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmarks_outlined,
                  color: AppColors.champagneGold, size: 42),
              const SizedBox(height: 14),
              UiText(context.uiCopy('Plan privately with Premium'),
                  style: AppTypography.userName.copyWith(fontSize: 24),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              UiText(
                context.uiCopy(
                    'Organize saved profiles, add private family notes and set gentle follow-up reminders.'),
                style: AppTypography.bodyMedium.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpgrade,
                  child: UiText(context.uiCopy('Explore Premium')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: UiText(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _ShortlistProfileCard extends StatelessWidget {
  const _ShortlistProfileCard({
    required this.profile,
    required this.detail,
    required this.onOpen,
    required this.onEdit,
  });
  final DiscoveryProfile profile;
  final ShortlistDetail? detail;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final category = detail?.category ?? ShortlistCategory.saved;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SilarahPressable(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: profile.photoUrl == null
                  ? Container(
                      width: 76,
                      height: 92,
                      color: AppColors.surfaceGlassHover,
                      child: Icon(Icons.person_outline_rounded,
                          color: AppColors.slateMist),
                    )
                  : SilarahBlurImage(
                      imageUrl: profile.photoUrl!,
                      blurhash: profile.blurhash,
                      width: 76,
                      height: 92,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(profile.firstName, style: AppTypography.bodyMedium),
                const SizedBox(height: 3),
                UiText('${profile.age} · ${profile.cityName}',
                    style: AppTypography.caption),
                const SizedBox(height: 8),
                UiText(context.uiCopy(shortlistCategoryLabel(category)),
                    style: AppTypography.captionMedium.copyWith(
                      color: AppColors.champagneGold,
                    )),
                if (detail?.privateNote != null) ...[
                  const SizedBox(height: 5),
                  UiText(detail!.privateNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption),
                ],
                if (detail?.hasPendingReminder == true) ...[
                  const SizedBox(height: 5),
                  UiText(
                    '${context.uiCopy('Reminder')} · ${DateFormat.MMMd().add_jm().format(detail!.remindAt!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.verifiedTeal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.uiCopy('Edit private note'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
    );
  }
}

class _ShortlistEditorSheet extends StatefulWidget {
  const _ShortlistEditorSheet({
    required this.savedUserId,
    required this.firstName,
    required this.initial,
  });
  final String savedUserId;
  final String firstName;
  final ShortlistDetail? initial;

  @override
  State<_ShortlistEditorSheet> createState() => _ShortlistEditorSheetState();
}

class _ShortlistEditorSheetState extends State<_ShortlistEditorSheet> {
  late ShortlistCategory _category;
  late final TextEditingController _noteController;
  DateTime? _remindAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initial?.category ?? ShortlistCategory.saved;
    _noteController = TextEditingController(text: widget.initial?.privateNote);
    _remindAt = widget.initial?.hasPendingReminder == true
        ? widget.initial!.remindAt
        : null;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await ShortlistService.instance.save(
        savedUserId: widget.savedUserId,
        category: _category,
        privateNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        remindAt: _remindAt,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.goldBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                UiText(
                  '${context.uiCopy('Private shortlist')} · ${widget.firstName}',
                  style: AppTypography.userName.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 5),
                UiText(
                  context.uiCopy('Only you can see these details.'),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ShortlistCategory.values
                      .map((category) => ChoiceChip(
                            label: UiText(context
                                .uiCopy(shortlistCategoryLabel(category))),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: context.uiCopy('Private family note'),
                    hintText: context
                        .uiCopy('Add questions or points to discuss later.'),
                  ),
                ),
                const SizedBox(height: 10),
                UiText(context.uiCopy('Gentle reminder'),
                    style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReminderChoice(
                      label: 'None',
                      selected: _remindAt == null,
                      onTap: () => setState(() => _remindAt = null),
                    ),
                    ...[
                      ('Tomorrow', const Duration(days: 1)),
                      ('In 3 days', const Duration(days: 3)),
                      ('In 1 week', const Duration(days: 7)),
                    ].map((choice) => _ReminderChoice(
                          label: choice.$1,
                          selected: _remindAt != null &&
                              _remindAt!
                                      .difference(DateTime.now())
                                      .inHours
                                      .abs() >=
                                  choice.$2.inHours - 2 &&
                              _remindAt!
                                      .difference(DateTime.now())
                                      .inHours
                                      .abs() <=
                                  choice.$2.inHours + 2,
                          onTap: () => setState(
                            () => _remindAt = DateTime.now().add(choice.$2),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: UiText(context.uiCopy('Save private details')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderChoice extends StatelessWidget {
  const _ReminderChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: UiText(context.uiCopy(label)),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}
