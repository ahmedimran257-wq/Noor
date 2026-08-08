// SILARAH — Guardian (Wali) Dashboard Screen
//
// Full in-app chat mirror for guardians. This is the guardian's
// primary interface when they log in. Shows all active
// conversations their ward is engaged in, with:
//   • Live message updates via Supabase Realtime
//   • Unread message badges
//   • Match approval controls (active mode)
//   • Read-only or interactive chat access
//
// This is SILARAH's biggest competitive moat against Muzz/Salams.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final _waliService = WaliModeService.instance;
  List<GuardianDashboardItem> _chats = [];
  bool _isLoading = true;
  bool _isRealtimeConnected = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (SupabaseService.isInitialized) {
      _waliService.disposeRealtime();
    }
    super.dispose();
  }

  Future<void> _loadDashboard({String? markSeenWardId}) async {
    if (!SupabaseService.isInitialized) {
      if (mounted) {
        setState(() {
          _chats = [];
          _isLoading = false;
        });
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final chats = await _waliService.getDashboard(
        markSeenWardId: markSeenWardId,
      );
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtime() {
    if (!SupabaseService.isInitialized) return;
    _waliService.subscribeToMirroredChats(
      onNewMessage: (message) {
        // Refresh dashboard to update unread counts and last message
        _loadDashboard();
      },
      onStatusChange: (connected) {
        if (mounted) {
          setState(() => _isRealtimeConnected = connected);
        }
      },
    );
  }

  Future<void> _handleApproveMatch(GuardianDashboardItem chat) async {
    HapticFeedback.mediumImpact();
    try {
      await _waliService.approveMatch(chat.matchId);
      await _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
              'Match approved — ${chat.wardName} can now message ${chat.otherPartyName}',
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.verifiedTeal),
              ),
            ),
            backgroundColor: AppColors.verifiedTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
              'Failed to approve match: $e',
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.errorRed),
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleMarkSeen(GuardianDashboardItem chat) async {
    await _loadDashboard(markSeenWardId: chat.wardUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            UiText('سيلارا',
                style: AppTypography.wordmark.copyWith(fontSize: 22)),
            const SizedBox(width: AppDimensions.space6),
            UiText(context.uiCopy('GUARDIAN'),
                style: AppTypography.wordmark.copyWith(fontSize: 16)),
            const Spacer(),
            // Realtime connection indicator
            _RealtimeIndicator(isConnected: _isRealtimeConnected),
          ],
        ),
      ),
      body: _isLoading
          ? const _DashboardShimmer()
          : _chats.isEmpty
              ? const _EmptyDashboard()
              : RefreshIndicator(
                  color: AppColors.champagneGold,
                  backgroundColor: AppColors.obsidianNight,
                  onRefresh: _loadDashboard,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical: AppDimensions.space12,
                    ),
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.space10),
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return _ChatTile(
                        chat: chat,
                        onTap: () => _handleMarkSeen(chat),
                        onApprove: chat.needsApproval
                            ? () => _handleApproveMatch(chat)
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}

// Realtime Connection Indicator
class _RealtimeIndicator extends StatelessWidget {
  const _RealtimeIndicator({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? AppColors.verifiedTeal : AppColors.slateMist,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: AppColors.verifiedTeal.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        UiText(
          isConnected ? 'Live' : 'Offline',
          style: AppTypography.caption.copyWith(
            color: isConnected ? AppColors.verifiedTeal : AppColors.slateMist,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Chat Tile
class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    this.onApprove,
  });

  final GuardianDashboardItem chat;
  final VoidCallback onTap;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: chat.hasUnread
                ? AppColors.champagneGold.withValues(alpha: 0.5)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main chat info row
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Row(
                children: [
                  // Avatar placeholder or photo
                  _Avatar(
                    photoUrl: chat.otherPartyPhoto,
                    hasUnread: chat.hasUnread,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  // Chat details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ward name & other party
                        Row(
                          children: [
                            UiText(
                              chat.wardName,
                              style: AppTypography.captionMedium.copyWith(
                                color: AppColors.champagneGold,
                                fontSize: 11,
                              ),
                            ),
                            UiText(
                              '  ↔  ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.slateMist,
                                fontSize: 10,
                              ),
                            ),
                            Expanded(
                              child: UiText(
                                chat.otherPartyName,
                                style: AppTypography.captionMedium.copyWith(
                                  color: AppColors.pearlWhite,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Last message preview
                        UiText(
                          chat.lastMessage ?? 'No messages yet',
                          style: AppTypography.caption.copyWith(
                            color: chat.hasUnread
                                ? AppColors.pearlWhite
                                : AppColors.slateMist,
                            fontWeight: chat.hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  // Right side: time + unread badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chat.lastMessageAt != null)
                        UiText(
                          _formatTime(context, chat.lastMessageAt!),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: chat.hasUnread
                                ? AppColors.champagneGold
                                : AppColors.slateMist,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (chat.hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.champagneGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: UiText(
                            '${chat.unreadCount}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.obsidianNight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Guardian approval banner (active mode, pending matches)
            if (onApprove != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppDimensions.radiusCard),
                    bottomRight: Radius.circular(AppDimensions.radiusCard),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.champagneGold,
                      size: 16,
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: UiText(
                        context.uiCopy('Awaiting your approval'),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onApprove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space12,
                          vertical: AppDimensions.space4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.champagneGold,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusChip),
                        ),
                        child: UiText(
                          context.uiCopy('Approve'),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.obsidianNight,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Mode badge
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.space16,
                right: AppDimensions.space16,
                bottom: AppDimensions.space10,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: chat.guardianMode == 'active'
                          ? AppColors.verifiedTeal.withValues(alpha: 0.15)
                          : AppColors.surfaceGlassHover,
                      border: Border.all(
                        color: chat.guardianMode == 'active'
                            ? AppColors.verifiedTeal.withValues(alpha: 0.5)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: UiText(
                      chat.guardianMode == 'active' ? 'ACTIVE' : 'VIEWING',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: chat.guardianMode == 'active'
                            ? AppColors.verifiedTeal
                            : AppColors.slateMist,
                      ),
                    ),
                  ),
                  const Spacer(),
                  UiText(
                    chat.matchStatus.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.slateMist,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return context.uiCopy('now');
    if (diff.inMinutes < 60) return context.uiMinutesShort(diff.inMinutes);
    if (diff.inHours < 24) return context.uiHoursShort(diff.inHours);
    if (diff.inDays < 7) return context.uiDaysShort(diff.inDays);
    return '${time.day}/${time.month}';
  }
}

// Avatar
class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl, required this.hasUnread});
  final String? photoUrl;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasUnread ? AppColors.champagneGold : AppColors.cardBorder,
          width: hasUnread ? 2 : 1,
        ),
        color: AppColors.surfaceGlassHover,
      ),
      child: photoUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 144,
                maxWidthDiskCache: 192,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  color: AppColors.slateMist,
                  size: 24,
                ),
              ),
            )
          : Icon(Icons.person, color: AppColors.slateMist, size: 24),
    );
  }
}

// Empty Dashboard
class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder, width: 2),
                color: AppColors.goldGlow,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: AppColors.champagneGold,
                size: 36,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            UiText(
              context.uiCopy('No Active Conversations'),
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space12),
            UiText(
              context.uiCopy(
                'Your ward hasn\'t started any conversations yet.\n'
                'You\'ll see their chats here when they do.',
              ),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard Shimmer
class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.space16),
      itemCount: 4,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space10),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
