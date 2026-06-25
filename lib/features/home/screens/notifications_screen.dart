// lib/features/home/screens/notifications_screen.dart
// ============================================================
// MITHAQ — Notifications Screen (Feature 11)
// Shows all notifications with read/unread state.
// AppBar: "Mark all read" text button.
// Each row: type icon in colored circle + title + body + time.
// Unread rows: gold 3px left border.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor:  AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color:  AppColors.surfaceGlass,
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.pearlWhite,
              size:  AppDimensions.iconSizeMedium,
            ),
          ),
        ),
        title: Text(AppLocalizations.of(context).notifications_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    context.read<NotificationsCubit>().markAllRead(),
                child: Text(
                  AppLocalizations.of(context).notifications_markAllRead,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppDimensions.space8),
        ],
      ),

      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            itemCount:        state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = state.items[i];
              return _NotificationTile(
                item: item,
                onTap: () =>
                    context.read<NotificationsCubit>().markRead(item.id),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) {
    final iconData  = _iconFor(item.type);
    final iconColor = _colorFor(item.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: item.isRead
              ? Border.all(color: AppColors.cardBorder)
              : const Border(
                  left:   BorderSide(
                      color: AppColors.champagneGold, width: 3),
                  top:    BorderSide(color: AppColors.cardBorder),
                  right:  BorderSide(color: AppColors.cardBorder),
                  bottom: BorderSide(color: AppColors.cardBorder),
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                  border: Border.all(
                      color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppDimensions.space12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: item.isRead
                                ? AppTypography.body
                                : AppTypography.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space8),
                        Text(
                          _timeLabel(item.time),
                          style: AppTypography.caption,
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: AppDimensions.space6),
                          Container(
                            width:  7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.champagneGold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      item.body,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  IconData _iconFor(String type) {
    switch (type) {
      case 'interest_received':  return Icons.favorite_rounded;
      case 'interest_accepted':  return Icons.check_circle_rounded;
      case 'new_message':        return Icons.chat_bubble_rounded;
      case 'boost_ready':        return Icons.rocket_launch_rounded;
      case 'profile_approved':   return Icons.verified_rounded;
      default:                   return Icons.lightbulb_outline_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'interest_received':  return AppColors.champagneGold;
      case 'interest_accepted':  return AppColors.verifiedTeal;
      case 'new_message':        return AppColors.messageBlue;
      case 'boost_ready':        return AppColors.champagneGold;
      case 'profile_approved':   return AppColors.verifiedTeal;
      default:                   return AppColors.slateMist;
    }
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder, width: 2),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.slateMist,
              size:  48,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          Text(
            AppLocalizations.of(context).notifications_empty_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            AppLocalizations.of(context).notifications_empty_subtitle,
            style: AppTypography.bodyMuted,
          ),
        ],
      ),
    );
  }
}
