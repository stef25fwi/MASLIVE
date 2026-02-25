import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/market_circuit_models.dart';

class PoiSelectionController extends ChangeNotifier {
  MarketMapPOI? _selectedPoi;

  MarketMapPOI? get selectedPoi => _selectedPoi;

  bool get hasSelection => _selectedPoi != null;

  void select(MarketMapPOI poi) {
    if (_selectedPoi?.id == poi.id) return;
    _selectedPoi = poi;
    notifyListeners();
  }

  void clear() {
    if (_selectedPoi == null) return;
    _selectedPoi = null;
    notifyListeners();
  }
}

class PoiBottomPopup extends StatefulWidget {
  final MarketMapPOI? selectedPoi;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(MarketMapPOI poi)? categoryLabel;

  const PoiBottomPopup({
    super.key,
    required this.selectedPoi,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    this.categoryLabel,
  });

  @override
  State<PoiBottomPopup> createState() => _PoiBottomPopupState();
}

class _PoiBottomPopupState extends State<PoiBottomPopup> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _wasVisible = false;

  static const _animDuration = Duration(milliseconds: 250);

  @override
  void didUpdateWidget(covariant PoiBottomPopup oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isVisible = widget.selectedPoi != null;
    if (!_wasVisible && isVisible) {
      // Auto-focus sur le popup quand un POI est sélectionné.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final sizes = _computeSizes(context);
        _controller.animateTo(
          sizes.snap,
          duration: _animDuration,
          curve: Curves.easeOut,
        );
      });
    }
    _wasVisible = isVisible;
  }

  ({double min, double snap, double max}) _computeSizes(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final min = (120.0 / height).clamp(0.10, 0.40);
    final snap = (250.0 / height).clamp(min, 0.45);
    final max = 0.45;
    return (min: min, snap: snap, max: max);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.selectedPoi;
    final sizes = _computeSizes(context);

    final visible = poi != null;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: _animDuration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: _animDuration,
          curve: Curves.easeOut,
          child: SafeArea(
            top: false,
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                if (!visible) return false;
                if (n.extent <= sizes.min + 0.0005) {
                  widget.onClose();
                }
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _controller,
                minChildSize: sizes.min,
                maxChildSize: sizes.max,
                initialChildSize: sizes.snap,
                snap: true,
                snapSizes: [sizes.min, sizes.snap, sizes.max],
                shouldCloseOnMinExtent: true,
                builder: (context, scrollController) {
                  if (poi == null) return const SizedBox.shrink();

                  final colorScheme = Theme.of(context).colorScheme;
                  final bg = colorScheme.surface.withValues(alpha: 0.92);

                  final category =
                      (widget.categoryLabel?.call(poi) ?? poi.layerType).trim();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                        bottom: Radius.circular(24),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Material(
                          color: bg,
                          elevation: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                                bottom: Radius.circular(24),
                              ),
                            ),
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                          right: 40,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            poi.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              if (category.isNotEmpty)
                                                _Pill(
                                                  icon: Icons.category_rounded,
                                                  label: category,
                                                ),
                                              _Pill(
                                                icon: Icons.my_location_rounded,
                                                label:
                                                    '${poi.lng.toStringAsFixed(5)}, ${poi.lat.toStringAsFixed(5)}',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fermer',
                                      onPressed: widget.onClose,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: widget.onEdit,
                                        icon: const Icon(Icons.edit_rounded),
                                        label: const Text('Éditer'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: widget.onDelete,
                                        icon: const Icon(Icons.delete_rounded),
                                        label: const Text('Supprimer'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.70),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}
