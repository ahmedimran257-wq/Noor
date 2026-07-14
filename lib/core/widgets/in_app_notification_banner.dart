import 'dart:async';

import 'package:flutter/material.dart';

import '../cubits/notifications/notifications_cubit.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

class InAppNotificationBannerHost extends StatefulWidget {
  const InAppNotificationBannerHost({
    super.key,
    required this.child,
    required this.notifications,
    required this.onTap,
  });

  final Widget child;
  final Stream<NotificationItem> notifications;
  final ValueChanged<NotificationItem> onTap;

  @override
  State<InAppNotificationBannerHost> createState() =>
      _InAppNotificationBannerHostState();
}

class _InAppNotificationBannerHostState
    extends State<InAppNotificationBannerHost> {
  StreamSubscription<NotificationItem>? _subscription;
  Timer? _dismissTimer;
  NotificationItem? _item;
  bool _visible = false;
  int _presentation = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant InAppNotificationBannerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifications != widget.notifications) _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.notifications.listen(_show);
  }

  void _show(NotificationItem item) {
    final presentation = ++_presentation;
    _dismissTimer?.cancel();
    setState(() {
      _item = item;
      _visible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || presentation != _presentation) return;
      setState(() => _visible = true);
    });
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted || _item == null) return;
    final presentation = ++_presentation;
    _dismissTimer?.cancel();
    setState(() => _visible = false);
    Timer(const Duration(milliseconds: 280), () {
      if (!mounted || presentation != _presentation) return;
      setState(() => _item = null);
    });
  }

  void _dismissImmediately() {
    _presentation++;
    _dismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _visible = false;
        _item = null;
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Stack(
      children: [
        widget.child,
        if (item != null)
          Positioned(
            top: 0,
            left: AppDimensions.space12,
            right: AppDimensions.space12,
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: _visible ? Offset.zero : const Offset(0, -1.25),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _visible ? 1 : 0,
                  child: Dismissible(
                    key: ValueKey('in_app_notification_${item.id}'),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) => _dismissImmediately(),
                    child: Material(
                      color: AppColors.surfaceElevated,
                      elevation: 12,
                      shadowColor:
                          AppColors.champagneGold.withValues(alpha: 0.28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                        side: const BorderSide(
                          color: AppColors.champagneGold,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          _dismiss();
                          widget.onTap(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: AppColors.goldGlow,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppColors.champagneGold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.space12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyMedium,
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.space4,
                                    ),
                                    Text(
                                      item.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                label: 'Dismiss notification',
                                button: true,
                                child: IconButton(
                                  onPressed: _dismiss,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.slateMist,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
