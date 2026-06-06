// lib/core/widgets/inputs/city_search_field.dart
// ============================================================
// NOOR — City Search Field
//
// Uses Google Places Autocomplete → Place Details.
// Shows: city name, state, country, postal code (pincode).
//
// Degrades gracefully to free-text when no API key is set.
//
// Usage:
//   CitySearchField(
//     countryCode: 'IN',
//     initialValue: data.city,
//     onSelected: (result) {
//       setState(() {
//         city       = result.city;
//         postalCode = result.postalCode;
//         lat        = result.lat;
//         lng        = result.lng;
//       });
//     },
//   )
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/country_context_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';

class CitySearchField extends StatefulWidget {
  const CitySearchField({
    super.key,
    this.countryCode,
    required this.onSelected,
    this.initialValue,
    this.label,
    this.hint,
  });

  final String? countryCode;
  final ValueChanged<CityResult> onSelected;
  final String? initialValue;
  final String? label;
  final String? hint;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();
  final _service = CountryContextService.instance;

  List<CityResult> _results  = [];
  bool _loading = false;
  bool _showDropdown = false;
  Timer? _debounce;
  String? _selectedDisplay;

  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _ctrl.text       = widget.initialValue!;
      _selectedDisplay = widget.initialValue;
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CitySearchField old) {
    super.didUpdateWidget(old);
    // When country changes, clear the selection
    if (old.countryCode != widget.countryCode) {
      _ctrl.clear();
      _selectedDisplay = null;
      _results.clear();
      _hideOverlay();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      if (_ctrl.text.trim().length >= 2 && !_showDropdown) {
        setState(() {
          _showDropdown = true;
          _showOverlay();
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_focus.hasFocus) {
          setState(() {
            _showDropdown = false;
            _hideOverlay();
          });
        }
      });
    }
  }

  void _onChanged(String value) {
    // If value matches selected, don't re-search
    if (value == _selectedDisplay) return;

    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results       = [];
        _showDropdown  = false;
        _hideOverlay();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _showDropdown = true;
        _showOverlay();
      });

      final results = await _service.searchCities(
        value,
        countryCode: widget.countryCode,
      );

      if (!mounted) return;
      setState(() {
        _results  = results;
        _loading  = false;
        if (_showDropdown) {
          _showOverlay();
        }
      });
    });
  }

  void _selectResult(CityResult result) {
    final display = result.city.isNotEmpty
        ? '${result.city}${result.state.isNotEmpty ? ', ${result.state}' : ''}'
        : result.fullAddress;

    setState(() {
      _selectedDisplay = display;
      _showDropdown    = false;
      _results         = [];
      _hideOverlay();
    });
    _ctrl.value = TextEditingValue(
      text:      display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    _focus.unfocus();
    widget.onSelected(result);
  }

  void _showOverlay() {
    if (!mounted) return;
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final width = renderBox?.size.width ?? 300.0;
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 62),
            child: _buildDropdown(),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ──────────────────────────────────────────
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
        ],

        // ── Input field wrapped in composited transform target ──
        CompositedTransformTarget(
          link: _layerLink,
          child: _buildInput(),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        AppColors.inputSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: _focus.hasFocus
              ? AppColors.champagneGold.withValues(alpha: 0.6)
              : AppColors.cardBorder,
          width: _focus.hasFocus ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode:  _focus,
        onChanged:  _onChanged,
        style:      AppTypography.inputText,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint ?? 'Search city or area',
          hintStyle: AppTypography.inputLabel,
          prefixIcon: const Icon(
            Icons.location_on_outlined,
            color: AppColors.slateMist,
            size: 20,
          ),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.champagneGold,
                    ),
                  ),
                )
              : _selectedDisplay != null
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _ctrl.clear();
                        _selectedDisplay = null;
                        _hideOverlay();
                        widget.onSelected(const CityResult(
                          city: '',
                          state: '',
                          country: '',
                          countryCode: '',
                          postalCode: '',
                          fullAddress: '',
                          placeId: '',
                          lat: 0.0,
                          lng: 0.0,
                        ));
                      }),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.slateMist,
                        size: 18,
                      ),
                    )
                  : null,
          border:          InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical:   18,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final queryText = _ctrl.text.trim();
    final showFallback = queryText.isNotEmpty;

    return Material(
      color:       Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      elevation:   0,
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.dropdownSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: _results.isEmpty && !showFallback
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No cities found. Try a different spelling.',
                  style: AppTypography.bodyMuted,
                ),
              )
            : ListView.separated(
                shrinkWrap:       true,
                physics:          const NeverScrollableScrollPhysics(),
                itemCount:        _results.length + (showFallback ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color:  AppColors.cardBorder,
                ),
                itemBuilder: (context, i) {
                  if (i < _results.length) {
                    final r = _results[i];
                    return _CityTile(
                      result: r,
                      onTap:  () => _selectResult(r),
                    );
                  } else {
                    return _CustomCityTile(
                      query: queryText,
                      onTap: () {
                        _selectResult(CityResult(
                          city: queryText,
                          state: '',
                          country: '',
                          countryCode: widget.countryCode ?? '',
                          postalCode: '',
                          fullAddress: queryText,
                          placeId: 'custom-city-${queryText.toLowerCase()}',
                          lat: 0.0,
                          lng: 0.0,
                        ));
                      },
                    );
                  }
                },
              ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(
          begin: -0.04, end: 0,
          duration: 220.ms, curve: Curves.easeOutCubic,
        );
  }
}

class _CustomCityTile extends StatelessWidget {
  const _CustomCityTile({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:       onTap,
      splashColor: AppColors.goldGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        AppColors.champagneGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_location_alt_rounded,
                color: AppColors.champagneGold,
                size:  18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  Text(
                    'Use "$query" as custom city',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.champagneGold,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Specify state/region in the next field',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slateMist,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── City result tile ──────────────────────────────────────────

class _CityTile extends StatelessWidget {
  const _CityTile({required this.result, required this.onTap});

  final CityResult   result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (result.state.isNotEmpty) result.state,
      if (result.postalCode.isNotEmpty) result.postalCode,
    ].join(' · ');

    return InkWell(
      onTap:       onTap,
      splashColor: AppColors.goldGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        AppColors.champagneGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_city_rounded,
                color: AppColors.champagneGold,
                size:  18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  Text(
                    result.city.isNotEmpty ? result.city : result.fullAddress,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                      ),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (result.postalCode.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:        AppColors.champagneGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.champagneGold.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  result.postalCode,
                  style: AppTypography.caption.copyWith(
                    color:       AppColors.champagneGold,
                    fontWeight:  FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
