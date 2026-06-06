// lib/features/home/screens/block_list_screen.dart
// ============================================================
// NOOR — Block List Screen (Item 29)
//
// Shows all blocked profiles from BlockReportCubit.
// Each row: avatar, name, age, city, Unblock button.
// Empty state: NoorEmptyState with block icon.
// Navigate from Settings → Safety → "Blocked Profiles".
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/noor_empty_state.dart';

class BlockListScreen extends StatelessWidget {
  const BlockListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlockReportCubit, BlockReportState>(
      builder: (context, state) {
        final blocked = state.blockedUsers;

        // Match blocked IDs against mock profiles for rich display
        final mockMatches = kMockProfiles
            .where((p) => blocked.any((b) => b.userId == p.id))
            .toList();

        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          appBar: _BlockListAppBar(count: blocked.length),
          body: blocked.isEmpty
              ? const NoorEmptyState(
                  icon:     Icons.block_rounded,
                  title:    'No blocked profiles',
                  subtitle: 'Profiles you block will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                    vertical:   AppDimensions.space16,
                  ),
                  itemCount:      blocked.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.space12),
                  itemBuilder: (_, i) {
                    final b = blocked[i];
                    // Try to find the mock profile for richer data
                    final mock = mockMatches.cast<MockProfile?>()
                        .firstWhere((p) => p?.id == b.userId,
                            orElse: () => null);
                    return _BlockedTile(
                      blockedUser: b,
                      mock:        mock,
                      onUnblock: () =>
                          _showUnblockDialog(context, b),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showUnblockDialog(BuildContext context, BlockedUser user) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Text('Unblock this person?',
            style: AppTypography.bodyMedium.copyWith(
                color: AppColors.pearlWhite, fontSize: 17)),
        content: Text(
          '${user.name} ${user.lastInitial}. will be able to find your profile again.',
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTypography.caption.copyWith(
                    color: AppColors.slateMist)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BlockReportCubit>().unblockUser(user.userId);
            },
            child: Text('Unblock',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.champagneGold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────

class _BlockListAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BlockListAppBar({required this.count});
  final int count;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:  AppColors.surfaceGlass,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.pearlWhite,
                  size:  AppDimensions.iconSizeMedium),
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blocked Profiles', style: AppTypography.bodyMedium),
                if (count > 0)
                  Text('$count blocked',
                      style: AppTypography.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blocked Tile ──────────────────────────────────────────────

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({
    required this.blockedUser,
    required this.onUnblock,
    this.mock,
  });
  final BlockedUser  blockedUser;
  final MockProfile? mock;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final name = '${blockedUser.name} ${blockedUser.lastInitial}.';
    final sub  = mock != null
        ? '${mock!.age} · ${mock!.cityName}'
        : 'Blocked profile';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width:  48,
            height: 48,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  AppColors.surfaceGlassHover,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.slateMist,
              size:  26,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space2),
                Text(sub, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Unblock button
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.cardBorder),
              foregroundColor: AppColors.pearlWhite,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14,
                vertical:   AppDimensions.space8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            child: Text('Unblock',
                style: AppTypography.caption.copyWith(
                    color: AppColors.pearlWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
