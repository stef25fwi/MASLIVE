
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../services/circuit_repository.dart';
import '../services/circuit_versioning_service.dart';
import '../services/market_map_service.dart';
import '../services/publish_quality_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../ui/map/maslive_poi_style.dart';
import '../ui/widgets/country_autocomplete_field.dart';
import '../ui/widgets/glass_scrollbar.dart';
import '../ui/snack/top_snack_bar.dart';
import '../models/market_country.dart';
import '../ui_kit/glass/glass_app_bar.dart';
import '../ui_kit/glass/glass_panel.dart';
import '../ui_kit/layout/soft_background.dart';
import '../ui_kit/tokens/maslive_tokens.dart';
import '../ui_kit/wizard/wizard_bottom_bar.dart';
import '../ui_kit/wizard/wizard_stepper_pills.dart';
import 'circuit_map_editor.dart';
import '../route_style_pro/models/route_style_config.dart' as rsp;
import '../route_style_pro/services/route_snap_service.dart' as snap;
import '../route_style_pro/ui/route_style_wizard_pro_page.dart';
import '../pages/home_vertical_nav.dart';
import 'poi_bottom_popup.dart';
import 'poi_edit_popup.dart';

typedef LngLat = ({double lng, double lat});

enum _PoiInlineEditorMode { none, createZone, edit }

class CircuitWizardProPage extends StatefulWidget {
  final String? projectId;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final int? initialStep;
  final bool poiOnly;

  const CircuitWizardProPage({
    super.key,
    this.projectId,
    this.countryId,
    this.eventId,
    this.circuitId,
    this.initialStep,
    this.poiOnly = false,
  });

  @override
  State<CircuitWizardProPage> createState() => _CircuitWizardProPageState();
}

class _CircuitWizardProPageState extends State<CircuitWizardProPage>
    with SingleTickerProviderStateMixin {
  static const int _poiPageSize = 100;
  static const int _poiLimit = 2000;
  static const int _poiStepIndex = 5;
  static const double _wizardMapHeightMultiplier = 2.0;
  static const double _wizardScrollRailWidth = 56.0;
  static const double _wizardStepHorizontalPadding = 4.0;
  static const double _perimeterCameraPitchMaxDegrees = 80.0;

  static const List<String> _stepLabels = <String>[
    'Template',
    'Infos',
    'Périmètre',
    'Tracé + Style',
    'Style Pro',
    'POI',
    'Pré-pub',
    'Publication',
  ];

  bool _isStepEnabled(int index) {
    // UX existante: en mode POI-only, on verrouille sur l'étape POI.
    return widget.poiOnly ? index == _poiStepIndex : true;
  }

  bool _isStepCompleted(int index) {
    // UX existante: en mode POI-only, on n'affiche pas de complétion.
    return widget.poiOnly ? false : index < _currentStep;
  }

  Widget _buildWizardStepper({bool interactive = true}) {
    return WizardStepperPills(
      currentStep: _currentStep,
      labels: _stepLabels,
      padding: EdgeInsets.zero,
      onStepTap: interactive ? (i) => unawaited(_continueToStep(i)) : null,
      isStepEnabled: _isStepEnabled,
      isStepCompleted: _isStepCompleted,
    );
  }

  Widget _wrapWizardStep(Widget child) {
    return Column(
      children: [
        const SizedBox(height: MasliveTokens.m),
        _buildWizardStepper(),
        const SizedBox(height: MasliveTokens.m),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: MasliveTokens.s),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildWizardScrollableHeader({
    Widget? toolbar,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
      _wizardStepHorizontalPadding,
      0,
      _wizardStepHorizontalPadding,
      0,
    ),
  }) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWizardStageBand(toolbar: toolbar),
          const SizedBox(height: MasliveTokens.m),
        ],
      ),
    );
  }

  Widget _buildWizardScrollRail() {
    return ValueListenableBuilder<bool>(
      valueListenable: _wizardScrollCanScroll,
      builder: (context, canScroll, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _wizardScrollProgress,
          builder: (context, progress, __) {
            final theme = Theme.of(context);
            const thumbHeight = 96.0;
            final trackColor = Colors.black.withValues(alpha: 0.10);
            final fillColor = MasliveTokens.primary.withValues(alpha: 0.18);
            final thumbColor = canScroll
                ? MasliveTokens.primary
                : theme.disabledColor.withValues(alpha: 0.35);

            Widget railButton({
              required IconData icon,
              required VoidCallback? onTap,
            }) {
              return SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: onTap,
                  icon: Icon(icon, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.88),
                    foregroundColor: onTap == null
                        ? theme.disabledColor
                        : MasliveTokens.primary,
                    side: BorderSide(
                      color: MasliveTokens.primary.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              child: Column(
                children: [
                  railButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onTap: canScroll ? () => _nudgeActiveStepScroll(-1) : null,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final trackHeight = constraints.maxHeight;
                        final effectiveThumbHeight = math.min(
                          thumbHeight,
                          trackHeight,
                        );
                        final top = trackHeight <= effectiveThumbHeight
                            ? 0.0
                            : (trackHeight - effectiveThumbHeight) * progress;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: !canScroll
                              ? null
                              : (details) {
                                  final fraction =
                                      details.localPosition.dy / trackHeight;
                                  unawaited(
                                    _animateActiveStepToFraction(fraction),
                                  );
                                },
                          onVerticalDragUpdate: !canScroll
                              ? null
                              : (details) {
                                  final fraction =
                                      details.localPosition.dy / trackHeight;
                                  unawaited(
                                    _jumpActiveStepToFraction(fraction),
                                  );
                                },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: MasliveTokens.primary.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: trackColor,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (canScroll)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: trackHeight * progress,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: fillColor,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: top,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: thumbColor,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: thumbColor.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: SizedBox(
                                        height: effectiveThumbHeight,
                                        child: Center(
                                          child: RotatedBox(
                                            quarterTurns: 1,
                                            child: Text(
                                              '${(progress * 100).round()}%',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  railButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: canScroll ? () => _nudgeActiveStepScroll(1) : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  ({String title, String subtitle, IconData icon, Color accent})
  _currentStepMeta() {
    switch (_currentStep) {
      case 0:
        return (
          title: 'Point de départ',
          subtitle:
              'Choisissez un template pour accélérer le démarrage ou partez d’une base libre.',
          icon: Icons.auto_awesome_rounded,
          accent: const Color(0xFF0A84FF),
        );
      case 1:
        return (
          title: 'Informations maîtresses',
          subtitle:
              'Cadrez le circuit avec un nom, un pays, un événement et une description propres.',
          icon: Icons.badge_rounded,
          accent: const Color(0xFF14746F),
        );
      case 2:
        return (
          title: 'Périmètre d’expérience',
          subtitle:
              'Définissez la zone visible et les contraintes caméra qui poseront le cadre du circuit.',
          icon: Icons.crop_free_rounded,
          accent: const Color(0xFF0A84FF),
        );
      case 3:
        return (
          title: 'Trajet principal',
          subtitle:
              'Tracez l’itinéraire, alignez-le sur la route et verrouillez sa lecture directionnelle.',
          icon: Icons.route_rounded,
          accent: const Color(0xFF3B82F6),
        );
      case 4:
        return (
          title: 'Style Pro',
          subtitle:
              'Affinez la carte et le rendu du circuit pour obtenir une signature visuelle cohérente.',
          icon: Icons.palette_outlined,
          accent: const Color(0xFF6D28D9),
        );
      case 5:
        return (
          title: 'POI & zones',
          subtitle:
              'Ajoutez les points d’intérêt et structurez les zones parking ou couches éditoriales.',
          icon: Icons.place_outlined,
          accent: const Color(0xFFB45309),
        );
      case 6:
        return (
          title: 'Contrôle qualité',
          subtitle:
              'Repérez les blocants de publication et corrigez les points qui réduisent la qualité finale.',
          icon: Icons.verified_outlined,
          accent: const Color(0xFFEA580C),
        );
      case 7:
        return (
          title: 'Publication',
          subtitle:
              'Vérifiez l’état final du circuit puis publiez uniquement quand tous les signaux sont au vert.',
          icon: Icons.rocket_launch_outlined,
          accent: const Color(0xFF16A34A),
        );
      default:
        return (
          title: 'Wizard Circuit Pro',
          subtitle: 'Édition avancée du circuit.',
          icon: Icons.auto_awesome,
          accent: MasliveTokens.primary,
        );
    }
  }

  bool _qualityItemOk(String id) {
    return _qualityReport.items
        .where((item) => item.id == id)
        .map((item) => item.ok)
        .fold(false, (value, element) => value || element);
  }

  int get _requiredQualityIssueCount =>
      _qualityReport.items.where((item) => item.required && !item.ok).length;

  int get _optionalQualityIssueCount =>
      _qualityReport.items.where((item) => !item.required && !item.ok).length;

  int _qualityStepForItem(CheckItem item) {
    switch (item.id) {
      case 'perimeterClosed':
      case 'boundsSane':
        return 2;
      case 'routeMinPoints':
      case 'routeDensity':
      case 'styleValid':
        return 3;
      case 'atLeastOnePoi':
      case 'layersExist':
        return 5;
      default:
        return 6;
    }
  }

  Future<void> _goToFirstQualityIssue() async {
    final target = _qualityReport.items
        .where((item) => item.required && !item.ok)
        .map(_qualityStepForItem)
        .cast<int?>()
        .firstWhere((step) => step != null, orElse: () => 6)!;
    await _continueToStep(target);
  }

  Widget _buildStageFact({
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    final tint = accent ?? MasliveTokens.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MasliveTokens.s,
        vertical: MasliveTokens.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MasliveTokens.rS),
        border: Border.all(color: tint.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.textSoft,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStageFacts() {
    final report = _qualityReport;
    switch (_currentStep) {
      case 0:
        return [
          _buildStageFact(
            label: 'Mode',
            value: _selectedTemplate == null
                ? 'Création libre'
                : 'Template actif',
            icon: Icons.dashboard_customize_outlined,
            accent: const Color(0xFF0A84FF),
          ),
          _buildStageFact(
            label: 'Sélection',
            value: _selectedTemplate?.name ?? 'Aucun modèle',
            icon: Icons.layers_outlined,
            accent: const Color(0xFF0A84FF),
          ),
        ];
      case 1:
        return [
          _buildStageFact(
            label: 'Nom',
            value: _nameController.text.trim().isEmpty
                ? 'À renseigner'
                : _nameController.text.trim(),
            icon: Icons.edit_note_rounded,
            accent: const Color(0xFF14746F),
          ),
          _buildStageFact(
            label: 'Pays',
            value: _countryController.text.trim().isEmpty
                ? 'Non défini'
                : _countryController.text.trim(),
            icon: Icons.flag_outlined,
            accent: const Color(0xFF14746F),
          ),
          if (_eventController.text.trim().isNotEmpty)
            _buildStageFact(
              label: 'Événement',
              value: _eventController.text.trim(),
              icon: Icons.event_outlined,
              accent: const Color(0xFF14746F),
            ),
        ];
      case 2:
        return [
          _buildStageFact(
            label: 'Sommets',
            value: '${_perimeterPoints.length}',
            icon: Icons.scatter_plot_outlined,
            accent: const Color(0xFF0A84FF),
          ),
          _buildStageFact(
            label: 'Mode',
            value: _perimeterCircleMode ? 'Cercle' : 'Polygone',
            icon: Icons.crop_square_rounded,
            accent: const Color(0xFF0A84FF),
          ),
          _buildStageFact(
            label: 'Statut',
            value: _qualityItemOk('perimeterClosed') ? 'Fermé' : 'À fermer',
            icon: _qualityItemOk('perimeterClosed')
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            accent: _qualityItemOk('perimeterClosed')
                ? MasliveTokens.success
                : const Color(0xFFEA580C),
          ),
        ];
      case 3:
        return [
          _buildStageFact(
            label: 'Points',
            value: '${_routePoints.length}',
            icon: Icons.timeline_rounded,
            accent: const Color(0xFF3B82F6),
          ),
          _buildStageFact(
            label: 'Distance',
            value: '${_routeEditorController.distanceKm.toStringAsFixed(2)} km',
            icon: Icons.straighten_rounded,
            accent: const Color(0xFF3B82F6),
          ),
          _buildStageFact(
            label: 'Style',
            value: '${_routeWidth.toStringAsFixed(0)} px',
            icon: Icons.brush_outlined,
            accent: const Color(0xFF3B82F6),
          ),
        ];
      case 4:
        return [
          _buildStageFact(
            label: 'Style URL',
            value:
                _normalizeMapboxStyleUrl(
                  _styleUrlController.text,
                ).trim().isEmpty
                ? 'Preset local'
                : 'Mapbox actif',
            icon: Icons.map_outlined,
            accent: const Color(0xFF6D28D9),
          ),
          _buildStageFact(
            label: 'Route Style Pro',
            value: _routeStyleProConfig == null ? 'À charger' : 'Synchronisé',
            icon: Icons.auto_graph_outlined,
            accent: const Color(0xFF6D28D9),
          ),
        ];
      case 5:
        return [
          _buildStageFact(
            label: 'POI',
            value: '${_pois.length}/$_poiLimit',
            icon: Icons.place_outlined,
            accent: const Color(0xFFB45309),
          ),
          _buildStageFact(
            label: 'Couche',
            value: _selectedLayer?.label ?? 'Aucune',
            icon: Icons.layers_outlined,
            accent: const Color(0xFFB45309),
          ),
          _buildStageFact(
            label: 'Parking',
            value: (_isDrawingParkingZone || _isEditingParkingZonePerimeter)
                ? 'Édition en cours'
                : 'Stable',
            icon: Icons.local_parking_outlined,
            accent: const Color(0xFFB45309),
          ),
        ];
      case 6:
        return [
          _buildStageFact(
            label: 'Score',
            value: '${report.score}/100',
            icon: Icons.insights_outlined,
            accent: report.canPublish
                ? MasliveTokens.success
                : const Color(0xFFEA580C),
          ),
          _buildStageFact(
            label: 'Blocants',
            value: '$_requiredQualityIssueCount',
            icon: Icons.error_outline,
            accent: _requiredQualityIssueCount == 0
                ? MasliveTokens.success
                : const Color(0xFFDC2626),
          ),
          _buildStageFact(
            label: 'Améliorations',
            value: '$_optionalQualityIssueCount',
            icon: Icons.tune_rounded,
            accent: const Color(0xFFEA580C),
          ),
        ];
      case 7:
        return [
          _buildStageFact(
            label: 'Publication',
            value: report.canPublish ? 'Prête' : 'Bloquée',
            icon: report.canPublish
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
            accent: report.canPublish
                ? MasliveTokens.success
                : const Color(0xFFEA580C),
          ),
          _buildStageFact(
            label: 'POI chargés',
            value: _hasMorePois || _isLoadingMorePois ? 'Partiels' : 'Complets',
            icon: Icons.inventory_2_outlined,
            accent: _hasMorePois || _isLoadingMorePois
                ? const Color(0xFFEA580C)
                : MasliveTokens.success,
          ),
          _buildStageFact(
            label: 'Score',
            value: '${report.score}/100',
            icon: Icons.verified_outlined,
            accent: report.canPublish
                ? MasliveTokens.success
                : const Color(0xFFEA580C),
          ),
        ];
      default:
        return const <Widget>[];
    }
  }

  List<Widget> _buildStageActions(bool compact) {
    final report = _qualityReport;
    final actions = <Widget>[];

    Widget wrapAction(Widget child) {
      if (!compact) return child;
      return SizedBox(width: double.infinity, child: child);
    }

    switch (_currentStep) {
      case 0:
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: _selectedTemplate == null
                  ? null
                  : () => _applyTemplate(_selectedTemplate!),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Appliquer le modèle'),
            ),
          ),
        );
        actions.add(
          wrapAction(
            OutlinedButton.icon(
              onPressed: _showDraftHistory,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Historique'),
            ),
          ),
        );
        break;
      case 1:
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () => unawaited(_continueToStep(2)),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Passer au périmètre'),
            ),
          ),
        );
        break;
      case 2:
        actions.add(
          wrapAction(
            OutlinedButton.icon(
              onPressed: (!_perimeterCircleMode && _perimeterPoints.length >= 2)
                  ? _perimeterEditorController.closePath
                  : null,
              icon: const Icon(Icons.loop_rounded, size: 18),
              label: const Text('Fermer le périmètre'),
            ),
          ),
        );
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: _qualityItemOk('perimeterClosed')
                  ? () => unawaited(_continueToStep(3))
                  : null,
              icon: const Icon(Icons.route_rounded, size: 18),
              label: const Text('Passer au tracé'),
            ),
          ),
        );
        break;
      case 3:
        actions.add(
          wrapAction(
            OutlinedButton.icon(
              onPressed: (!_isSnappingRoute && _routePoints.length >= 2)
                  ? _snapRouteToRoads
                  : null,
              icon: const Icon(Icons.alt_route_rounded, size: 18),
              label: const Text('Snap sur route'),
            ),
          ),
        );
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: _qualityItemOk('routeMinPoints')
                  ? () => unawaited(_continueToStep(4))
                  : null,
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('Passer au style pro'),
            ),
          ),
        );
        break;
      case 4:
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_continueToStep(5)),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('Passer aux POI'),
            ),
          ),
        );
        break;
      case 5:
        actions.add(
          wrapAction(
            OutlinedButton.icon(
              onPressed:
                  (_selectedLayer == null ||
                      _pois.length >= _poiLimit ||
                      _isDrawingParkingZone ||
                      _isEditingParkingZonePerimeter)
                  ? null
                  : _addPoiAtCurrentCenter,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Ajouter un POI ici'),
            ),
          ),
        );
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_continueToStep(6)),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Lancer la pré-pub'),
            ),
          ),
        );
        break;
      case 6:
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: _requiredQualityIssueCount > 0
                  ? () => unawaited(_goToFirstQualityIssue())
                  : () => unawaited(_continueToStep(7)),
              icon: Icon(
                _requiredQualityIssueCount > 0
                    ? Icons.build_circle_outlined
                    : Icons.rocket_launch_outlined,
                size: 18,
              ),
              label: Text(
                _requiredQualityIssueCount > 0
                    ? 'Corriger le premier blocant'
                    : 'Passer à la publication',
              ),
            ),
          ),
        );
        break;
      case 7:
        actions.add(
          wrapAction(
            FilledButton.tonalIcon(
              onPressed: (report.canPublish && !_isEnsuringAllPoisLoaded)
                  ? _publishCircuit
                  : null,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Publier maintenant'),
            ),
          ),
        );
        if (_hasMorePois || _isLoadingMorePois) {
          actions.add(
            wrapAction(
              OutlinedButton.icon(
                onPressed: _isEnsuringAllPoisLoaded
                    ? null
                    : _ensureAllPoisLoadedForPublish,
                icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                label: const Text('Charger tous les POI'),
              ),
            ),
          );
        }
        break;
    }
    return actions;
  }

  Widget _buildWizardStageBand({Widget? toolbar}) {
    final meta = _currentStepMeta();
    final compact = MediaQuery.sizeOf(context).width < 920;
    final actions = _buildStageActions(compact);
    final facts = _buildStageFacts();
    final report = _qualityReport;

    final summaryCard = Container(
      padding: const EdgeInsets.all(MasliveTokens.s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(MasliveTokens.rM),
        border: Border.all(color: MasliveTokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilotage',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: MasliveTokens.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: facts),
          if (_currentStep >= 6) ...[
            const SizedBox(height: 10),
            Text(
              report.canPublish
                  ? 'Tous les critères requis sont validés.'
                  : '$_requiredQualityIssueCount blocant(s) requis avant publication.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: report.canPublish
                    ? MasliveTokens.success
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );

    return Column(
      children: [
        GlassPanel(
          radius: MasliveTokens.rL,
          opacity: 0.9,
          padding: const EdgeInsets.all(MasliveTokens.m),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: meta.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              MasliveTokens.rM,
                            ),
                          ),
                          child: Icon(meta.icon, color: meta.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Étape ${_currentStep + 1}/${_stepLabels.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: meta.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                meta.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: MasliveTokens.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                meta.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MasliveTokens.textSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    summaryCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: meta.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    MasliveTokens.rM,
                                  ),
                                ),
                                child: Icon(
                                  meta.icon,
                                  color: meta.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Étape ${_currentStep + 1}/${_stepLabels.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: meta.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    meta.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: MasliveTokens.text,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            meta.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MasliveTokens.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 420, child: summaryCard),
                  ],
                ),
        ),
        if (toolbar != null) ...[
          const SizedBox(height: MasliveTokens.s),
          toolbar,
        ],
      ],
    );
  }

  double _responsiveWizardMapHeight(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final shortestSide = math.min(viewport.width, viewport.height);

    if (shortestSide < 600) {
      return (viewport.height * 0.42).clamp(320.0, 520.0);
    }
    if (shortestSide < 960) {
      return (viewport.height * 0.48).clamp(420.0, 640.0);
    }
    return 720.0;
  }

  double _expandedWizardMapHeight(BuildContext context) {
    return (_responsiveWizardMapHeight(context) * _wizardMapHeightMultiplier)
        .clamp(640.0, 1440.0);
  }

  double _expandedWizardRouteMapHeight(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final base =
        _responsiveWizardMapHeight(context) +
        (viewport.width < 920 ? 72.0 : 56.0);
    return (base * _wizardMapHeightMultiplier).clamp(760.0, 1560.0);
  }

  double _expandedWizardPoiMapHeight(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final base = (viewportHeight - 168).clamp(520.0, 760.0);
    return (base * _wizardMapHeightMultiplier).clamp(1040.0, 1520.0);
  }

  double _embeddedStyleProPreviewHeight(BuildContext context) {
    return (320.0 * _wizardMapHeightMultiplier).clamp(640.0, 960.0);
  }

  double _responsiveWizardPointsListMaxHeight(BuildContext context) {
    final shortestSide = math.min(
      MediaQuery.sizeOf(context).width,
      MediaQuery.sizeOf(context).height,
    );
    return shortestSide < 600 ? 96.0 : 120.0;
  }

  final CircuitRepository _repository = CircuitRepository();
  final CircuitVersioningService _versioning = CircuitVersioningService();
  final PublishQualityService _qualityService = PublishQualityService();
  final MarketMapService _marketMapService = MarketMapService();

  String? _projectId;
  late PageController _pageController;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserRole;
  String? _currentGroupId;

  bool _canWriteMapProjects = false;

  List<CircuitTemplate> _templates = [];
  CircuitTemplate? _selectedTemplate;

  final _perimeterEditorController = CircuitMapEditorController();
  final _routeEditorController = CircuitMapEditorController();

  // Formulaire Step 1: Infos
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _styleUrlController = TextEditingController();

  Timer? _styleUrlDebounce;

  // Données Steps 2-4: Cartes
  List<LngLat> _perimeterPoints = [];
  List<LngLat> _routePoints = [];

  // Step 2: Option périmètre cercle (centre + diamètre)
  bool _perimeterCircleMode = false;
  LngLat? _perimeterCircleCenter;
  bool _perimeterCircleCenterLocked = false;
  double _perimeterCircleDiameterMeters = 1200.0;

  // Step 2 (périmètre): contraintes caméra
  double _perimeterCameraInitialZoom = 15.0;
  double _perimeterCameraPitchZoomThreshold = 16.0;
  double _perimeterCameraPitchDegrees = 45.0;
  double _perimeterCameraMaxZoom = 18.0;

  // Style du tracé (Step 3 + Step 4)
  String _routeColorHex = '#1A73E8';
  double _routeWidth = 6.0;
  bool _routeRoadLike = true;
  bool _routeShadow3d = true;
  bool _routeShowDirection = true;
  bool _routeAnimateDirection = false;
  double _routeAnimationSpeed = 1.0;
  bool _perimeterCameraAdvancedExpanded = false;
  bool _routeStyleAdvancedExpanded = false;

  // Style Pro (RouteStyleConfig) chargé depuis Firestore (map_projects.routeStylePro)
  rsp.RouteStyleConfig? _routeStyleProConfig;

  // Animation (rainbow) sur la carte POI
  Timer? _poiRouteStyleProTimer;
  int _poiRouteStyleProAnimTick = 0;
  bool _isRenderingPoiRoute = false;
  String? _lastPoiBuildingsKey;
  final RouteStyleWizardProController _routeStyleProController =
      RouteStyleWizardProController();

  // Step 4: Layers/POI
  List<MarketMapLayer> _layers = [];
  List<MarketMapPOI> _pois = [];
  DocumentSnapshot<Map<String, dynamic>>? _poisLastDoc;
  bool _hasMorePois = false;
  bool _isLoadingMorePois = false;
  MarketMapLayer? _selectedLayer;
  final MasLiveMapControllerPoi _poiMapController = MasLiveMapControllerPoi();
  final PoiSelectionController _poiSelection = PoiSelectionController();
  final ScrollController _poiStepScrollController = ScrollController();
  final ScrollController _templateStepScrollController = ScrollController();
  final ScrollController _infosStepScrollController = ScrollController();
  final ScrollController _perimeterStepScrollController = ScrollController();
  final ScrollController _routeStepScrollController = ScrollController();
  final ScrollController _styleProStepScrollController = ScrollController();
  final ScrollController _validationStepScrollController = ScrollController();
  final ScrollController _publishStepScrollController = ScrollController();
  final ValueNotifier<double> _wizardScrollProgress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _wizardScrollCanScroll = ValueNotifier<bool>(false);

  String _defaultPoiAppearanceId = kMasLivePoiAppearancePresets.first.id;
  String _poiInlineAppearanceId = kMasLivePoiAppearancePresets.first.id;

  // Empêche le scroll vertical de certaines pages quand l'utilisateur interagit
  // avec une carte intégrée dans un scroll (drag/pan/zoom).
  int _wizardMapPointerCount = 0;
  bool get _isWizardMapInteracting => _wizardMapPointerCount > 0;

  Widget _wrapWizardMapToBlockScroll(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!mounted) return;
        setState(() => _wizardMapPointerCount++);
      },
      onPointerUp: (_) {
        if (!mounted) return;
        setState(() {
          _wizardMapPointerCount = math.max(0, _wizardMapPointerCount - 1);
        });
      },
      onPointerCancel: (_) {
        if (!mounted) return;
        setState(() {
          _wizardMapPointerCount = math.max(0, _wizardMapPointerCount - 1);
        });
      },
      child: child,
    );
  }

  _PoiInlineEditorMode _poiInlineEditorMode = _PoiInlineEditorMode.none;
  MarketMapPOI? _poiEditingPoi;

  final TextEditingController _poiInlineNameController =
      TextEditingController();
  final TextEditingController _poiInlineLatController = TextEditingController();
  final TextEditingController _poiInlineLngController = TextEditingController();
  String? _poiInlineError;

  // Parking: création de zone (polygone)
  bool _isDrawingParkingZone = false;
  bool _isEditingParkingZonePerimeter = false;
  List<LngLat> _parkingZonePoints = <LngLat>[];

  // Parking: style de zone (fond/couleur/texture)
  static const String _parkingZoneStyleKey = 'perimeterStyle';
  static const String _parkingZoneVehiclesKey = 'vehicleTypes';
  static const String _parkingZoneLabelPresetKey = 'labelPreset';
  static const String _parkingZoneLabelPresetDefault = 'default';
  static const String _parkingZoneLabelPresetWideBlue =
      'wide_blue_badge_white_outline';
  static const String _parkingZoneDefaultFillHex = '#0A84FF';
  static const String _parkingZoneDefaultStrokeHex = '#FFFFFF';
  static const double _parkingZoneDefaultFillOpacity = 0.88;
  static const double _parkingZoneDefaultStrokeWidth = 4.0;
  static const double _parkingZoneDefaultPatternOpacity = 0.55;
  static const double _parkingZoneDefaultColorSaturation = 1.0;
  Set<String> _parkingZoneVehicleTypes = <String>{'car', 'moto'};
  String _parkingZoneFillColorHex = _parkingZoneDefaultFillHex;
  String _parkingZoneStrokeColorHex = _parkingZoneDefaultStrokeHex;
  bool _parkingZoneStrokeFollowsFill = false;
  double _parkingZoneColorSaturation = _parkingZoneDefaultColorSaturation;
  double _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
  double _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
  String _parkingZoneLabelPreset = _parkingZoneLabelPresetWideBlue;
  String _parkingZoneStrokeDash = 'solid'; // solid|dashed|dotted
  String _parkingZonePattern = 'none'; // none|diag|cross|dots
  double _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
  final TextEditingController _parkingZoneColorController =
      TextEditingController(text: _parkingZoneDefaultFillHex);
  final TextEditingController _parkingZoneStrokeColorController =
      TextEditingController(text: _parkingZoneDefaultStrokeHex);

  void _applyParkingZonePresetWhiteBlue() {
    setState(() {
      _parkingZoneFillColorHex = _parkingZoneDefaultFillHex;
      _parkingZoneStrokeColorHex = _parkingZoneDefaultStrokeHex;
      _parkingZoneStrokeFollowsFill = false;
      _parkingZoneColorSaturation = _parkingZoneDefaultColorSaturation;
      _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneLabelPreset = _parkingZoneLabelPresetWideBlue;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = _parkingZoneDefaultFillHex;
      _parkingZoneStrokeColorController.text = _parkingZoneDefaultStrokeHex;
      _poiInlineError = null;
    });
    _refreshPoiMarkers();
  }

  Set<String> _normalizeParkingVehicleTypes(Iterable<String> raw) {
    final normalized = raw
        .map((e) => e.trim().toLowerCase())
        .where((e) => e == 'car' || e == 'moto')
        .toSet();
    return normalized.isEmpty ? <String>{'car', 'moto'} : normalized;
  }

  Set<String> _parkingZoneVehicleTypesFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    final raw = meta?[_parkingZoneVehiclesKey];
    if (raw is Iterable) {
      return _normalizeParkingVehicleTypes(raw.whereType<String>());
    }
    return <String>{'car', 'moto'};
  }

  String _parkingZoneLabelText(Set<String> vehicleTypes) {
    return 'PARKING';
  }

  String _parkingZoneLabelPresetFromStyle(Map<String, dynamic>? style) {
    final raw = style?[_parkingZoneLabelPresetKey] as String?;
    if (raw == _parkingZoneLabelPresetWideBlue) {
      return _parkingZoneLabelPresetWideBlue;
    }
    return _parkingZoneLabelPresetDefault;
  }

  double _parkingZoneDistanceMeters(LngLat a, LngLat b) {
    const earthRadius = 6371000.0;
    final lat1 = a.lat * math.pi / 180.0;
    final lat2 = b.lat * math.pi / 180.0;
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLng = (b.lng - a.lng) * math.pi / 180.0;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  double _parkingZoneMaxSpanMeters(List<LngLat> perimeter) {
    if (perimeter.length < 2) return 0.0;
    var west = perimeter.first.lng;
    var east = perimeter.first.lng;
    var south = perimeter.first.lat;
    var north = perimeter.first.lat;
    for (final point in perimeter.skip(1)) {
      west = math.min(west, point.lng);
      east = math.max(east, point.lng);
      south = math.min(south, point.lat);
      north = math.max(north, point.lat);
    }
    final centerLat = (south + north) / 2;
    final centerLng = (west + east) / 2;
    final width = _parkingZoneDistanceMeters(
      (lng: west, lat: centerLat),
      (lng: east, lat: centerLat),
    );
    final height = _parkingZoneDistanceMeters(
      (lng: centerLng, lat: south),
      (lng: centerLng, lat: north),
    );
    return math.max(width, height);
  }

  String? _parkingZoneBadgeIdForPerimeter(
    List<LngLat> perimeter,
    String labelPreset,
  ) {
    if (labelPreset != _parkingZoneLabelPresetWideBlue) return null;
    final span = _parkingZoneMaxSpanMeters(perimeter);
    if (span >= 120) return 'maslive_parking_badge_lg';
    if (span >= 60) return 'maslive_parking_badge_md';
    return 'maslive_parking_badge_sm';
  }

  double _parkingZoneLabelTextSizeForPerimeter(
    List<LngLat> perimeter,
    String labelPreset,
  ) {
    if (labelPreset != _parkingZoneLabelPresetWideBlue) return 16.0;
    final span = _parkingZoneMaxSpanMeters(perimeter);
    if (span >= 120) return 17.0;
    if (span >= 60) return 15.0;
    return 13.0;
  }

  double _parkingZoneIconScaleForPerimeter(
    List<LngLat> perimeter,
    String labelPreset,
  ) {
    if (labelPreset != _parkingZoneLabelPresetWideBlue) return 1.0;
    final span = _parkingZoneMaxSpanMeters(perimeter);
    if (span >= 120) return 1.0;
    if (span >= 60) return 0.92;
    return 0.84;
  }

  String _parkingZoneSymbolImageId(Set<String> vehicleTypes) {
    final normalized = _normalizeParkingVehicleTypes(vehicleTypes);
    if (normalized.length == 2) return 'maslive_parking_both';
    if (normalized.contains('moto')) return 'maslive_parking_moto';
    return 'maslive_parking_car';
  }

  void _toggleParkingZoneVehicleType(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized != 'car' && normalized != 'moto') return;
    setState(() {
      final next = <String>{..._parkingZoneVehicleTypes};
      if (next.contains(normalized)) {
        if (next.length == 1) return;
        next.remove(normalized);
      } else {
        next.add(normalized);
      }
      _parkingZoneVehicleTypes = _normalizeParkingVehicleTypes(next);
      _poiInlineError = null;
    });
    _refreshPoiMarkers();
  }

  double? _poiInitialLng;
  double? _poiInitialLat;
  double? _poiInitialZoom;

  bool _isSnappingRoute = false;

  bool _isRefreshingMarketImport = false;
  bool _isEnsuringAllPoisLoaded = false;

  // Snap en continu (debounce + ignore résultats obsolètes)
  Timer? _routeSnapDebounce;
  int _routeSnapSeq = 0;

  // Brouillon
  Map<String, dynamic> _draftData = {};

  void _showTopSnackBar(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    TopSnackBar.showMessage(
      context,
      message,
      isError: isError,
      duration: duration,
    );
  }

  Future<void> _ensureAllPoisLoadedForPublish() async {
    if (_isEnsuringAllPoisLoaded) return;
    if (_projectId == null) return;
    if (!_hasMorePois) return;

    setState(() => _isEnsuringAllPoisLoaded = true);
    try {
      // Sécurité: évite une boucle infinie si l'état Firestore est instable.
      int pageGuard = 0;
      while (mounted && _hasMorePois) {
        pageGuard += 1;
        if (pageGuard > 60) {
          throw StateError('Trop de pages POI à charger (guard).');
        }
        await _loadMorePoisPage();
      }
    } finally {
      if (mounted) {
        setState(() => _isEnsuringAllPoisLoaded = false);
      } else {
        _isEnsuringAllPoisLoaded = false;
      }
    }
  }

  Future<void> _refreshImportFromMarketMap() async {
    if (_isRefreshingMarketImport) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar('⛔ Import réservé aux admins master.', isError: true);
        return;
      }

      // Assure un projectId existant (on importe dans un brouillon).
      if (_projectId == null) {
        await _saveDraft();
      }

      final projectId = _projectId;
      if (projectId == null || projectId.trim().isEmpty) {
        throw StateError('Projet non initialisé');
      }

      final countryId = _countryController.text.trim();
      final eventId = _eventController.text.trim();
      final circuitId = (widget.circuitId?.trim().isNotEmpty ?? false)
          ? widget.circuitId!.trim()
          : (_draftData['circuitId']?.toString().trim() ?? '');

      if (countryId.isEmpty || eventId.isEmpty || circuitId.isEmpty) {
        throw StateError('Pays / événement / circuit requis pour importer.');
      }

      if (!mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Réimporter depuis MarketMap ?'),
            content: const Text(
              'Cette action remplace les couches et POI du brouillon par la version publiée (MarketMap).\n'
              'Les modifications locales non publiées sur les POI/couches seront perdues.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Importer'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (ok != true) return;

      setState(() => _isRefreshingMarketImport = true);
      await _repository.refreshDraftFromMarketMap(
        projectId: projectId,
        actorUid: user.uid,
        actorRole: _currentUserRole ?? 'creator',
        groupId: _currentGroupId ?? 'default',
        countryId: countryId,
        eventId: eventId,
        circuitId: circuitId,
      );

      // Recharge l'état (doc courant + sous-collections layers/pois).
      await _loadDraftOrInitialize();

      if (mounted) {
        _showTopSnackBar('✅ Import MarketMap terminé');
      }
    } catch (e) {
      debugPrint('WizardPro _refreshImportFromMarketMap error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Import Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur import: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingMarketImport = false);
      } else {
        _isRefreshingMarketImport = false;
      }
    }
  }

  PublishQualityReport get _qualityReport => _qualityService.evaluate(
    perimeter: _perimeterPoints,
    route: _routePoints,
    routeColorHex: _routeColorHex,
    routeWidth: _routeWidth,
    layers: _layers,
    pois: _pois,
  );

  String _formatMeters(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  List<LngLat> _circlePerimeter({
    required LngLat center,
    required double diameterMeters,
    int steps = 36,
  }) {
    final radiusMeters = (diameterMeters / 2).clamp(50.0, 50000.0);
    final lat1 = _toRad(center.lat);
    final lng1 = _toRad(center.lng);
    const earthRadius = 6371000.0;
    final d = radiusMeters / earthRadius;

    double wrapLngDeg(double lngDeg) {
      var x = lngDeg;
      while (x > 180) {
        x -= 360;
      }
      while (x < -180) {
        x += 360;
      }
      return x;
    }

    final pts = <LngLat>[];
    for (var i = 0; i < steps; i++) {
      final bearing = 2 * 3.141592653589793 * (i / steps);
      final lat2 = math.asin(
        math.sin(lat1) * math.cos(d) +
            math.cos(lat1) * math.sin(d) * math.cos(bearing),
      );
      final lng2 =
          lng1 +
          math.atan2(
            math.sin(bearing) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2),
          );

      pts.add((lng: wrapLngDeg(_toDeg(lng2)), lat: _toDeg(lat2)));
    }

    if (pts.isNotEmpty) pts.add(pts.first);
    return pts;
  }

  double _toRad(double deg) => deg * (3.141592653589793 / 180.0);
  double _toDeg(double rad) => rad * (180.0 / 3.141592653589793);

  void _applyPerimeterCircle({LngLat? center, double? diameterMeters}) {
    final nextCenter = center ?? _perimeterCircleCenter;
    if (nextCenter == null) return;

    final nextDiameter = (diameterMeters ?? _perimeterCircleDiameterMeters)
        .clamp(200.0, 20000.0);

    setState(() {
      _perimeterCircleMode = true;
      _perimeterCircleCenter = nextCenter;
      _perimeterCircleDiameterMeters = nextDiameter;
      _perimeterPoints = _circlePerimeter(
        center: nextCenter,
        diameterMeters: nextDiameter,
      );
    });
  }

  Future<void> _reloadRouteAndStyleFromFirestore(String projectId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .get();

      if (!doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};

      void applyRouteStyle(Map<String, dynamic> m) {
        final color = (m['color'] as String?)?.trim();
        if (color != null && color.isNotEmpty) {
          _routeColorHex = color;
        }
        final w = m['width'];
        if (w is num) _routeWidth = w.toDouble();
        final rl = m['roadLike'];
        if (rl is bool) _routeRoadLike = rl;
        final sh = m['shadow3d'];
        if (sh is bool) _routeShadow3d = sh;
        final sd = m['showDirection'];
        if (sd is bool) _routeShowDirection = sd;
        final ad = m['animateDirection'];
        if (ad is bool) _routeAnimateDirection = ad;
        final sp = m['animationSpeed'];
        if (sp is num) _routeAnimationSpeed = sp.toDouble();
      }

      final routeStyle = data['routeStyle'];
      if (routeStyle is Map) {
        applyRouteStyle(Map<String, dynamic>.from(routeStyle));
      }

      // Charger la config Style Pro (si elle existe)
      final routeStylePro = data['routeStylePro'];
      if (routeStylePro is Map) {
        try {
          _routeStyleProConfig = rsp.RouteStyleConfig.fromJson(
            Map<String, dynamic>.from(routeStylePro),
          ).validated();
        } catch (_) {
          _routeStyleProConfig = null;
        }
      } else {
        _routeStyleProConfig = null;
      }

      final routeData = data['route'] as List<dynamic>?;
      if (routeData != null) {
        double asDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
        _routePoints = routeData.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return (lng: asDouble(m['lng']), lat: asDouble(m['lat']));
        }).toList();
      }

      _draftData = data;

      if (mounted) {
        setState(() {});
      }

      // Applique le rendu sur la carte POI si besoin.
      unawaited(_refreshPoiRouteOverlay());
      _syncPoiRouteStyleProTimer();
    } catch (e) {
      debugPrint('WizardPro _reloadRouteAndStyleFromFirestore error: $e');
      if (mounted) {
        _showTopSnackBar(
          '❌ Erreur recharge style: $e',
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _currentStep = widget.poiOnly
        ? _poiStepIndex
        : (widget.initialStep ?? 0).clamp(0, 7);
    _pageController = PageController(initialPage: _currentStep);

    for (final controller in _wizardStepScrollControllers) {
      controller.addListener(_syncWizardScrollRailState);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWizardScrollRailState();
    });

    // Step POI: hit-testing GeoJSON (tap POI => édition, tap carte => ajout)
    _poiMapController.onPoiTap = (poiId) {
      final idx = _pois.indexWhere((p) => p.id == poiId);
      if (idx < 0) return;
      _poiSelection.select(_pois[idx]);
    };
    _poiMapController.onMapTap = (lat, lng) {
      // Note: signature controller = (lat, lng), handler = (lng, lat)
      if (_isDrawingParkingZone || _isEditingParkingZonePerimeter) {
        unawaited(_onMapTapForPoi(lng, lat));
        return;
      }
      if (_poiSelection.hasSelection) {
        _poiSelection.clear();
        return;
      }
      unawaited(_onMapTapForPoi(lng, lat));
    };

    _poiSelection.addListener(_onPoiSelectionChanged);

    _loadDraftOrInitialize();
  }

  void _onPoiSelectionChanged() {
    if (!_poiSelection.hasSelection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_poiStepScrollController.hasClients) return;
      _poiStepScrollController.animateTo(
        _poiStepScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _ensureActorContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? const <String, dynamic>{};

    final role = ((data['role'] as String?) ?? 'creator').trim();
    final groupId = ((data['groupId'] as String?) ?? 'default').trim();
    final isAdmin = (data['isAdmin'] as bool?) ?? false;
    final canWrite =
        isAdmin ||
        role == 'admin_master' ||
        role == 'superAdmin' ||
        role == 'super-admin' ||
        role == 'superadmin';

    _currentUserRole = role;
    _currentGroupId = groupId;
    _canWriteMapProjects = canWrite;
  }

  Map<String, dynamic> _buildCurrentData() {
    final proCfg = _routeStyleProConfig?.validated();

    final routeStyle = <String, dynamic>{
      'roadLike': _routeRoadLike,
      'shadow3d': _routeShadow3d,
      'showDirection': _routeShowDirection,
      'animateDirection': _routeAnimateDirection,
      'animationSpeed': _routeAnimationSpeed,
    };

    // Si un Style Pro existe, il devient la source de vérité du design publié.
    // On publie:
    // - `routeStylePro` complet (future-proof)
    // - une projection `routeStyle` compatible avec les consommateurs legacy
    //   (ex: Home/Default map qui lit `style.color/width/...`).
    if (proCfg != null) {
      routeStyle['color'] = _toHexRgb(proCfg.mainColor);
      routeStyle['width'] = proCfg.effectiveRenderedMainWidth;
      routeStyle['shadow3d'] = proCfg.effectiveShadowEnabled;
      routeStyle['animateDirection'] = proCfg.pulseEnabled;
      routeStyle['animationSpeed'] = (proCfg.pulseSpeed / 25.0).clamp(0.5, 5.0);
    }

    return {
      'circuitId': (widget.circuitId ?? _projectId ?? '').trim(),
      'name': _nameController.text.trim(),
      'countryId': _countryController.text.trim(),
      'eventId': _eventController.text.trim(),
      'description': _descriptionController.text.trim(),
      'styleUrl': _styleUrlController.text.trim(),
      'perimeter': _perimeterPoints
          .map((p) => {'lng': p.lng, 'lat': p.lat})
          .toList(),
      'perimeterCircle': {
        'enabled': _perimeterCircleMode,
        'center': _perimeterCircleCenter == null
            ? null
            : {
                'lng': _perimeterCircleCenter!.lng,
                'lat': _perimeterCircleCenter!.lat,
              },
        'centerLocked': _perimeterCircleCenterLocked,
        'diameterMeters': _perimeterCircleDiameterMeters,
      },
      'perimeterMapCamera': {
        'initialZoom': _perimeterCameraInitialZoom,
        'pitchZoomThreshold': _perimeterCameraPitchZoomThreshold,
        'pitchDegrees': _perimeterCameraPitchDegrees,
        'maxZoom': _perimeterCameraMaxZoom,
      },
      'route': _routePoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'routeStyle': routeStyle,
      if (proCfg != null) 'routeStylePro': proCfg.toJson(),
    };
  }

  Future<void> _loadTemplates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _templates = await _repository.listTemplates(actorUid: user.uid);
  }

  Future<void> _applyTemplate(CircuitTemplate template) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ensureActorContext();
    if (!_canWriteMapProjects) {
      if (!mounted) return;
      _showTopSnackBar(
        '⛔ Accès en écriture réservé aux admins master.',
        isError: true,
      );
      return;
    }
    final result = await _repository.createProjectFromTemplate(
      template: template,
      groupId: _currentGroupId ?? 'default',
      actorUid: user.uid,
      projectId: _projectId,
    );
    _projectId = result['projectId'] as String;
    final current = Map<String, dynamic>.from(
      (result['current'] as Map?) ?? const <String, dynamic>{},
    );
    _nameController.text = (current['name'] as String?) ?? _nameController.text;
    _descriptionController.text =
        (current['description'] as String?) ?? _descriptionController.text;
    _selectedTemplate = template;
    await _loadDraftOrInitialize();
    if (!mounted) return;
    _showTopSnackBar('✅ Modèle appliqué: ${template.name}');
  }

  Future<void> _showDraftHistory() async {
    if (_projectId == null) {
      if (!mounted) return;
      _showTopSnackBar('ℹ️ Sauvegarde d’abord le projet.');
      return;
    }

    final drafts = await _versioning.listDrafts(
      projectId: _projectId!,
      pageSize: 30,
    );
    if (!mounted) return;

    final selected = await showDialog<CircuitDraftVersion>(
      context: context,
      builder: (ctx) {
        CircuitDraftVersion? picked = drafts.isNotEmpty ? drafts.first : null;
        Future<Map<String, dynamic>?> snapshotFuture =
            picked == null
            ? Future<Map<String, dynamic>?>.value(null)
          : _loadDraftSnapshot(projectId: _projectId!, draftId: picked.id);

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Historique des versions'),
              content: SizedBox(
                width: 560,
                child: drafts.isEmpty
                    ? const Text('Aucune version disponible')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<CircuitDraftVersion>(
                            value: picked,
                            decoration: const InputDecoration(
                              labelText: 'Version',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: drafts
                                .map(
                                  (d) => DropdownMenuItem<CircuitDraftVersion>(
                                    value: d,
                                    child: Text(
                                      'V${d.version} - ${_formatHistoryDate(d.createdAt)}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setLocal(() {
                                picked = value;
                                snapshotFuture = value == null
                                    ? Future<Map<String, dynamic>?>.value(null)
                                    : _loadDraftSnapshot(
                                        projectId: _projectId!,
                                        draftId: value.id,
                                      );
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: snapshotFuture,
                            builder: (context, snap) {
                              if (snap.connectionState != ConnectionState.done) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final snapshot = snap.data;
                              if (snapshot == null) {
                                return const Text(
                                  'Impossible de charger les détails de cette version.',
                                );
                              }

                              final changes = _buildHistoryChangeSummary(
                                oldSnapshot: snapshot,
                              );
                              return Container(
                                constraints: const BoxConstraints(maxHeight: 280),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: MasliveTokens.borderSoft,
                                  ),
                                ),
                                child: changes.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'Aucune modification détectée avec le brouillon actuel.',
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: changes.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          color: MasliveTokens.borderSoft,
                                        ),
                                        itemBuilder: (_, index) => ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.subdirectory_arrow_right,
                                            size: 18,
                                          ),
                                          title: Text(changes[index]),
                                        ),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
                FilledButton.icon(
                  onPressed: picked == null
                      ? null
                      : () => Navigator.pop(ctx, picked),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restaurer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;

    if (!_canWriteMapProjects) {
      if (!mounted) return;
      _showTopSnackBar(
        '⛔ Restauration réservée aux admins master.',
        isError: true,
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ensureActorContext();
    await _versioning.restoreDraft(
      projectId: _projectId!,
      draftId: selected.id,
      actorUid: user.uid,
      actorRole: _currentUserRole ?? 'creator',
      groupId: _currentGroupId ?? 'default',
    );
    await _loadDraftOrInitialize();
    if (!mounted) return;
    _showTopSnackBar('✅ Version ${selected.version} restaurée');
  }

  String _formatHistoryDate(DateTime? date) {
    if (date == null) return 'date inconnue';
    final local = date.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mn = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year} $hh:$mn';
  }

  Future<Map<String, dynamic>?> _loadDraftSnapshot({
    required String projectId,
    required String draftId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(projectId)
        .collection('drafts')
        .doc(draftId)
        .get();
    if (!snap.exists) return null;
    final data = snap.data() ?? const <String, dynamic>{};
    final raw = data['dataSnapshot'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  List<String> _buildHistoryChangeSummary({
    required Map<String, dynamic> oldSnapshot,
  }) {
    final current = _buildCurrentData();
    final lines = <String>[];

    void compareText(String key, String label) {
      final oldValue = (oldSnapshot[key] ?? '').toString().trim();
      final newValue = (current[key] ?? '').toString().trim();
      if (oldValue != newValue) {
        lines.add('$label: "$oldValue" -> "$newValue"');
      }
    }

    void compareCount(String key, String label) {
      final oldList = oldSnapshot[key];
      final newList = current[key];
      final oldCount = oldList is List ? oldList.length : 0;
      final newCount = newList is List ? newList.length : 0;
      if (oldCount != newCount) {
        lines.add('$label: $oldCount -> $newCount');
      }
    }

    compareText('name', 'Nom');
    compareText('description', 'Description');
    compareText('countryId', 'Pays');
    compareText('eventId', 'Événement');
    compareText('styleUrl', 'Style URL');
    compareCount('route', 'Points tracé');
    compareCount('perimeter', 'Points périmètre');

    final oldLayers = (oldSnapshot['layers'] is List)
        ? (oldSnapshot['layers'] as List).length
        : 0;
    if (oldLayers != _layers.length) {
      lines.add('Couches: $oldLayers -> ${_layers.length}');
    }

    final oldPois = (oldSnapshot['pois'] is List)
        ? (oldSnapshot['pois'] as List).length
        : 0;
    if (oldPois != _pois.length) {
      lines.add('POIs: $oldPois -> ${_pois.length}');
    }

    return lines;
  }

  @override
  void dispose() {
    _poiRouteStyleProTimer?.cancel();
    _poiRouteStyleProTimer = null;
    _routeSnapDebounce?.cancel();
    _pageController.dispose();
    _perimeterEditorController.dispose();
    _routeEditorController.dispose();
    _poiMapController.dispose();
    _poiSelection.removeListener(_onPoiSelectionChanged);
    _poiSelection.dispose();
    for (final controller in _wizardStepScrollControllers) {
      controller.removeListener(_syncWizardScrollRailState);
    }
    _poiStepScrollController.dispose();
    _templateStepScrollController.dispose();
    _infosStepScrollController.dispose();
    _perimeterStepScrollController.dispose();
    _routeStepScrollController.dispose();
    _validationStepScrollController.dispose();
    _publishStepScrollController.dispose();
    _wizardScrollProgress.dispose();
    _wizardScrollCanScroll.dispose();
    _styleProStepScrollController.dispose();
    _poiInlineNameController.dispose();
    _poiInlineLatController.dispose();
    _poiInlineLngController.dispose();
    _parkingZoneColorController.dispose();
    _parkingZoneStrokeColorController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _descriptionController.dispose();
    _styleUrlController.dispose();
    _styleUrlDebounce?.cancel();
    super.dispose();
  }

  List<ScrollController> get _wizardStepScrollControllers => <ScrollController>[
    _templateStepScrollController,
    _infosStepScrollController,
    _perimeterStepScrollController,
    _routeStepScrollController,
    _styleProStepScrollController,
    _poiStepScrollController,
    _validationStepScrollController,
    _publishStepScrollController,
  ];

  ScrollController? get _activeStepScrollController {
    switch (_currentStep) {
      case 0:
        return _templateStepScrollController;
      case 1:
        return _infosStepScrollController;
      case 2:
        return _perimeterStepScrollController;
      case 3:
        return _routeStepScrollController;
      case 4:
        return _styleProStepScrollController;
      case 5:
        return _poiStepScrollController;
      case 6:
        return _validationStepScrollController;
      case 7:
        return _publishStepScrollController;
      default:
        return null;
    }
  }

  void _syncWizardScrollRailState() {
    final controller = _activeStepScrollController;
    if (controller == null || !controller.hasClients) {
      if (_wizardScrollCanScroll.value != false) {
        _wizardScrollCanScroll.value = false;
      }
      if (_wizardScrollProgress.value != 0) {
        _wizardScrollProgress.value = 0;
      }
      return;
    }

    final maxScroll = controller.position.maxScrollExtent;
    final canScroll = maxScroll > 0;
    final progress = canScroll
        ? (controller.offset / maxScroll).clamp(0.0, 1.0)
        : 0.0;

    if (_wizardScrollCanScroll.value != canScroll) {
      _wizardScrollCanScroll.value = canScroll;
    }
    if ((_wizardScrollProgress.value - progress).abs() > 0.001) {
      _wizardScrollProgress.value = progress;
    }
  }

  Future<void> _jumpActiveStepToFraction(double fraction) async {
    final controller = _activeStepScrollController;
    if (controller == null || !controller.hasClients) return;
    final maxScroll = controller.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final target = (maxScroll * fraction.clamp(0.0, 1.0)).clamp(0.0, maxScroll);
    controller.jumpTo(target);
    _syncWizardScrollRailState();
  }

  Future<void> _animateActiveStepToFraction(double fraction) async {
    final controller = _activeStepScrollController;
    if (controller == null || !controller.hasClients) return;
    final maxScroll = controller.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final target = (maxScroll * fraction.clamp(0.0, 1.0)).clamp(0.0, maxScroll);
    await controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    _syncWizardScrollRailState();
  }

  Future<void> _nudgeActiveStepScroll(int direction) async {
    final controller = _activeStepScrollController;
    if (controller == null || !controller.hasClients) return;
    final step = math.max(controller.position.viewportDimension * 0.72, 240.0);
    final target = (controller.offset + (direction * step)).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    await controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _syncWizardScrollRailState();
  }

  void _onStyleUrlChanged(String _) {
    // Évite de recharger le style à chaque frappe.
    _styleUrlDebounce?.cancel();
    _styleUrlDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      final current = _styleUrlController.text;
      final normalized = _normalizeMapboxStyleUrl(current);
      if (normalized != current) {
        _styleUrlController.text = normalized;
        _styleUrlController.selection = TextSelection.collapsed(
          offset: normalized.length,
        );
      }

      setState(() {
        // La valeur source-of-truth reste _styleUrlController.text.
        // Le rebuild suffit pour propager le nouveau styleUrl aux MasLiveMap.
      });
    });
  }

  String _normalizeMapboxStyleUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return '';

    if (input.startsWith('mapbox://styles/')) {
      return input;
    }

    Uri uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {
      return input;
    }

    final host = uri.host.toLowerCase();

    // Cas fréquent: URL Mapbox Studio copiée depuis l'UI (page HTML).
    // Ex: https://studio.mapbox.com/styles/{user}/{styleId}/edit
    // => mapbox://styles/{user}/{styleId}
    if (host.contains('mapbox.com')) {
      final seg = uri.pathSegments;
      final stylesIndex = seg.indexOf('styles');
      if (stylesIndex != -1 && seg.length >= stylesIndex + 3) {
        final user = seg[stylesIndex + 1];
        final styleId = seg[stylesIndex + 2];
        if (user.isNotEmpty && styleId.isNotEmpty) {
          return 'mapbox://styles/$user/$styleId';
        }
      }
    }

    // Certains liens finissent par ".html" (HTML, non JSON). On tente d'enlever le suffixe.
    if (input.toLowerCase().endsWith('.html')) {
      return input.substring(0, input.length - 5);
    }

    return input;
  }

  void _applyStylePreset(String styleUrl) {
    _styleUrlDebounce?.cancel();
    final normalized = _normalizeMapboxStyleUrl(styleUrl);
    _styleUrlController.text = normalized;
    _styleUrlController.selection = TextSelection.collapsed(
      offset: normalized.length,
    );
    if (!mounted) return;
    setState(() {
      // Rebuild immédiat pour que la preview réagisse au clic.
    });
  }

  void _ensurePoiInitialCamera() {
    if (_poiInitialLng != null &&
        _poiInitialLat != null &&
        _poiInitialZoom != null) {
      return;
    }

    final lng = _routePoints.isNotEmpty
        ? _routePoints.first.lng
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lng : -61.533);
    final lat = _routePoints.isNotEmpty
        ? _routePoints.first.lat
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lat : 16.241);
    final zoom = (_routePoints.isNotEmpty || _perimeterPoints.isNotEmpty)
        ? _perimeterCameraInitialZoom
        : 12.0;

    _poiInitialLng = lng;
    _poiInitialLat = lat;
    _poiInitialZoom = zoom;
  }

  Future<void> _loadDraftOrInitialize() async {
    try {
      setState(() => _isLoading = true);

      await _ensureActorContext();
      await _loadTemplates();

      // Si un projectId est fouirni, le charger
      if (_projectId != null) {
        final data = await _repository.loadProjectCurrent(
          projectId: _projectId!,
          fallbackCountryId: widget.countryId,
          fallbackEventId: widget.eventId,
          fallbackCircuitId: widget.circuitId,
        );

        if (data != null) {
          _draftData = data;
          _nameController.text = _draftData['name'] ?? '';
          _countryController.text = _draftData['countryId'] ?? '';
          _eventController.text = _draftData['eventId'] ?? '';
          _descriptionController.text = _draftData['description'] ?? '';
          _styleUrlController.text = _draftData['styleUrl'] ?? '';

          // Style tracé
          final routeStyle = _draftData['routeStyle'];
          if (routeStyle is Map) {
            final m = Map<String, dynamic>.from(routeStyle);
            _routeColorHex = (m['color'] as String?)?.trim().isNotEmpty == true
                ? (m['color'] as String).trim()
                : _routeColorHex;
            final w = m['width'];
            if (w is num) _routeWidth = w.toDouble();
            final rl = m['roadLike'];
            if (rl is bool) _routeRoadLike = rl;
            final sh = m['shadow3d'];
            if (sh is bool) _routeShadow3d = sh;
            final sd = m['showDirection'];
            if (sd is bool) _routeShowDirection = sd;
            final ad = m['animateDirection'];
            if (ad is bool) _routeAnimateDirection = ad;
            final sp = m['animationSpeed'];
            if (sp is num) _routeAnimationSpeed = sp.toDouble();
          }

          // Style Pro (si présent) : utilisé ensuite pour le rendu des étapes suivantes
          final routeStylePro = _draftData['routeStylePro'];
          if (routeStylePro is Map) {
            try {
              _routeStyleProConfig = rsp.RouteStyleConfig.fromJson(
                Map<String, dynamic>.from(routeStylePro),
              ).validated();
            } catch (_) {
              _routeStyleProConfig = null;
            }
          } else {
            _routeStyleProConfig = null;
          }

          // Charger points
          final perimData = _draftData['perimeter'] as List<dynamic>?;
          if (perimData != null) {
            _perimeterPoints = perimData.map((p) {
              final m = p as Map<String, dynamic>;
              return (lng: m['lng'] as double, lat: m['lat'] as double);
            }).toList();
          }

          // Optionnel: restauration du mode cercle (centre + diamètre)
          final circleData = _draftData['perimeterCircle'];
          if (circleData is Map) {
            final m = Map<String, dynamic>.from(circleData);
            final enabled = (m['enabled'] as bool?) ?? false;
            if (enabled) {
              _perimeterCircleMode = true;
              _perimeterCircleCenterLocked =
                  (m['centerLocked'] as bool?) ?? false;

              final center = m['center'];
              if (center is Map) {
                final cm = Map<String, dynamic>.from(center);
                final lng = cm['lng'];
                final lat = cm['lat'];
                if (lng is num && lat is num) {
                  _perimeterCircleCenter = (
                    lng: lng.toDouble(),
                    lat: lat.toDouble(),
                  );
                }
              }

              final diam = m['diameterMeters'];
              if (diam is num) {
                _perimeterCircleDiameterMeters = diam.toDouble();
              }

              // Si on a le centre mais pas (ou peu) de points, régénère.
              if (_perimeterCircleCenter != null &&
                  _perimeterPoints.length < 3) {
                _perimeterPoints = _circlePerimeter(
                  center: _perimeterCircleCenter!,
                  diameterMeters: _perimeterCircleDiameterMeters,
                );
              }
              if (_perimeterCircleCenter == null) {
                _perimeterCircleCenterLocked = false;
              }
            }
          }

          // Caméra (étape périmètre)
          final camData = _draftData['perimeterMapCamera'];
          if (camData is Map) {
            final m = Map<String, dynamic>.from(camData);
            final iz = m['initialZoom'];
            final th = m['pitchZoomThreshold'];
            final pd = m['pitchDegrees'];
            final mz = m['maxZoom'];
            if (iz is num) _perimeterCameraInitialZoom = iz.toDouble();
            if (th is num) _perimeterCameraPitchZoomThreshold = th.toDouble();
            if (pd is num) _perimeterCameraPitchDegrees = pd.toDouble();
            if (mz is num) _perimeterCameraMaxZoom = mz.toDouble();

            _perimeterCameraInitialZoom = _perimeterCameraInitialZoom.clamp(
              0.0,
              22.0,
            );
            _perimeterCameraMaxZoom = _perimeterCameraMaxZoom.clamp(
              _perimeterCameraInitialZoom,
              22.0,
            );
            _perimeterCameraPitchZoomThreshold =
                _perimeterCameraPitchZoomThreshold.clamp(
                  0.0,
                  _perimeterCameraMaxZoom,
                );
            _perimeterCameraPitchDegrees = _perimeterCameraPitchDegrees.clamp(
              0.0,
              _perimeterCameraPitchMaxDegrees,
            );
          }

          final routeData = _draftData['route'] as List<dynamic>?;
          if (routeData != null) {
            _routePoints = routeData.map((p) {
              final m = p as Map<String, dynamic>;
              return (lng: m['lng'] as double, lat: m['lat'] as double);
            }).toList();
          }

          // Charger layers
          _layers = await _loadLayers();

          // Assure les couches POI attendues (visit/food/assistance/parking/wc)
          // et migre les anciens types (tour/visiter -> visit).
          await _ensureDefaultPoiLayers();

          // Charger POI (paginé)
          await _loadPoisFirstPage();

          // Couche sélectionnée par défaut
          if (_layers.isNotEmpty) {
            _selectedLayer = _layers.firstWhere(
              (l) => l.type != 'route',
              orElse: () => _layers.first,
            );
          }
        }
      } else {
        // Nouveau brouillon
        _countryController.text = widget.countryId ?? '';
        _eventController.text = widget.eventId ?? '';

        // Pas de Style Pro au démarrage d'un nouveau projet
        _routeStyleProConfig = null;

        // Initialiser les couches standard en local
        _layers = await _loadLayers();
        _pois = [];
        _poisLastDoc = null;
        _hasMorePois = false;
        _isLoadingMorePois = false;
        if (_layers.isNotEmpty) {
          _selectedLayer = _layers.firstWhere(
            (l) => l.type != 'route',
            orElse: () => _layers.first,
          );
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        if (e is FirebaseException) {
          _errorMessage =
              'Erreur chargement (${e.code}): ${e.message ?? e.toString()}';
        } else {
          _errorMessage = 'Erreur chargement: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<List<MarketMapLayer>> _loadLayers() async {
    if (_projectId == null) {
      // Initialiser les 6 couches standard
      return [
        MarketMapLayer(
          id: '1',
          label: 'Tracé Route',
          type: 'route',
          isVisible: true,
          zIndex: 1,
          color: '#1A73E8',
        ),
        MarketMapLayer(
          id: '2',
          label: 'Parkings',
          type: 'parking',
          isVisible: true,
          zIndex: 2,
          color: _parkingZoneDefaultFillHex,
        ),
        MarketMapLayer(
          id: '3',
          label: 'Toilettes',
          type: 'wc',
          isVisible: true,
          zIndex: 3,
          color: '#9333EA',
        ),
        MarketMapLayer(
          id: '4',
          label: 'Food',
          type: 'food',
          isVisible: true,
          zIndex: 4,
          color: '#EF4444',
        ),
        MarketMapLayer(
          id: '5',
          label: 'Assistance',
          type: 'assistance',
          isVisible: true,
          zIndex: 5,
          color: '#34A853',
        ),
        MarketMapLayer(
          id: '6',
          label: 'Lieux à visiter',
          type: 'visit',
          isVisible: true,
          zIndex: 6,
          color: '#F59E0B',
        ),
      ];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(_projectId)
        .collection('layers')
        .orderBy('zIndex')
        .get();

    return snapshot.docs
        .map((doc) => MarketMapLayer.fromFirestore(doc))
        .toList();
  }

  String _normalizePoiLayerType(String raw) {
    final norm = raw.trim().toLowerCase();
    if (norm == 'tour' || norm == 'visiter') return 'visit';
    if (norm == 'toilet' || norm == 'toilets') return 'wc';
    return norm;
  }

  bool _poiMatchesSelectedLayer(MarketMapPOI poi, MarketMapLayer layer) {
    return _normalizePoiLayerType(poi.layerType) ==
        _normalizePoiLayerType(layer.type);
  }

  Future<void> _migrateLegacyPoiTypesToVisit({
    required String projectId,
  }) async {
    if (!_canWriteMapProjects) return;

    final db = FirebaseFirestore.instance;
    final col = db.collection('map_projects').doc(projectId).collection('pois');

    // Migration ciblée (pas de scan complet): tour/visiter -> visit
    final snap = await col
        .where('layerType', whereIn: const ['tour', 'visiter'])
        .get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = db.batch();
    int ops = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (ops == 0) return;
      if (!force && ops < 450) return;
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }

    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'layerType': 'visit',
        'layerId': 'visit',
        // Compat: certains écrans lisent `type`
        'type': 'visit',
      });
      ops++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }

  Future<void> _ensureDefaultPoiLayers() async {
    final projectId = _projectId;
    if (projectId == null || projectId.trim().isEmpty) return;

    // 1) Migration POI legacy (pour cohérence avec Home: visit)
    try {
      await _migrateLegacyPoiTypesToVisit(projectId: projectId);
    } catch (e) {
      debugPrint('WizardPro migrate POI types error: $e');
    }

    // 2) Assurer les couches attendues côté wizard/Home
    const defaults =
        <({String type, String label, String color, int preferredZ})>[
          (
            type: 'route',
            label: 'Tracé Route',
            color: '#1A73E8',
            preferredZ: 1,
          ),
          (
            type: 'parking',
            label: 'Parkings',
            color: _parkingZoneDefaultFillHex,
            preferredZ: 2,
          ),
          (type: 'wc', label: 'Toilettes', color: '#9333EA', preferredZ: 3),
          (type: 'food', label: 'Food', color: '#EF4444', preferredZ: 4),
          (
            type: 'assistance',
            label: 'Assistance',
            color: '#34A853',
            preferredZ: 5,
          ),
          (
            type: 'visit',
            label: 'Lieux à visiter',
            color: '#F59E0B',
            preferredZ: 6,
          ),
        ];

    bool hasExactLayerType(String t) {
      final norm = t.trim().toLowerCase();
      return _layers.any((l) => l.type.trim().toLowerCase() == norm);
    }

    final usedZ = _layers.map((l) => l.zIndex).toSet();
    int maxZ = 0;
    for (final z in usedZ) {
      if (z > maxZ) maxZ = z;
    }

    int allocZ(int preferred) {
      if (!usedZ.contains(preferred)) {
        usedZ.add(preferred);
        if (preferred > maxZ) maxZ = preferred;
        return preferred;
      }
      maxZ += 1;
      usedZ.add(maxZ);
      return maxZ;
    }

    // Si pas de couche `visit` mais une legacy `tour/visiter` existe,
    // on la convertit en `visit` pour éviter des doublons.
    final hasVisit = hasExactLayerType('visit');
    if (!hasVisit) {
      final idx = _layers.indexWhere(
        (l) => ['tour', 'visiter'].contains(l.type.trim().toLowerCase()),
      );
      if (idx >= 0 && _canWriteMapProjects) {
        final legacy = _layers[idx];
        try {
          await FirebaseFirestore.instance
              .collection('map_projects')
              .doc(projectId)
              .collection('layers')
              .doc(legacy.id)
              .set({'type': 'visit'}, SetOptions(merge: true));
          final migrated = legacy.copyWith(type: 'visit');
          _layers[idx] = migrated;
          if (_selectedLayer?.id == legacy.id) {
            _selectedLayer = migrated;
          }
        } catch (e) {
          debugPrint('WizardPro migrate layer tour->visit error: $e');
        }
      }
    }

    final db = FirebaseFirestore.instance;
    final layersCol = db
        .collection('map_projects')
        .doc(projectId)
        .collection('layers');
    WriteBatch? batch;
    int writes = 0;

    void queueWrite(DocumentReference ref, Map<String, dynamic> data) {
      batch ??= db.batch();
      batch!.set(ref, data, SetOptions(merge: true));
      writes += 1;
    }

    for (final d in defaults) {
      if (hasExactLayerType(d.type)) continue;

      final layer = MarketMapLayer(
        id: d.type,
        label: d.label,
        type: d.type,
        isVisible: true,
        zIndex: allocZ(d.preferredZ),
        color: d.color,
      );
      _layers.add(layer);
      if (_canWriteMapProjects) {
        queueWrite(layersCol.doc(layer.id), layer.toFirestore());
      }
    }

    if (batch != null && writes > 0) {
      try {
        await batch!.commit();
      } catch (e) {
        debugPrint('WizardPro ensure POI layers commit error: $e');
      }
    }

    _layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Si la couche sélectionnée a disparu ou est nulle, on en choisit une valide.
    if (_selectedLayer == null && _layers.isNotEmpty) {
      _selectedLayer = _layers.firstWhere(
        (l) => _normalizePoiLayerType(l.type) != 'route',
        orElse: () => _layers.first,
      );
    }
  }

  Future<void> _loadPoisFirstPage() async {
    if (_projectId == null) {
      _pois = [];
      _poisLastDoc = null;
      _hasMorePois = false;
      _isLoadingMorePois = false;
      return;
    }

    final page = await _repository.listPoisPage(
      projectId: _projectId!,
      pageSize: _poiPageSize,
    );

    _pois = page.docs.map((doc) => MarketMapPOI.fromFirestore(doc)).toList();
    _poisLastDoc = page.docs.isNotEmpty ? page.docs.last : null;
    _hasMorePois = page.docs.length == _poiPageSize;
  }

  Future<void> _loadMorePoisPage() async {
    if (_projectId == null || _isLoadingMorePois || !_hasMorePois) return;

    setState(() => _isLoadingMorePois = true);
    try {
      final page = await _repository.listPoisPage(
        projectId: _projectId!,
        pageSize: _poiPageSize,
        startAfter: _poisLastDoc,
      );

      final incoming = page.docs
          .map((doc) => MarketMapPOI.fromFirestore(doc))
          .toList();
      final existingIds = _pois.map((p) => p.id).toSet();
      _pois.addAll(incoming.where((p) => !existingIds.contains(p.id)));

      _poisLastDoc = page.docs.isNotEmpty ? page.docs.last : _poisLastDoc;
      _hasMorePois = page.docs.length == _poiPageSize;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMorePois = false);
      } else {
        _isLoadingMorePois = false;
      }
    }

    // Si l'utilisateur est déjà sur une couche, on rafraîchit l'affichage.
    if (mounted && _selectedLayer != null) {
      _refreshPoiMarkers();
    }
  }

  Future<void> _saveDraft({
    bool createSnapshot = false,
    bool ensureRouteSnapped = true,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Garantit que le tracé est bien "au milieu de la voie" au moment
      // de la persistance (si l'utilisateur clique vite après avoir posé des points).
      // On ne persiste pas ici: on laisse `_repository.saveDraft` écrire `currentData`.
      if (ensureRouteSnapped && _currentStep == 3) {
        await _ensureRouteSnappedBeforePersist();
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar(
          '⛔ Sauvegarde réservée aux admins master.',
          isError: true,
        );
        return;
      }

      final isNew = _projectId == null;
      final projectId = _projectId ?? _repository.createProjectId();
      _projectId = projectId;

      // IMPORTANT: le saveDraft sync les POIs (avec suppression des doc absents).
      // Si la pagination n'a pas tout chargé, on risquerait de supprimer des POIs.
      await _ensureAllPoisLoadedForPublish();

      final previousRouteCount = (_draftData['route'] as List?)?.length ?? 0;
      final previousPoiCount = _pois.length;
      final currentData = _buildCurrentData();

      await _repository.saveDraft(
        projectId: projectId,
        actorUid: user.uid,
        actorRole: _currentUserRole ?? 'creator',
        groupId: _currentGroupId ?? 'default',
        currentData: currentData,
        layers: _layers,
        pois: _pois,
        previousRouteCount: previousRouteCount,
        previousPoiCount: previousPoiCount,
        isNew: isNew,
      );

      _draftData = currentData;

      // Alimente l'historique des versions uniquement sur action explicite.
      // Important: ne pas créer de versions sur les autosaves silencieux (ex: snap route)
      // pour éviter de spammer la sous-collection `drafts`.
      if (createSnapshot) {
        try {
          await _versioning.saveDraftVersion(
            projectId: projectId,
            actorUid: user.uid,
            actorRole: _currentUserRole ?? 'creator',
            groupId: _currentGroupId ?? 'default',
            currentData: currentData,
            layers: _layers,
            pois: _pois,
          );
        } catch (e) {
          debugPrint('WizardPro _saveDraft snapshot error: $e');
        }
      }

      if (mounted) {
        _showTopSnackBar('✅ Brouillon sauvegardé');
      }
    } catch (e) {
      debugPrint('WizardPro _saveDraft error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  Future<void> _continueToStep(int step) async {
    if (widget.poiOnly && step != _poiStepIndex) return;
    // Valider l'étape courante
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showTopSnackBar('❌ Nom requis', isError: true);
        return;
      }
    }

    // En quittant l'étape Tracé + Style, on force un snap immédiat et on attend.
    // Objectif: le tracé reste toujours centré sur la route, même si l'utilisateur
    // a posé les points "à la main" et enchaîne rapidement sur l'étape suivante.
    final leavingRouteStep = _currentStep == 3 && step != 3;
    if (leavingRouteStep) {
      await _ensureRouteSnappedBeforePersist();
    }

    final leavingStyleProStep = _currentStep == 4 && step != 4;
    if (leavingStyleProStep) {
      await _routeStyleProController.flushPendingChanges();
      final projectId = _projectId;
      if (projectId != null && projectId.trim().isNotEmpty) {
        await _reloadRouteAndStyleFromFirestore(projectId);
      }
    }

    if (_canWriteMapProjects) {
      await _saveDraft(
        createSnapshot: true,
        ensureRouteSnapped: !leavingRouteStep,
      );
    }
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _goToPreviousStep() async {
    if (widget.poiOnly || _currentStep <= 0) return;

    final targetStep = _currentStep - 1;

    final leavingStyleProStep = _currentStep == 4;
    if (leavingStyleProStep) {
      await _routeStyleProController.flushPendingChanges();
      final projectId = _projectId;
      if (projectId != null && projectId.trim().isNotEmpty) {
        await _reloadRouteAndStyleFromFirestore(projectId);
      }
    }

    if (_canWriteMapProjects) {
      await _saveDraft(createSnapshot: true, ensureRouteSnapped: false);
    }

    if (!mounted) return;
    setState(() => _currentStep = targetStep);
    await _pageController.animateToPage(
      targetStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _ensureRouteSnappedBeforePersist() async {
    if (_routePoints.length < 2) return;

    // Si un snap est déjà en cours, on attend un peu qu'il se termine.
    // (Evite un early-return de `_snapRouteToRoadsInternal`.)
    final startedAt = DateTime.now();
    while (mounted &&
        _isSnappingRoute &&
        DateTime.now().difference(startedAt) < const Duration(seconds: 8)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    // Snap silencieux (sans snack) et sans persistance Firestore.
    // La persistance est faite ensuite via `_saveDraft`/`_repository.saveDraft`.
    await _snapRouteToRoadsInternal(
      persist: false,
      showSnackBar: false,
      expectedSeq: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: SoftBackground(
          child: Column(
            children: [
              const GlassAppBar(title: 'Chargement…', padding: EdgeInsets.zero),
              const SizedBox(height: MasliveTokens.s),
              _buildWizardStepper(interactive: false),
              const SizedBox(height: MasliveTokens.s),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SoftBackground(
          child: Column(
            children: [
              const GlassAppBar(title: 'Erreur', padding: EdgeInsets.zero),
              const SizedBox(height: MasliveTokens.s),
              _buildWizardStepper(interactive: false),
              const SizedBox(height: MasliveTokens.s),
              Expanded(
                child: Center(
                  child: GlassPanel(
                    padding: const EdgeInsets.all(MasliveTokens.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: MasliveTokens.m),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MasliveTokens.text,
                          ),
                        ),
                        const SizedBox(height: MasliveTokens.m),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: MasliveTokens.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Retour'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SoftBackground(
        child: Column(
          children: [
            const GlassAppBar(
              title: 'Wizard Circuit Pro',
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _wizardScrollRailWidth,
                    child: _buildWizardScrollRail(),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) {
                            setState(() => _currentStep = page);

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              if (_currentStep == _poiStepIndex) {
                                unawaited(_refreshPoiRouteOverlay());
                              }

                              _syncPoiRouteStyleProTimer();
                              _syncWizardScrollRailState();
                            });
                          },
                          children: [
                            _wrapWizardStep(_buildStep0Template()),
                            _wrapWizardStep(_buildStep1Infos()),
                            _wrapWizardStep(_buildStep2Perimeter()),
                            _wrapWizardStep(_buildStep3RouteAndStyleTabbed()),
                            _wrapWizardStep(_buildStep6StylePro()),
                            _wrapWizardStep(_buildStep5POI()),
                            _wrapWizardStep(_buildStep7Validation()),
                            _wrapWizardStep(_buildStep8Publish()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            WizardBottomBar(
              outerPadding: EdgeInsets.zero,
              panelPadding: EdgeInsets.zero,
              showPrevious: (!widget.poiOnly && _currentStep > 0),
              onPrevious: (!widget.poiOnly && _currentStep > 0)
                  ? () => unawaited(_goToPreviousStep())
                  : null,
              onSave: () => _saveDraft(createSnapshot: true),
              showNext: (!widget.poiOnly && _currentStep < 7),
              onNext: (!widget.poiOnly && _currentStep < 7)
                  ? () => _continueToStep(_currentStep + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3RouteAndStyleTabbed() {
    // UX: fusion Tracé + Style (un seul affichage).
    // Tous les outils sont réunis dans la barre centrale.
    return _buildStep3RouteAndStyleUnified();
  }

  Widget _buildStep3RouteAndStyleUnified() {
    final proCfg = _routeStyleProConfig?.validated();
    final mapHeight = _expandedWizardRouteMapHeight(context);
    return CircuitMapEditor(
      title: 'Tracé + Style',
      subtitle: 'Tracez l\'itinéraire et réglez son apparence',
      points: _routePoints,
      controller: _routeEditorController,
      perimeterOverlay: _perimeterPoints,
      lockMapToPerimeter: true,
      cameraInitialZoom: _perimeterCameraInitialZoom,
      cameraMaxZoom: _perimeterCameraMaxZoom,
      cameraPitchZoomThreshold: _perimeterCameraPitchZoomThreshold,
      cameraPitchDegrees: _perimeterCameraPitchDegrees,
      styleUrl: _normalizeMapboxStyleUrl(_styleUrlController.text).isEmpty
          ? null
          : _normalizeMapboxStyleUrl(_styleUrlController.text),
      buildings3dEnabled: proCfg?.buildings3dEnabled,
      buildingsOpacity: proCfg?.buildingOpacity,
      showToolbar: false,
      showHeader: false,
      allowVerticalScroll: true,
      mapHeight: mapHeight,
      externalScrollController: _routeStepScrollController,
      topContent: _buildWizardScrollableHeader(
        toolbar: _buildCentralMapToolsBar(isPerimeter: false),
      ),
      onPointsChanged: (points) {
        final previousCount = _routePoints.length;
        setState(() {
          _routePoints = points;
        });

        // Waze-like: après ajout de point, on aligne automatiquement sur route.
        // Important: on ne spam pas pendant les glisser-déposer.
        if (_currentStep == 3 &&
            points.length >= 2 &&
            points.length > previousCount) {
          _scheduleContinuousRouteSnap();
        }
      },
      onSave: _saveDraft,
      mode: 'polyline',

      // Style itinéraire routier
      polylineColor: _parseHexColor(_routeColorHex, fallback: Colors.blue),
      polylineWidth: _routeWidth,
      polylineRoadLike: _routeRoadLike,
      polylineShadow3d: _routeShadow3d,
      polylineShowDirection: _routeShowDirection,
      polylineAnimateDirection: _routeAnimateDirection,
      polylineAnimationSpeed: _routeAnimationSpeed,
      polylineOpacity: proCfg?.opacity,
    );
  }

  Widget _buildStep0Template() {
    final compactActions = MediaQuery.sizeOf(context).width < 520;
    return GlassScrollbar(
      controller: _templateStepScrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: SingleChildScrollView(
        controller: _templateStepScrollController,
        physics: _isWizardMapInteracting
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.fromLTRB(
          _wizardStepHorizontalPadding,
          0,
          _wizardStepHorizontalPadding,
          kBottomNavigationBarHeight + MasliveTokens.l,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.all(MasliveTokens.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWizardScrollableHeader(padding: EdgeInsets.zero),
              const Text(
                'Choisir un modèle (optionnel)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Text(
                'Tu peux démarrer depuis un template global ou passer cette étape.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MasliveTokens.textSoft,
                ),
              ),
              const SizedBox(height: MasliveTokens.l),
              DropdownButtonFormField<CircuitTemplate>(
                initialValue: _selectedTemplate,
                items: _templates
                    .map(
                      (t) => DropdownMenuItem<CircuitTemplate>(
                        value: t,
                        child: Text('${t.name} (${t.category})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedTemplate = value),
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Wrap(
                spacing: MasliveTokens.s,
                runSpacing: MasliveTokens.s,
                children: [
                  if (compactActions)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: _selectedTemplate == null
                            ? null
                            : () => _applyTemplate(_selectedTemplate!),
                        label: const Text('Appliquer le modèle'),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: _selectedTemplate == null
                          ? null
                          : () => _applyTemplate(_selectedTemplate!),
                      label: const Text('Appliquer le modèle'),
                    ),
                  if (compactActions)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.history),
                        onPressed: _showDraftHistory,
                        label: const Text('Historique'),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      onPressed: _showDraftHistory,
                      label: const Text('Historique'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Infos() {
    return GlassScrollbar(
      controller: _infosStepScrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: SingleChildScrollView(
        controller: _infosStepScrollController,
        physics: _isWizardMapInteracting
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.fromLTRB(
          _wizardStepHorizontalPadding,
          0,
          _wizardStepHorizontalPadding,
          kBottomNavigationBarHeight + MasliveTokens.l,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.all(MasliveTokens.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWizardScrollableHeader(padding: EdgeInsets.zero),
              const Text(
                'Informations de base',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  onPressed: _showDraftHistory,
                  label: const Text('Historique des modifications'),
                ),
              ),
              const SizedBox(height: MasliveTokens.l),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du circuit *',
                  hintText: 'Ex: Circuit Côte Nord',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              StreamBuilder<List<MarketCountry>>(
                stream: _marketMapService.watchCountries(),
                builder: (context, snap) {
                  final items = snap.data ?? const <MarketCountry>[];

                  // Fallback: champ texte si la liste n'est pas dispo.
                  if (snap.hasError || items.isEmpty) {
                    return TextField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Pays *',
                        hintText: 'Ex: guadeloupe',
                        border: OutlineInputBorder(),
                      ),
                    );
                  }

                  return MarketCountryAutocompleteField(
                    items: items,
                    controller: _countryController,
                    labelText: 'Pays *',
                    hintText: 'Rechercher un pays…',
                    valueForOption: (c) => c.id,
                    onSelected: (_) {},
                  );
                },
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Événement *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _styleUrlController,
                onChanged: _onStyleUrlChanged,
                decoration: const InputDecoration(
                  labelText: 'Style URL Mapbox (optionnel)',
                  hintText: 'mapbox://styles/username/style-id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Builder(
                builder: (context) {
                  final current = _normalizeMapboxStyleUrl(
                    _styleUrlController.text,
                  );
                  final presets = <({String label, String url})>[
                    (label: 'Effacer', url: ''),
                    (
                      label: 'Streets',
                      url: 'mapbox://styles/mapbox/streets-v12',
                    ),
                    (
                      label: 'Outdoors',
                      url: 'mapbox://styles/mapbox/outdoors-v12',
                    ),
                    (
                      label: 'Satellite',
                      url: 'mapbox://styles/mapbox/satellite-streets-v12',
                    ),
                    (label: 'Light', url: 'mapbox://styles/mapbox/light-v11'),
                    (label: 'Dark', url: 'mapbox://styles/mapbox/dark-v11'),
                    (
                      label: 'Perso (stef971fwi)',
                      url:
                          'mapbox://styles/stef971fwi/cmmgh2oa000rk01qr65il695n',
                    ),
                  ];

                  Widget pill({required String label, required String url}) {
                    final normalized = _normalizeMapboxStyleUrl(url);
                    final selected =
                        (normalized.isEmpty && current.isEmpty) ||
                        (normalized.isNotEmpty && normalized == current);

                    final bg = selected
                        ? MasliveTokens.primary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.74);
                    final fg = selected
                        ? MasliveTokens.primary
                        : MasliveTokens.text;

                    return InkWell(
                      onTap: () => _applyStylePreset(url),
                      borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MasliveTokens.m,
                          vertical: MasliveTokens.s,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(
                            MasliveTokens.rPill,
                          ),
                          border: Border.all(
                            color: selected
                                ? MasliveTokens.primary.withValues(alpha: 0.22)
                                : MasliveTokens.borderSoft,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presets rapides',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MasliveTokens.text,
                        ),
                      ),
                      const SizedBox(height: MasliveTokens.xs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final p in presets) ...[
                              pill(label: p.label, url: p.url),
                              const SizedBox(width: MasliveTokens.xs),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: MasliveTokens.m),
              ClipRRect(
                borderRadius: BorderRadius.circular(MasliveTokens.rL),
                child: SizedBox(
                  height: 440,
                  child: _wrapWizardMapToBlockScroll(
                    MasLiveMap(
                      initialLng: _routePoints.isNotEmpty
                          ? _routePoints.first.lng
                          : (_perimeterPoints.isNotEmpty
                                ? _perimeterPoints.first.lng
                                : -61.533),
                      initialLat: _routePoints.isNotEmpty
                          ? _routePoints.first.lat
                          : (_perimeterPoints.isNotEmpty
                                ? _perimeterPoints.first.lat
                                : 16.241),
                      initialZoom:
                          (_routePoints.isNotEmpty ||
                              _perimeterPoints.isNotEmpty)
                          ? 13.5
                          : 12.0,
                      styleUrl:
                          _normalizeMapboxStyleUrl(
                            _styleUrlController.text,
                          ).isEmpty
                          ? null
                          : _normalizeMapboxStyleUrl(_styleUrlController.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MasliveTokens.xl),
              GlassPanel(
                radius: MasliveTokens.rM,
                opacity: 0.74,
                padding: const EdgeInsets.all(MasliveTokens.m),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: MasliveTokens.textSoft,
                    ),
                    const SizedBox(width: MasliveTokens.s),
                    Expanded(
                      child: Text(
                        'Complétez les informations de base, puis définissez le périmètre et le tracé sur les étapes suivantes.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MasliveTokens.textSoft,
                        ),
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

  Widget _buildStep2Perimeter() {
    final proCfg = _routeStyleProConfig?.validated();
    final mapHeight = _expandedWizardMapHeight(context);
    final pointsListMaxHeight = _responsiveWizardPointsListMaxHeight(context);
    return CircuitMapEditor(
      title: 'Définir le périmètre',
      subtitle: 'Tracez la zone de couverture (polygon fermé)',
      points: _perimeterPoints,
      controller: _perimeterEditorController,
      styleUrl: _normalizeMapboxStyleUrl(_styleUrlController.text).isEmpty
          ? null
          : _normalizeMapboxStyleUrl(_styleUrlController.text),
      buildings3dEnabled: proCfg?.buildings3dEnabled,
      buildingsOpacity: proCfg?.buildingOpacity,

      // Verrouillage + caméra (périmètre)
      lockMapToPerimeter: true,
      cameraInitialZoom: _perimeterCameraInitialZoom,
      cameraMaxZoom: _perimeterCameraMaxZoom,
      cameraPitchZoomThreshold: _perimeterCameraPitchZoomThreshold,
      cameraPitchDegrees: _perimeterCameraPitchDegrees,

      editingEnabled: true,
      onPointAddedOverride: _perimeterCircleMode
          ? (p) {
              if (_perimeterCircleCenterLocked &&
                  _perimeterCircleCenter != null) {
                return;
              }
              _applyPerimeterCircle(center: p);
            }
          : null,
      centerMarker: _perimeterCircleMode ? _perimeterCircleCenter : null,
      showPointMarkers: !_perimeterCircleMode,
      showPointsList: !_perimeterCircleMode,
      showToolbar: false,
      showHeader: false,
      allowVerticalScroll: true,
      mapHeight: mapHeight,
      externalScrollController: _perimeterStepScrollController,
      topContent: _buildWizardScrollableHeader(
        toolbar: _buildCentralMapToolsBar(isPerimeter: true),
      ),
      pointsListMaxHeight: pointsListMaxHeight,
      onPointsChanged: (points) {
        setState(() {
          _perimeterPoints = points;
        });
      },
      onSave: _saveDraft,
    );
  }

  Widget _buildCentralMapToolsBar({required bool isPerimeter}) {
    final controller = isPerimeter
        ? _perimeterEditorController
        : _routeEditorController;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final toolbarMaxWidth = screenWidth >= 1180
        ? 780.0
        : screenWidth >= 720
        ? 700.0
        : double.infinity;

    final isRouteAndStyleStep = !isPerimeter;
    const toolbarSectionStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: MasliveTokens.text,
      letterSpacing: 0.1,
    );
    const toolbarValueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: MasliveTokens.text,
    );
    final toolbarHintStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: MasliveTokens.textSoft,
    );

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: toolbarMaxWidth),
      child: GlassPanel(
        radius: MasliveTokens.rM,
        opacity: 0.92,
        padding: const EdgeInsets.symmetric(
          horizontal: MasliveTokens.s,
          vertical: MasliveTokens.s,
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final colorScheme = Theme.of(context).colorScheme;
            final routeIsLooped =
                !isPerimeter &&
                _routePoints.length >= 2 &&
                _routePoints.first == _routePoints.last;

            final perimeterIsLooped =
                isPerimeter &&
                _perimeterPoints.length >= 2 &&
                _perimeterPoints.first == _perimeterPoints.last;

            Widget toolbarActionButton({
              required IconData icon,
              required String tooltip,
              required VoidCallback? onPressed,
              bool active = false,
              Color? accent,
              Widget? child,
            }) {
              final tint = accent ?? MasliveTokens.primary;
              return IconButton.filledTonal(
                tooltip: tooltip,
                onPressed: onPressed,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: active ? tint : MasliveTokens.text,
                  backgroundColor: active
                      ? tint.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.82),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.34),
                  disabledForegroundColor: MasliveTokens.textSoft.withValues(
                    alpha: 0.5,
                  ),
                ),
                icon: child ?? Icon(icon, size: 18),
              );
            }

            Widget toolbarMetric({
              required String label,
              required String value,
              IconData? icon,
              Color? accent,
            }) {
              final tint = accent ?? MasliveTokens.primary;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MasliveTokens.xs,
                  vertical: MasliveTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(MasliveTokens.rS),
                  border: Border.all(color: tint.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: tint),
                      const SizedBox(width: 6),
                    ],
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: toolbarHintStyle),
                        Text(value, style: toolbarSectionStyle),
                      ],
                    ),
                  ],
                ),
              );
            }

            Widget toolbarSection({
              required String title,
              required IconData icon,
              required List<Widget> children,
              Color? accent,
              bool compact = false,
            }) {
              final tint = accent ?? MasliveTokens.primary;
              return Container(
                constraints: const BoxConstraints(minHeight: 84),
                padding: const EdgeInsets.symmetric(
                  horizontal: MasliveTokens.xs,
                  vertical: MasliveTokens.s,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      tint.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(MasliveTokens.rM),
                  border: Border.all(color: tint.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(icon, size: 14, color: tint),
                        ),
                        const SizedBox(width: 8),
                        Text(title, style: toolbarSectionStyle),
                      ],
                    ),
                    const SizedBox(height: 10),
                    compact
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: children,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: children,
                          ),
                  ],
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final compactToolbar = constraints.maxWidth < 560;
                final sections = <Widget>[
                  toolbarSection(
                    title: 'Historique',
                    icon: Icons.history_rounded,
                    accent: colorScheme.secondary,
                    compact: compactToolbar,
                    children: [
                      toolbarActionButton(
                        icon: Icons.undo_rounded,
                        tooltip: 'Annuler',
                        onPressed: controller.canUndo ? controller.undo : null,
                        accent: colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      toolbarActionButton(
                        icon: Icons.redo_rounded,
                        tooltip: 'Rétablir',
                        onPressed: controller.canRedo ? controller.redo : null,
                        accent: colorScheme.secondary,
                      ),
                    ],
                  ),
                  if (isPerimeter)
                    toolbarSection(
                      title: 'Forme',
                      icon: Icons.gesture_rounded,
                      accent: MasliveTokens.primary,
                      compact: compactToolbar,
                      children: [
                        if (!_perimeterCircleMode) ...[
                          toolbarActionButton(
                            icon: Icons.loop_rounded,
                            tooltip: 'Fermer le polygone',
                            onPressed: controller.pointCount >= 2
                                ? controller.closePath
                                : null,
                            active: perimeterIsLooped,
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilterChip(
                          label: const Text('Boucle fermée'),
                          labelStyle: toolbarValueStyle,
                          selected: perimeterIsLooped,
                          shape: StadiumBorder(
                            side: BorderSide(color: MasliveTokens.borderSoft),
                          ),
                          side: BorderSide(color: MasliveTokens.borderSoft),
                          selectedColor: MasliveTokens.primary.withValues(
                            alpha: 0.15,
                          ),
                          onSelected:
                              (_perimeterCircleMode ||
                                  controller.pointCount < 2)
                              ? null
                              : (v) {
                                  if (v) {
                                    controller.closePath();
                                  } else {
                                    controller.openPath();
                                  }
                                },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Cercle'),
                          labelStyle: toolbarValueStyle,
                          selected: _perimeterCircleMode,
                          shape: StadiumBorder(
                            side: BorderSide(color: MasliveTokens.borderSoft),
                          ),
                          side: BorderSide(color: MasliveTokens.borderSoft),
                          selectedColor: MasliveTokens.primary.withValues(
                            alpha: 0.15,
                          ),
                          onSelected: (v) {
                            if (v) {
                              if (_perimeterCircleCenter != null) {
                                _applyPerimeterCircle();
                                return;
                              }
                              if (_perimeterPoints.isNotEmpty) {
                                _applyPerimeterCircle(
                                  center: _perimeterPoints.first,
                                );
                                return;
                              }
                              setState(() {
                                _perimeterCircleMode = true;
                                _perimeterPoints = [];
                              });
                              _showTopSnackBar(
                                '🧭 Tape sur la carte pour poser le centre du cercle.',
                              );
                            } else {
                              setState(() {
                                _perimeterCircleMode = false;
                              });
                            }
                          },
                        ),
                        if (_perimeterCircleMode) ...[
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Centre verrouille'),
                            labelStyle: toolbarValueStyle,
                            selected: _perimeterCircleCenterLocked,
                            shape: StadiumBorder(
                              side: BorderSide(color: MasliveTokens.borderSoft),
                            ),
                            side: BorderSide(color: MasliveTokens.borderSoft),
                            selectedColor: MasliveTokens.primary.withValues(
                              alpha: 0.15,
                            ),
                            onSelected: _perimeterCircleCenter == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _perimeterCircleCenterLocked = value;
                                    });
                                  },
                          ),
                          const SizedBox(width: 8),
                          toolbarMetric(
                            label: 'Diamètre',
                            value: _formatMeters(
                              _perimeterCircleDiameterMeters,
                            ),
                            icon: Icons.radio_button_checked,
                          ),
                          const SizedBox(width: 8),
                          toolbarActionButton(
                            icon: Icons.remove_circle_outline,
                            tooltip: 'Réduire diamètre',
                            onPressed: () {
                              final next =
                                  (_perimeterCircleDiameterMeters - 200.0)
                                      .clamp(200.0, 20000.0);
                              if (_perimeterCircleCenter != null) {
                                _applyPerimeterCircle(diameterMeters: next);
                              } else {
                                setState(
                                  () => _perimeterCircleDiameterMeters = next,
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          toolbarActionButton(
                            icon: Icons.add_circle_outline,
                            tooltip: 'Augmenter diamètre',
                            onPressed: () {
                              final next =
                                  (_perimeterCircleDiameterMeters + 200.0)
                                      .clamp(200.0, 20000.0);
                              if (_perimeterCircleCenter != null) {
                                _applyPerimeterCircle(diameterMeters: next);
                              } else {
                                setState(
                                  () => _perimeterCircleDiameterMeters = next,
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  if (isPerimeter)
                    toolbarSection(
                      title: 'Caméra',
                      icon: Icons.videocam_outlined,
                      accent: colorScheme.tertiary,
                      compact: compactToolbar,
                      children: [
                        toolbarMetric(
                          label: 'Init',
                          value: _perimeterCameraInitialZoom.toStringAsFixed(1),
                          icon: Icons.center_focus_strong,
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        toolbarActionButton(
                          icon: Icons.zoom_out,
                          tooltip: 'Zoom initial -',
                          onPressed: () {
                            setState(() {
                              _perimeterCameraInitialZoom =
                                  (_perimeterCameraInitialZoom - 0.5).clamp(
                                    0.0,
                                    22.0,
                                  );
                              _perimeterCameraMaxZoom = _perimeterCameraMaxZoom
                                  .clamp(_perimeterCameraInitialZoom, 22.0);
                              _perimeterCameraPitchZoomThreshold =
                                  _perimeterCameraPitchZoomThreshold.clamp(
                                    0.0,
                                    _perimeterCameraMaxZoom,
                                  );
                            });
                          },
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        toolbarActionButton(
                          icon: Icons.zoom_in,
                          tooltip: 'Zoom initial +',
                          onPressed: () {
                            setState(() {
                              _perimeterCameraInitialZoom =
                                  (_perimeterCameraInitialZoom + 0.5).clamp(
                                    0.0,
                                    22.0,
                                  );
                              _perimeterCameraMaxZoom = _perimeterCameraMaxZoom
                                  .clamp(_perimeterCameraInitialZoom, 22.0);
                              _perimeterCameraPitchZoomThreshold =
                                  _perimeterCameraPitchZoomThreshold.clamp(
                                    0.0,
                                    _perimeterCameraMaxZoom,
                                  );
                            });
                          },
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        toolbarMetric(
                          label: 'Max',
                          value: _perimeterCameraMaxZoom.toStringAsFixed(1),
                          icon: Icons.zoom_in_map,
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        toolbarActionButton(
                          icon: Icons.remove_circle_outline,
                          tooltip: 'Zoom max -',
                          onPressed: () {
                            setState(() {
                              _perimeterCameraMaxZoom =
                                  (_perimeterCameraMaxZoom - 0.5).clamp(
                                    _perimeterCameraInitialZoom,
                                    22.0,
                                  );
                              _perimeterCameraPitchZoomThreshold =
                                  _perimeterCameraPitchZoomThreshold.clamp(
                                    0.0,
                                    _perimeterCameraMaxZoom,
                                  );
                            });
                          },
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        toolbarActionButton(
                          icon: Icons.add_circle_outline,
                          tooltip: 'Zoom max +',
                          onPressed: () {
                            setState(() {
                              _perimeterCameraMaxZoom =
                                  (_perimeterCameraMaxZoom + 0.5).clamp(
                                    _perimeterCameraInitialZoom,
                                    22.0,
                                  );
                              _perimeterCameraPitchZoomThreshold =
                                  _perimeterCameraPitchZoomThreshold.clamp(
                                    0.0,
                                    _perimeterCameraMaxZoom,
                                  );
                            });
                          },
                          accent: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(
                            _perimeterCameraAdvancedExpanded
                                ? 'Perspective ouverte'
                                : 'Perspective avancée',
                          ),
                          selected: _perimeterCameraAdvancedExpanded,
                          labelStyle: toolbarValueStyle,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          side: BorderSide(
                            color: colorScheme.tertiary.withValues(alpha: 0.25),
                          ),
                          selectedColor: colorScheme.tertiary.withValues(
                            alpha: 0.14,
                          ),
                          onSelected: (value) {
                            setState(() {
                              _perimeterCameraAdvancedExpanded = value;
                            });
                          },
                        ),
                        if (_perimeterCameraAdvancedExpanded) ...[
                          const SizedBox(width: 8),
                          toolbarMetric(
                            label: 'Seuil',
                            value: _perimeterCameraPitchZoomThreshold
                                .toStringAsFixed(1),
                            icon: Icons.tune,
                            accent: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          toolbarActionButton(
                            icon: Icons.expand_more,
                            tooltip: 'Seuil tilt -',
                            onPressed: () {
                              setState(() {
                                _perimeterCameraPitchZoomThreshold =
                                    (_perimeterCameraPitchZoomThreshold - 0.5)
                                        .clamp(0.0, _perimeterCameraMaxZoom);
                              });
                            },
                            accent: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          toolbarActionButton(
                            icon: Icons.expand_less,
                            tooltip: 'Seuil tilt +',
                            onPressed: () {
                              setState(() {
                                _perimeterCameraPitchZoomThreshold =
                                    (_perimeterCameraPitchZoomThreshold + 0.5)
                                        .clamp(0.0, _perimeterCameraMaxZoom);
                              });
                            },
                            accent: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          toolbarMetric(
                            label: 'Pitch',
                            value:
                                '${_perimeterCameraPitchDegrees.toStringAsFixed(0)}°',
                            icon: Icons.threed_rotation,
                            accent: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          toolbarActionButton(
                            icon: Icons.remove,
                            tooltip: 'Pitch -',
                            onPressed: () {
                              setState(() {
                                _perimeterCameraPitchDegrees =
                                    (_perimeterCameraPitchDegrees - 5.0).clamp(
                                      0.0,
                                      _perimeterCameraPitchMaxDegrees,
                                    );
                              });
                            },
                            accent: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          toolbarActionButton(
                            icon: Icons.add,
                            tooltip: 'Pitch +',
                            onPressed: () {
                              setState(() {
                                _perimeterCameraPitchDegrees =
                                    (_perimeterCameraPitchDegrees + 5.0).clamp(
                                      0.0,
                                      _perimeterCameraPitchMaxDegrees,
                                    );
                              });
                            },
                            accent: colorScheme.tertiary,
                          ),
                        ],
                      ],
                    ),
                  toolbarSection(
                    title: 'Édition',
                    icon: Icons.auto_fix_high_rounded,
                    accent: Colors.deepPurple,
                    compact: compactToolbar,
                    children: [
                      toolbarActionButton(
                        icon: Icons.flip_to_back,
                        tooltip: 'Inverser sens',
                        onPressed: controller.pointCount >= 2
                            ? controller.reversePath
                            : null,
                        accent: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      toolbarActionButton(
                        icon: Icons.compress_rounded,
                        tooltip: 'Simplifier tracé',
                        onPressed: controller.pointCount >= 3
                            ? controller.simplifyTrack
                            : null,
                        accent: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      toolbarActionButton(
                        icon: Icons.delete_sweep,
                        tooltip: 'Effacer tous',
                        onPressed: controller.pointCount > 0
                            ? controller.clearAll
                            : null,
                        accent: Colors.redAccent,
                      ),
                    ],
                  ),
                  if (isRouteAndStyleStep)
                    toolbarSection(
                      title: 'Trajet',
                      icon: Icons.route_rounded,
                      accent: colorScheme.secondary,
                      compact: compactToolbar,
                      children: [
                        toolbarActionButton(
                          icon: Icons.alt_route_rounded,
                          tooltip: 'Snap sur route (Waze)',
                          onPressed:
                              (!_isSnappingRoute && controller.pointCount >= 2)
                              ? _snapRouteToRoads
                              : null,
                          active: _isSnappingRoute,
                          accent: colorScheme.secondary,
                          child: _isSnappingRoute
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.secondary.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: ToggleButtons(
                            isSelected: [routeIsLooped, !routeIsLooped],
                            borderRadius: BorderRadius.circular(10),
                            constraints: const BoxConstraints(minHeight: 38),
                            onPressed: controller.pointCount >= 2
                                ? (index) {
                                    if (index == 0) {
                                      controller.closePath();
                                    } else {
                                      controller.openPath();
                                    }
                                  }
                                : null,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.loop_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Boucler', style: toolbarValueStyle),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flag_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Arrivée', style: toolbarValueStyle),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  toolbarSection(
                    title: 'Lecture',
                    icon: Icons.analytics_outlined,
                    accent: MasliveTokens.success,
                    compact: compactToolbar,
                    children: [
                      toolbarMetric(
                        label: 'Points',
                        value: '${controller.pointCount}',
                        icon: Icons.scatter_plot_outlined,
                        accent: MasliveTokens.success,
                      ),
                      const SizedBox(width: 8),
                      toolbarMetric(
                        label: 'Distance',
                        value: '${controller.distanceKm.toStringAsFixed(2)} km',
                        icon: Icons.straighten_rounded,
                        accent: MasliveTokens.success,
                      ),
                    ],
                  ),
                  if (isRouteAndStyleStep)
                    toolbarSection(
                      title: 'Style itinéraire',
                      icon: Icons.palette_outlined,
                      accent: colorScheme.primary,
                      compact: compactToolbar,
                      children: [
                        _buildRouteStyleControls(compact: compactToolbar),
                      ],
                    ),
                ];

                if (compactToolbar) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < sections.length; i++) ...[
                          sections[i],
                          if (i < sections.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        sections[i],
                        if (i < sections.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    if (kIsWeb) {
      content = PointerInterceptor(child: content);
    }
    return content;
  }

  Future<void> _snapRouteToRoads() async {
    await _snapRouteToRoadsInternal(
      persist: true,
      showSnackBar: true,
      expectedSeq: null,
    );
  }

  Future<void> _addPointsAndSnapRoute() async {
    if (_isSnappingRoute || _routePoints.length < 2) return;

    final densified = _densifyRoutePoints(
      _routePoints,
      maxSegmentMeters: 45.0,
    );
    final addedCount = densified.length - _routePoints.length;

    if (addedCount > 0) {
      setState(() {
        _routePoints = densified;
      });
    }

    await _snapRouteToRoadsInternal(
      persist: true,
      showSnackBar: false,
      expectedSeq: null,
    );

    if (!mounted) return;
    _showTopSnackBar(
      '✅ Points ajoutés: +$addedCount, tracé recalé sur la route.',
    );
  }

  List<LngLat> _densifyRoutePoints(
    List<LngLat> input, {
    required double maxSegmentMeters,
  }) {
    if (input.length < 2) return input;
    final out = <LngLat>[];

    for (var i = 0; i < input.length - 1; i++) {
      final start = input[i];
      final end = input[i + 1];
      out.add(start);

      final distance = _parkingZoneDistanceMeters(start, end);
      final inserts = math.max(
        0,
        (distance / maxSegmentMeters).ceil() - 1,
      );

      for (var j = 1; j <= inserts; j++) {
        final t = j / (inserts + 1);
        out.add(
          (
            lng: start.lng + (end.lng - start.lng) * t,
            lat: start.lat + (end.lat - start.lat) * t,
          ),
        );
      }
    }

    out.add(input.last);
    return out;
  }

  void _scheduleContinuousRouteSnap() {
    if (_routePoints.length < 2) return;

    _routeSnapDebounce?.cancel();
    final seq = ++_routeSnapSeq;
    _routeSnapDebounce = Timer(const Duration(milliseconds: 650), () {
      _attemptContinuousRouteSnap(seq);
    });
  }

  void _attemptContinuousRouteSnap(int seq) {
    if (!mounted) return;
    if (seq != _routeSnapSeq) return;

    // Si un snap est en cours, on retente un peu plus tard.
    if (_isSnappingRoute) {
      _routeSnapDebounce?.cancel();
      _routeSnapDebounce = Timer(const Duration(milliseconds: 350), () {
        _attemptContinuousRouteSnap(seq);
      });
      return;
    }

    // Mode silencieux + sans persistance: évite de spammer Firestore.
    _snapRouteToRoadsInternal(
      persist: false,
      showSnackBar: false,
      expectedSeq: seq,
    );
  }

  Future<void> _snapRouteToRoadsInternal({
    required bool persist,
    required bool showSnackBar,
    required int? expectedSeq,
  }) async {
    if (_routePoints.length < 2) return;
    if (_isSnappingRoute) return;

    // Anti-stale: on invalide les snaps en cours si une nouvelle édition arrive.
    final seq = expectedSeq ?? ++_routeSnapSeq;

    setState(() => _isSnappingRoute = true);
    try {
      final service = snap.RouteSnapService();
      final input = <rsp.LatLng>[
        for (final p in _routePoints) (lat: p.lat, lng: p.lng),
      ];

      final snapped = await service.snapToRoad(
        input,
        options: const snap.SnapOptions(
          toleranceMeters: 35.0,
          simplifyPercent: 0.0,
        ),
      );

      if (!mounted) return;
      if (seq != _routeSnapSeq) return;

      final output = <LngLat>[
        for (final p in snapped.points) (lng: p.lng, lat: p.lat),
      ];

      setState(() {
        _routePoints = output;
      });

      if (showSnackBar) {
        _showTopSnackBar(
          '✅ Tracé aligné sur la route (${output.length} points)',
        );
      }

      if (persist && _projectId != null) {
        await _saveDraft(ensureRouteSnapped: false);
      }
    } catch (e) {
      debugPrint('WizardPro _snapRouteToRoadsInternal error: $e');
      if (!mounted) return;
      if (seq != _routeSnapSeq) return;
      if (showSnackBar) {
        _showTopSnackBar(
          '❌ Snap impossible: $e',
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => _isSnappingRoute = false);
    }
  }

  Widget _buildRouteStyleControls({bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final toolLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: MasliveTokens.textSoft,
    );
    final colors = <String, String>{
      '#1A73E8': 'Bleu',
      '#34A853': 'Vert',
      '#EF4444': 'Rouge',
      '#F59E0B': 'Orange',
    };
    const proBlue = Color(0xFF1A73E8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 520.0;
        final sliderWidth = compact
            ? (availableWidth < 236
                  ? availableWidth
                  : (availableWidth > 320 ? 320.0 : availableWidth))
            : 244.0;
        final speedWidth = compact
            ? (availableWidth < 236
                  ? availableWidth
                  : (availableWidth > 340 ? 340.0 : availableWidth))
            : 260.0;

        return Wrap(
          spacing: compact ? 8 : 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Couleur du tracé',
              initialValue: _routeColorHex,
              onSelected: (hex) {
                setState(() => _routeColorHex = hex);
              },
              itemBuilder: (context) => [
                for (final e in colors.entries)
                  PopupMenuItem<String>(
                    value: e.key,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _parseHexColor(e.key, fallback: Colors.blue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(e.value),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.color_lens, color: colorScheme.onSurface),
                    const SizedBox(width: 6),
                    Text('Couleur', style: toolLabelStyle),
                    const SizedBox(width: 6),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _parseHexColor(
                          _routeColorHex,
                          fallback: colorScheme.primary,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: sliderWidth,
              child: _buildCompactToolbarAdjuster(
                label: 'Largeur',
                value: _routeWidth,
                min: 2.0,
                max: 18.0,
                divisions: 16,
                displayValue: _routeWidth.toStringAsFixed(0),
                labelStyle: toolLabelStyle,
                onChanged: (v) {
                  setState(() => _routeWidth = v);
                },
              ),
            ),
            IconButton(
              tooltip: 'Itinéraire routier',
              onPressed: () => setState(() => _routeRoadLike = !_routeRoadLike),
              icon: Icon(
                Icons.route,
                color: _routeRoadLike ? proBlue : colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _routeShowDirection
                    ? proBlue.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _routeShowDirection
                      ? proBlue.withValues(alpha: 0.35)
                      : colorScheme.outline.withValues(alpha: 0.50),
                ),
              ),
              child: IconButton(
                tooltip: 'Sens (flèches)',
                onPressed: () {
                  setState(() {
                    _routeShowDirection = !_routeShowDirection;
                    if (!_routeShowDirection) {
                      _routeAnimateDirection = false;
                    }
                  });
                },
                icon: Icon(
                  Icons.navigation,
                  color: _routeShowDirection
                      ? proBlue
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilterChip(
              label: Text(
                _routeStyleAdvancedExpanded
                    ? 'Style avancé ouvert'
                    : 'Style avancé',
                style: toolLabelStyle,
              ),
              selected: _routeStyleAdvancedExpanded,
              shape: StadiumBorder(
                side: BorderSide(color: proBlue.withValues(alpha: 0.24)),
              ),
              side: BorderSide(color: proBlue.withValues(alpha: 0.24)),
              selectedColor: proBlue.withValues(alpha: 0.12),
              onSelected: (value) {
                setState(() {
                  _routeStyleAdvancedExpanded = value;
                });
              },
            ),
            if (_routeStyleAdvancedExpanded)
              IconButton(
                tooltip: 'Ombre 3D',
                onPressed: _routeRoadLike
                    ? () => setState(() => _routeShadow3d = !_routeShadow3d)
                    : null,
                icon: Icon(
                  Icons.layers,
                  color: (_routeRoadLike && _routeShadow3d)
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            if (_routeStyleAdvancedExpanded)
              IconButton(
                tooltip: 'Animation sens de marche',
                onPressed: _routeShowDirection
                    ? () => setState(
                        () => _routeAnimateDirection = !_routeAnimateDirection,
                      )
                    : null,
                icon: Icon(
                  _routeAnimateDirection
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: _routeAnimateDirection
                      ? proBlue
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            if (_routeStyleAdvancedExpanded && _routeAnimateDirection)
              SizedBox(
                width: speedWidth,
                child: _buildCompactToolbarAdjuster(
                  label: 'Vitesse',
                  value: _routeAnimationSpeed,
                  min: 0.5,
                  max: 5.0,
                  divisions: 9,
                  displayValue: _routeAnimationSpeed.toStringAsFixed(1),
                  labelStyle: toolLabelStyle,
                  onChanged: (v) {
                    setState(() => _routeAnimationSpeed = v);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStep6StylePro() {
    final media = MediaQuery.sizeOf(context);
    final styleProViewportHeight = (media.height - 220).clamp(760.0, 1180.0);

    return GlassScrollbar(
      controller: _styleProStepScrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: SingleChildScrollView(
        controller: _styleProStepScrollController,
        padding: const EdgeInsets.fromLTRB(
          _wizardStepHorizontalPadding,
          0,
          _wizardStepHorizontalPadding,
          kBottomNavigationBarHeight + MasliveTokens.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWizardScrollableHeader(
              padding: const EdgeInsets.only(left: _wizardStepHorizontalPadding),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: (!_isSnappingRoute && _routePoints.length >= 2)
                    ? _addPointsAndSnapRoute
                    : null,
                icon: _isSnappingRoute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_road_rounded),
                label: const Text('Ajouter des points'),
              ),
            ),
            const SizedBox(height: MasliveTokens.s),
            SizedBox(
              height: styleProViewportHeight,
              child: RouteStyleWizardProPage(
                embedded: true,
                controller: _routeStyleProController,
                projectId: _projectId,
                circuitId: widget.circuitId,
                initialStyleUrl:
                    _normalizeMapboxStyleUrl(
                      _styleUrlController.text,
                    ).trim().isEmpty
                    ? null
                    : _normalizeMapboxStyleUrl(_styleUrlController.text).trim(),
                initialRoute: _routePoints.isNotEmpty
                    ? <rsp.LatLng>[
                        for (final p in _routePoints) (lat: p.lat, lng: p.lng),
                      ]
                    : null,
                embeddedPreviewHeight: _embeddedStyleProPreviewHeight(context),
                onConfigChanged: (cfg) {
                  _routeStyleProConfig = cfg.validated();
                  if (_currentStep == _poiStepIndex) {
                    unawaited(_refreshPoiRouteOverlay());
                  }
                  _syncPoiRouteStyleProTimer();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String hex, {required Color fallback}) {
    final h = hex.trim();
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(h);
    if (m == null) return fallback;
    final rgb = int.parse(m.group(1)!, radix: 16);
    return Color(0xFF000000 | rgb);
  }

  String _colorToHex(Color color) {
    final r = color.r.round().toRadixString(16).padLeft(2, '0');
    final g = color.g.round().toRadixString(16).padLeft(2, '0');
    final b = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  String _applyParkingColorSaturationToHex(String hex, double factor) {
    final color = _parseHexColor(hex, fallback: Colors.black);
    final hsv = HSVColor.fromColor(color);
    final adjusted = hsv.withSaturation(
      (hsv.saturation * factor.clamp(0.0, 1.0)).clamp(0.0, 1.0),
    );
    return _colorToHex(adjusted.toColor());
  }

  Widget _buildStep5POI() {
    _ensurePoiInitialCamera();
    const poiStepHorizontalPadding = _wizardStepHorizontalPadding;
    final compactPoiLayout = MediaQuery.sizeOf(context).width < 520;

    Widget buildPoiToolsPanel({required List<MarketMapLayer> poiLayers}) {
      final parkingLayerSelected = _selectedLayer?.type == 'parking';
      final parkingDrawingActive =
          parkingLayerSelected &&
          (_isDrawingParkingZone || _isEditingParkingZonePerimeter);
      final canFinishParkingZone = _parkingZonePoints.length >= 3;

      const panelTitleStyle = TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: MasliveTokens.text,
      );
      const panelValueStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MasliveTokens.text,
      );
      final panelHintStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MasliveTokens.textSoft,
      );

      Widget buildParkingWorkflowCard() {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(MasliveTokens.rL),
            border: Border.all(color: MasliveTokens.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_parking_rounded,
                    color: MasliveTokens.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Zone parking', style: panelTitleStyle),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: parkingDrawingActive
                          ? MasliveTokens.primary.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: parkingDrawingActive
                            ? MasliveTokens.primary.withValues(alpha: 0.28)
                            : MasliveTokens.borderSoft,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        parkingDrawingActive ? 'Dessin actif' : 'Prêt',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: parkingDrawingActive
                              ? MasliveTokens.primary
                              : MasliveTokens.textSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                parkingDrawingActive
                    ? 'Touchez la carte pour poser les sommets de la zone. Il faut au moins 3 points pour créer le parking.'
                    : 'Créez une zone parking polygonale directement sur la carte, puis ajustez son apparence et ses pictogrammes.',
                style: panelHintStyle,
              ),
              const SizedBox(height: 12),
              if (parkingDrawingActive) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.timeline_rounded, size: 16),
                      label: Text('${_parkingZonePoints.length} points'),
                    ),
                    Chip(
                      avatar: Icon(
                        canFinishParkingZone
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: canFinishParkingZone
                            ? Colors.green
                            : MasliveTokens.textSoft,
                      ),
                      label: Text(
                        canFinishParkingZone
                            ? 'Zone prête'
                            : 'Minimum 3 points',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _parkingZonePoints.isEmpty
                          ? null
                          : _removeLastParkingZonePoint,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Retirer le dernier point'),
                    ),
                    TextButton(
                      onPressed: _cancelParkingZoneDrawing,
                      child: const Text('Annuler'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canFinishParkingZone
                          ? _finishParkingZoneDrawing
                          : null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Créer la zone'),
                    ),
                  ],
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: (_pois.length >= _poiLimit)
                        ? null
                        : _startParkingZoneDrawing,
                    icon: const Icon(Icons.crop_square_rounded, size: 18),
                    label: const Text('Démarrer une zone parking'),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      IconButton toolButton({
        required Widget icon,
        required String tooltip,
        required VoidCallback? onPressed,
      }) {
        return IconButton.filledTonal(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: icon,
          style: IconButton.styleFrom(
            foregroundColor: MasliveTokens.text,
            backgroundColor: Colors.white.withValues(alpha: 0.74),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.34),
            disabledForegroundColor: MasliveTokens.textSoft.withValues(
              alpha: 0.5,
            ),
          ),
        );
      }

      return GlassPanel(
        radius: MasliveTokens.rL,
        opacity: 0.90,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: MasliveTokens.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Points d\'intérêt (POI)',
                    style: panelTitleStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                toolButton(
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  tooltip: 'Ajouter un POI (coordonnées manuelles)',
                  onPressed:
                      (_selectedLayer == null ||
                          _pois.length >= _poiLimit ||
                          parkingDrawingActive)
                      ? null
                      : () {
                          double lng;
                          double lat;
                          if (_routePoints.isNotEmpty) {
                            lng = _routePoints.first.lng;
                            lat = _routePoints.first.lat;
                          } else if (_perimeterPoints.isNotEmpty) {
                            lng = _perimeterPoints.first.lng;
                            lat = _perimeterPoints.first.lat;
                          } else {
                            lng = -61.533;
                            lat = 16.241;
                          }

                          unawaited(_createPoiAt(lng: lng, lat: lat));
                        },
                ),
                toolButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Ajouter un POI à la position actuelle',
                  onPressed:
                      (_selectedLayer == null ||
                          _pois.length >= _poiLimit ||
                          parkingDrawingActive)
                      ? null
                      : _addPoiAtCurrentCenter,
                ),
                if (parkingLayerSelected)
                  toolButton(
                    icon: Icon(
                      parkingDrawingActive
                          ? Icons.crop_square
                          : Icons.crop_square_rounded,
                    ),
                    tooltip: parkingDrawingActive
                        ? 'Mode zone parking (en cours)'
                        : 'Créer une zone parking (périmètre)',
                    onPressed: (_pois.length >= _poiLimit)
                        ? null
                        : () {
                            if (parkingDrawingActive) {
                              if (_isEditingParkingZonePerimeter) {
                                _cancelParkingZonePerimeterEditing();
                              } else {
                                _cancelParkingZoneDrawing();
                              }
                            } else {
                              _startParkingZoneDrawing();
                            }
                          },
                  ),
                toolButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Enregistrer les POI',
                  onPressed: _isLoading ? null : _saveDraft,
                ),
                toolButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Réimporter POI/couches depuis MarketMap',
                  onPressed: (_isLoading || _isRefreshingMarketImport)
                      ? null
                      : _refreshImportFromMarketMap,
                ),
              ],
            ),
            if (parkingLayerSelected) ...[
              const SizedBox(height: 12),
              buildParkingWorkflowCard(),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'POI: ${_pois.length}/$_poiLimit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _pois.length >= _poiLimit
                        ? Colors.redAccent
                        : (_pois.length >= (_poiLimit * 0.9)
                              ? Colors.orange
                              : MasliveTokens.text),
                  ),
                ),
                const SizedBox(width: 8),
                if (_hasMorePois || _isLoadingMorePois)
                  TextButton.icon(
                    onPressed: _isLoadingMorePois ? null : _loadMorePoisPage,
                    icon: _isLoadingMorePois
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more, size: 16),
                    label: const Text('Charger +100'),
                  ),
              ],
            ),
            if (_pois.length >= _poiLimit)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Limite atteinte: supprime des POI pour continuer.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Apparence (nouveau POI)',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _defaultPoiAppearanceId,
                  isExpanded: true,
                  items: [
                    for (final p in kMasLivePoiAppearancePresets)
                      DropdownMenuItem(
                        value: p.id,
                        child: buildMasLivePoiAppearanceMenuItem(p),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _defaultPoiAppearanceId = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (poiLayers.isNotEmpty)
              Row(
                children: [
                  const Text('Catégorie: ', style: panelValueStyle),
                  Expanded(
                    child: Text(
                      _selectedLayer?.label ?? 'Choisissez une catégorie',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: panelHintStyle,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Aucune couche trouvée. Vérifiez la configuration du projet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            if (_selectedLayer != null) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                title: Text(
                  'POI de la couche: ${_selectedLayer!.label}',
                  style: panelValueStyle,
                ),
                subtitle: Text(
                  '${_pois.where((p) => _poiMatchesSelectedLayer(p, _selectedLayer!)).length} POI',
                  style: panelHintStyle,
                ),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final poi in _pois.where(
                          (p) => _poiMatchesSelectedLayer(p, _selectedLayer!),
                        ))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  MasliveTokens.rS,
                                ),
                                onTap: () => _poiSelection.select(poi),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: compactPoiLayout
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  child: Icon(
                                                    Icons.place_outlined,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        poi.name,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: MasliveTokens
                                                              .text,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${poi.lng.toStringAsFixed(5)}, ${poi.lat.toStringAsFixed(5)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: MasliveTokens
                                                              .textSoft,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 26,
                                              ),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () =>
                                                        _editPoi(poi),
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Modifier',
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: () =>
                                                        _deletePoi(poi),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Supprimer',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            const Icon(
                                              Icons.place_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    poi.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: MasliveTokens.text,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${poi.lng.toStringAsFixed(5)}, ${poi.lat.toStringAsFixed(5)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: MasliveTokens
                                                          .textSoft,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Modifier',
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              onPressed: () => _editPoi(poi),
                                            ),
                                            IconButton(
                                              tooltip: 'Supprimer',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                              ),
                                              onPressed: () => _deletePoi(poi),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_hasMorePois || _isLoadingMorePois)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isLoadingMorePois
                            ? null
                            : _loadMorePoisPage,
                        icon: _isLoadingMorePois
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.more_horiz),
                        label: const Text('Voir plus'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget interceptPointersIfNeeded(Widget child) {
      // Sur Flutter web + HtmlElementView (Mapbox), des clics peuvent traverser
      // certains overlays et déclencher le onTap de la carte en arrière-plan.
      if (!kIsWeb) return child;
      return PointerInterceptor(child: child);
    }

    final poiLayers = _layers.where((l) => l.type != 'route').toList();

    final mapViewportHeight = _expandedWizardPoiMapHeight(context);

    return ChangeNotifierProvider<PoiSelectionController>.value(
      value: _poiSelection,
      child: GlassScrollbar(
        controller: _poiStepScrollController,
        scrollbarOrientation: ScrollbarOrientation.left,
        child: SingleChildScrollView(
          controller: _poiStepScrollController,
          physics: _isWizardMapInteracting
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.fromLTRB(
            poiStepHorizontalPadding,
            0,
            poiStepHorizontalPadding,
            kBottomNavigationBarHeight + MasliveTokens.xl,
          ),
          child: Column(
            children: [
              _buildWizardScrollableHeader(
                padding: const EdgeInsets.only(bottom: MasliveTokens.m),
              ),
              SizedBox(
                height: mapViewportHeight,
                child: Stack(
                  children: [
                    _wrapWizardMapToBlockScroll(
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MasliveTokens.rXL),
                        child: MasLiveMap(
                          controller: _poiMapController,
                          initialLng: _poiInitialLng ?? -61.533,
                          initialLat: _poiInitialLat ?? 16.241,
                          initialZoom: _poiInitialZoom ?? 12.0,
                          styleUrl:
                              _normalizeMapboxStyleUrl(
                                _styleUrlController.text,
                              ).isEmpty
                              ? null
                              : _normalizeMapboxStyleUrl(
                                  _styleUrlController.text,
                                ),
                          onMapReady: (ctrl) async {
                            final cfg = _routeStyleProConfig?.validated();
                            if (cfg != null) {
                              await ctrl.setBuildings3d(
                                enabled: cfg.buildings3dEnabled,
                                opacity: cfg.buildingOpacity,
                              );
                            }

                            // Restrictions périmètre (après l'étape "Périmètre")
                            // - empêche de pan en dehors du périmètre
                            // - applique le zoom max configuré
                            final perim = _perimeterPoints;
                            final isClosed =
                                perim.length >= 3 && perim.first == perim.last;
                            if (isClosed) {
                              var west = perim.first.lng;
                              var east = perim.first.lng;
                              var south = perim.first.lat;
                              var north = perim.first.lat;
                              for (final p in perim) {
                                if (p.lng < west) west = p.lng;
                                if (p.lng > east) east = p.lng;
                                if (p.lat < south) south = p.lat;
                                if (p.lat > north) north = p.lat;
                              }
                              await ctrl.setZoomRange(
                                maxZoom: _perimeterCameraMaxZoom,
                              );
                              await ctrl.setMaxBounds(
                                west: west,
                                south: south,
                                east: east,
                                north: north,
                              );
                            } else {
                              await ctrl.setZoomRange(
                                maxZoom: _perimeterCameraMaxZoom,
                              );
                              await ctrl.setMaxBounds();
                            }

                            await _refreshPoiMarkers();
                            await _refreshPoiRouteOverlay();
                            _syncPoiRouteStyleProTimer();
                          },
                        ),
                      ),
                    ),

                    if (poiLayers.isNotEmpty)
                      Align(
                        alignment: Alignment.topRight,
                        child: interceptPointersIfNeeded(
                          HomeVerticalNavMenu(
                            margin: const EdgeInsets.only(right: 12, top: 12),
                            horizontalPadding: 6,
                            verticalPadding: 10,
                            items: [
                              for (final layer in poiLayers)
                                (() {
                                  final v = _poiNavVisualForLayerType(
                                    layer.type,
                                  );
                                  return HomeVerticalNavItem(
                                    label: layer.label,
                                    icon: v.icon,
                                    iconWidget: v.iconWidget,
                                    fullBleed: v.fullBleed,
                                    tintOnSelected: v.tintOnSelected,
                                    showBorder: v.showBorder,
                                    selected:
                                        _selectedLayer?.type == layer.type,
                                    onTap: () {
                                      _poiSelection.clear();
                                      setState(() {
                                        _isDrawingParkingZone = false;
                                        _isEditingParkingZonePerimeter = false;
                                        _parkingZonePoints = <LngLat>[];
                                        _poiInlineEditorMode =
                                            _PoiInlineEditorMode.none;
                                        _poiEditingPoi = null;
                                        _poiInlineError = null;
                                        _selectedLayer = layer;
                                      });
                                      _refreshPoiMarkers();
                                    },
                                  );
                                })(),
                            ],
                          ),
                        ),
                      ),

                    // Fin Stack carte
                  ],
                ),
              ),
              const SizedBox(height: 12),
              buildPoiToolsPanel(poiLayers: poiLayers),

              Consumer<PoiSelectionController>(
                builder: (context, selection, _) {
                  final selected = selection.selectedPoi;
                  if (_poiInlineEditorMode != _PoiInlineEditorMode.none) {
                    return _buildPoiInlineEditorSection();
                  }

                  return PoiInlinePopup(
                    selectedPoi: selected,
                    onClose: selection.clear,
                    onEdit: selected == null ? () {} : () => _editPoi(selected),
                    onDelete: selected == null
                        ? () {}
                        : () => _deletePoi(selected),
                    categoryLabel: (poi) {
                      final match = _layers
                          .where((l) => l.type == poi.layerType)
                          .toList();
                      return match.isNotEmpty
                          ? match.first.label
                          : poi.layerType;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Gestion POI (étape 4) ======

  void _scrollPoiBottomSectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_poiStepScrollController.hasClients) return;
      _poiStepScrollController.animateTo(
        _poiStepScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _openPoiCreateZoneSection({required List<LngLat> perimeterPoints}) {
    _poiSelection.clear();

    setState(() {
      _poiInlineEditorMode = _PoiInlineEditorMode.createZone;
      _poiEditingPoi = null;
      _poiInlineError = null;
      _poiInlineNameController.text = '';
      _parkingZoneVehicleTypes = <String>{'car', 'moto'};

      _parkingZoneFillColorHex = _parkingZoneDefaultFillHex;
      _parkingZoneStrokeColorHex = _parkingZoneDefaultStrokeHex;
      _parkingZoneStrokeFollowsFill = false;
      _parkingZoneColorSaturation = _parkingZoneDefaultColorSaturation;
      _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneLabelPreset = _parkingZoneLabelPresetWideBlue;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = _parkingZoneDefaultFillHex;
      _parkingZoneStrokeColorController.text = _parkingZoneDefaultStrokeHex;

      // Pour une zone, lat/lng servent de centre (centroid approx.)
      final centroid = _centroidOf(perimeterPoints);
      _poiInlineLatController.text = centroid.lat.toStringAsFixed(6);
      _poiInlineLngController.text = centroid.lng.toStringAsFixed(6);
    });
    _scrollPoiBottomSectionIntoView();
  }

  void _openPoiEditSection(MarketMapPOI poi) {
    _poiSelection.select(poi);

    final perimeter = _poiPerimeterFromMetadata(poi);
    final isZone = perimeter != null;
    final style = isZone ? _parkingZoneRawStyleFromMetadata(poi) : null;

    setState(() {
      _isEditingParkingZonePerimeter = false;
      _parkingZonePoints = <LngLat>[];
      _poiInlineEditorMode = _PoiInlineEditorMode.edit;
      _poiEditingPoi = poi;
      _poiInlineError = null;
      _poiInlineAppearanceId =
          normalizeMasLivePoiAppearanceId(
                (poi.metadata?[kMasLivePoiAppearanceKey] as String?),
              ).isNotEmpty
          ? normalizeMasLivePoiAppearanceId(
              (poi.metadata?[kMasLivePoiAppearanceKey] as String?),
            )
          : _defaultPoiAppearanceId;
      _poiInlineNameController.text = poi.name;
      _poiInlineLatController.text = poi.lat.toStringAsFixed(6);
      _poiInlineLngController.text = poi.lng.toStringAsFixed(6);

      if (style != null) {
        _parkingZoneVehicleTypes = _parkingZoneVehicleTypesFromMetadata(poi);
        _parkingZoneFillColorHex =
            style['fillColor'] as String? ??
            _normalizeColorHex(_selectedLayer?.color) ??
            _defaultLayerColorHex(poi.layerType) ??
            _parkingZoneFillColorHex;
        _parkingZoneStrokeColorHex =
            style['strokeColor'] as String? ?? _parkingZoneFillColorHex;
        _parkingZoneStrokeFollowsFill =
            _parkingZoneStrokeColorHex.toUpperCase() ==
            _parkingZoneFillColorHex.toUpperCase();
        _parkingZoneColorSaturation =
            (style['colorSaturation'] as num?)?.toDouble() ??
            _parkingZoneDefaultColorSaturation;
        _parkingZoneFillOpacity =
            (style['fillOpacity'] as num?)?.toDouble() ??
            _parkingZoneFillOpacity;
        _parkingZoneStrokeWidth =
            (style['strokeWidth'] as num?)?.toDouble() ??
            _parkingZoneStrokeWidth;
        _parkingZoneLabelPreset = _parkingZoneLabelPresetFromStyle(style);
        _parkingZoneStrokeDash =
            (style['strokeDash'] as String?)?.trim().isNotEmpty == true
            ? (style['strokeDash'] as String).trim()
            : _parkingZoneStrokeDash;
        _parkingZonePattern =
            (style['pattern'] as String?)?.trim().isNotEmpty == true
            ? (style['pattern'] as String).trim()
            : _parkingZonePattern;
        _parkingZonePatternOpacity =
            (style['patternOpacity'] as num?)?.toDouble() ??
            _parkingZonePatternOpacity;
        _parkingZoneColorController.text = _parkingZoneFillColorHex;
        _parkingZoneStrokeColorController.text = _parkingZoneStrokeColorHex;
      }
    });
    _scrollPoiBottomSectionIntoView();
  }

  void _closePoiInlineEditor({bool keepSelection = true}) {
    setState(() {
      _isEditingParkingZonePerimeter = false;
      _parkingZonePoints = <LngLat>[];
      _poiInlineEditorMode = _PoiInlineEditorMode.none;
      _poiEditingPoi = null;
      _poiInlineError = null;
    });
    if (!keepSelection) {
      _poiSelection.clear();
    }
  }

  Future<void> _createPoiAt({required double lng, required double lat}) async {
    if (_selectedLayer == null) return;
    if (_pois.length >= _poiLimit) {
      if (mounted) {
        _showTopSnackBar(
          '❌ Limite atteinte: 2000 POI maximum par projet',
          isError: true,
        );
      }
      return;
    }

    // Unifier avec la page POI: création d'un point via le même popup complet.
    final layerType = _selectedLayer!.type;
    final provisional = MarketMapPOI(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      layerType: layerType,
      layerId: layerType,
      lng: lng,
      lat: lat,
      metadata: <String, dynamic>{
        kMasLivePoiAppearanceKey: _defaultPoiAppearanceId,
      },
    );

    final created = await showModalBottomSheet<MarketMapPOI>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PoiEditPopup(
        poi: provisional,
        projectId: _projectId,
        appearancePresets: kMasLivePoiAppearancePresets,
      ),
    );
    if (created == null) return;

    setState(() {
      _pois.add(created);
    });
    _poiSelection.select(created);
    _refreshPoiMarkers();
    await _persistPoiDraftUpdate(created);
  }

  Future<void> _refreshPoiMarkers() async {
    if (_selectedLayer == null) {
      await _poiMapController.clearPoisGeoJson();
      return;
    }

    final layer = _selectedLayer!;
    final poisForLayer = _pois
        .where(
          (p) =>
              _poiMatchesSelectedLayer(p, layer) &&
              !(_isEditingParkingZonePerimeter && _poiEditingPoi?.id == p.id),
        )
        .toList();

    final previewParkingZonePoints =
        ((_isDrawingParkingZone || _isEditingParkingZonePerimeter) &&
            layer.type == 'parking' &&
            _parkingZonePoints.isNotEmpty)
        ? _parkingZonePoints
        : null;

    await _poiMapController.setPoisGeoJson(
      _buildPoisFeatureCollection(
        poisForLayer,
        previewParkingZonePoints: previewParkingZonePoints,
      ),
    );
  }

  void _syncPoiRouteStyleProTimer() {
    final cfg = _routeStyleProConfig;
    final needsAnim =
        mounted &&
        _currentStep == _poiStepIndex &&
        cfg != null &&
        (cfg.rainbowEnabled || cfg.effectiveCasingRainbowEnabled);

    if (!needsAnim) {
      _poiRouteStyleProTimer?.cancel();
      _poiRouteStyleProTimer = null;
      return;
    }

    // Période similaire à la preview map (throttlée)
    final periodMs = (110 - (cfg.rainbowSpeed * 0.8)).clamp(25, 110).round();

    _poiRouteStyleProTimer?.cancel();
    _poiRouteStyleProTimer = Timer.periodic(Duration(milliseconds: periodMs), (
      _,
    ) {
      if (!mounted) return;
      if (_currentStep != _poiStepIndex) {
        _syncPoiRouteStyleProTimer();
        return;
      }
      _poiRouteStyleProAnimTick++;
      unawaited(_refreshPoiRouteOverlay(animTick: _poiRouteStyleProAnimTick));
    });
  }

  Future<void> _refreshPoiRouteOverlay({int? animTick}) async {
    if (!mounted) return;
    if (_currentStep != _poiStepIndex) return;
    if (_isRenderingPoiRoute) return;
    _isRenderingPoiRoute = true;

    try {
      final route = _routePoints;
      if (route.length < 2) {
        await _poiMapController.setPolyline(points: const [], show: false);
        return;
      }

      final mapPoints = <MapPoint>[
        for (final p in route) MapPoint(p.lng, p.lat),
      ];

      final pro = _routeStyleProConfig;
      if (pro != null) {
        final cfg = pro.validated();

        final buildingsKey =
            '${cfg.buildings3dEnabled ? 1 : 0}:${cfg.buildingOpacity.toStringAsFixed(3)}';
        if (_lastPoiBuildingsKey != buildingsKey) {
          _lastPoiBuildingsKey = buildingsKey;
          unawaited(
            _poiMapController.setBuildings3d(
              enabled: cfg.buildings3dEnabled,
              opacity: cfg.buildingOpacity,
            ),
          );
        }

        final mainWidth = cfg.effectiveRenderedMainWidth;
        final casingWidth = cfg.effectiveRenderedCasingWidth;
        final glowWidth = cfg.glowWidth * cfg.effectiveWidthScale3d;

        final segmentsForMain =
            cfg.rainbowEnabled ||
            cfg.trafficDemoEnabled ||
            cfg.vanishingEnabled;
        final needSegmentsSource =
            segmentsForMain || cfg.effectiveCasingRainbowEnabled;
        final segmentsGeoJson = needSegmentsSource
            ? _buildRouteStyleProSegmentsGeoJson(
                route,
                cfg,
                animTick: animTick ?? _poiRouteStyleProAnimTick,
              )
            : null;

        final shouldRoadLike = cfg.shouldRenderRoadLike;

        await _poiMapController.setPolyline(
          points: mapPoints,
          color: cfg.mainColor,
          width: mainWidth,
          show: true,
          roadLike: shouldRoadLike,
          shadow3d: cfg.effectiveShadowEnabled,
          shadowOpacity: cfg.shadowOpacity,
          shadowBlur: cfg.shadowBlur,
          showDirection: false,
          animateDirection: cfg.pulseEnabled,
          animationSpeed: (cfg.pulseSpeed / 25.0).clamp(0.5, 5.0),

          opacity: cfg.opacity,
          casingColor: cfg.casingColor,
          casingWidth: cfg.effectiveCasingWidth > 0 ? casingWidth : null,
          casingRainbowEnabled: cfg.effectiveCasingRainbowEnabled,

          glowEnabled: cfg.effectiveGlowEnabled,
          glowColor: cfg.mainColor,
          glowWidth: glowWidth,
          glowOpacity: cfg.effectiveGlowEnabled ? cfg.glowOpacity : 0.0,
          glowBlur: cfg.glowBlur,

          thickness3d: cfg.thickness3d,
          elevationPx: cfg.effectiveElevationPx,
          sidesEnabled: cfg.effectiveSidesEnabled,
          sidesIntensity: cfg.sidesIntensity,

          dashArray: cfg.dashEnabled
              ? <double>[cfg.dashLength, cfg.dashGap]
              : null,
          lineCap: cfg.lineCap.name,
          lineJoin: cfg.lineJoin.name,
          segmentsGeoJson: segmentsGeoJson,
          segmentsForMain: segmentsForMain,
        );
        return;
      }

      // Fallback: style legacy (Waze-like)
      await _poiMapController.setPolyline(
        points: mapPoints,
        color: _parseHexColor(_routeColorHex, fallback: Colors.blue),
        width: _routeWidth,
        show: true,
        roadLike: _routeRoadLike,
        shadow3d: _routeShadow3d,
        showDirection: _routeShowDirection,
        animateDirection: _routeAnimateDirection,
        animationSpeed: _routeAnimationSpeed,
      );
    } catch (_) {
      // Garder l'étape POI stable même si interop map KO.
    } finally {
      _isRenderingPoiRoute = false;
    }
  }

  String _emptyFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  String _featureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({'type': 'FeatureCollection', 'features': features});

  String _buildRouteStyleProSegmentsGeoJson(
    List<LngLat> pts,
    rsp.RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) return _emptyFeatureCollection();

    final width = cfg.effectiveRenderedMainWidth;

    // Limite le nombre de segments (perf)
    const maxSeg = 60;
    final step = math.max(1, ((pts.length - 1) / maxSeg).ceil());

    final features = <Map<String, dynamic>>[];
    int segIndex = 0;

    for (int i = 0; i < pts.length - 1; i += step) {
      final a = pts[i];
      final b = pts[math.min(i + step, pts.length - 1)];

      final t = segIndex / math.max(1, ((pts.length - 1) / step).floor());

      final baseOpacity = cfg.opacity;
      final opacity = cfg.vanishingEnabled
          ? (t <= cfg.vanishingProgress ? 0.25 : baseOpacity)
          : baseOpacity;

      final color = _routeStyleProSegmentColor(cfg, segIndex, animTick);
      final casingColor = _routeStyleProSegmentCasingColor(
        cfg,
        segIndex,
        animTick,
      );

      features.add({
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(color, opacity: opacity),
          'casingColor': _toHexRgb(casingColor),
          'width': width,
          'opacity': opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [a.lng, a.lat],
            [b.lng, b.lat],
          ],
        },
      });
      segIndex++;
    }

    return _featureCollection(features);
  }

  Color _routeStyleProSegmentColor(
    rsp.RouteStyleConfig cfg,
    int index,
    int animTick,
  ) {
    if (cfg.trafficDemoEnabled) {
      const traffic = [Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444)];
      return traffic[index % traffic.length];
    }

    if (cfg.rainbowEnabled) {
      final shift = (animTick % 360);
      final dir = cfg.rainbowReverse ? -1 : 1;
      final hue = (shift + dir * index * 14) % 360;
      return _hsvToColor(hue.toDouble(), cfg.rainbowSaturation, 1.0);
    }

    return cfg.mainColor;
  }

  Color _routeStyleProSegmentCasingColor(
    rsp.RouteStyleConfig cfg,
    int index,
    int animTick,
  ) {
    if (!cfg.effectiveCasingRainbowEnabled) return cfg.casingColor;
    final shift = (animTick % 360);
    final dir = cfg.rainbowReverse ? -1 : 1;
    final hue = (shift + dir * index * 14) % 360;
    return _hsvToColor(hue.toDouble(), cfg.rainbowSaturation, 1.0);
  }

  Color _hsvToColor(double h, double s, double v) {
    final hh = (h % 360) / 60.0;
    final c = v * s;
    final x = c * (1 - ((hh % 2) - 1).abs());
    final m = v - c;

    double r1 = 0, g1 = 0, b1 = 0;
    if (hh >= 0 && hh < 1) {
      r1 = c;
      g1 = x;
    } else if (hh < 2) {
      r1 = x;
      g1 = c;
    } else if (hh < 3) {
      g1 = c;
      b1 = x;
    } else if (hh < 4) {
      g1 = x;
      b1 = c;
    } else if (hh < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
      b1 = x;
    }

    final r = ((r1 + m) * 255).round().clamp(0, 255);
    final g = ((g1 + m) * 255).round().clamp(0, 255);
    final b = ((b1 + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  String _toHexRgba(Color c, {required double opacity}) {
    // Mapbox accepte bien rgba() (plus robuste que #RRGGBBAA selon environnements).
    final a = opacity.clamp(0.0, 1.0);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  String _toHexRgb(Color c) {
    final r = ((c.r * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final g = ((c.g * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final b = ((c.b * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  List<LngLat>? _poiPerimeterFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    if (meta == null) return null;
    final raw = meta['perimeter'];
    if (raw is! List) return null;
    final pts = <LngLat>[];
    for (final item in raw) {
      if (item is Map) {
        final lng = (item['lng'] as num?)?.toDouble();
        final lat = (item['lat'] as num?)?.toDouble();
        if (lng != null && lat != null) {
          pts.add((lng: lng, lat: lat));
        }
      }
    }
    return pts.length >= 3 ? pts : null;
  }

  String? _defaultLayerColorHex(String layerType) {
    for (final l in _layers) {
      if (l.type == layerType) {
        final hex = _normalizeColorHex(l.color);
        if (hex != null) return hex;
      }
    }
    return null;
  }

  String? _normalizeColorHex(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    final hex6 = RegExp(r'^#?[0-9a-fA-F]{6}$');
    if (hex6.hasMatch(v)) {
      final s = v.startsWith('#') ? v : '#$v';
      return s.toUpperCase();
    }
    final hex8 = RegExp(r'^0x[0-9a-fA-F]{8}$');
    if (hex8.hasMatch(v)) {
      // 0xAARRGGBB -> #RRGGBB
      final rgb = v.substring(v.length - 6);
      return '#${rgb.toUpperCase()}';
    }
    return null;
  }

  Map<String, dynamic> _parkingZoneRawStyleFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    final styleRaw = meta?[_parkingZoneStyleKey];
    final style = (styleRaw is Map) ? styleRaw.cast<String, dynamic>() : null;

    final layerHex =
        _defaultLayerColorHex(poi.layerType) ?? _parkingZoneDefaultFillHex;
    final labelPreset = _parkingZoneLabelPresetFromStyle(style);
    final fillColor =
        _normalizeColorHex(style?['fillColor']?.toString()) ?? layerHex;
    final strokeColor =
        _normalizeColorHex(style?['strokeColor']?.toString()) ??
        (labelPreset == _parkingZoneLabelPresetWideBlue
            ? _parkingZoneDefaultStrokeHex
            : fillColor);
    final colorSaturation =
        (style?['colorSaturation'] as num?)?.toDouble() ??
        _parkingZoneDefaultColorSaturation;
    final fillOpacity =
        (style?['fillOpacity'] as num?)?.toDouble() ??
        _parkingZoneDefaultFillOpacity;
    final strokeWidth =
        (style?['strokeWidth'] as num?)?.toDouble() ??
        _parkingZoneDefaultStrokeWidth;
    final dashRaw = style?['strokeDash'];
    final dash = (dashRaw is String && dashRaw.trim().isNotEmpty)
        ? dashRaw.trim()
        : 'solid';

    final pattern =
        (style?['pattern'] is String &&
            (style?['pattern'] as String).trim().isNotEmpty)
        ? (style?['pattern'] as String).trim()
        : 'none';
    final patternOpacity =
        (style?['patternOpacity'] as num?)?.toDouble() ??
        _parkingZoneDefaultPatternOpacity;

    return <String, dynamic>{
      'fillColor': fillColor,
      'fillOpacity': fillOpacity.clamp(0.0, 1.0),
      'strokeColor': strokeColor,
      'colorSaturation': colorSaturation.clamp(0.0, 1.0),
      'strokeWidth': strokeWidth,
      'strokeDash': dash,
      'pattern': pattern,
      'patternOpacity': patternOpacity.clamp(0.0, 1.0),
      _parkingZoneLabelPresetKey: labelPreset,
    };
  }

  Map<String, dynamic> _parkingZoneStyleFromMetadata(MarketMapPOI poi) {
    final raw = _parkingZoneRawStyleFromMetadata(poi);
    final colorSaturation =
        (raw['colorSaturation'] as num?)?.toDouble() ??
        _parkingZoneDefaultColorSaturation;

    return <String, dynamic>{
      ...raw,
      'fillColor': _applyParkingColorSaturationToHex(
        raw['fillColor'] as String? ?? _parkingZoneDefaultFillHex,
        colorSaturation,
      ),
      'strokeColor': _applyParkingColorSaturationToHex(
        raw['strokeColor'] as String? ??
            (raw['fillColor'] as String? ?? _parkingZoneDefaultFillHex),
        colorSaturation,
      ),
    };
  }

  String? _mapboxFillPatternIdFromStylePattern(String? pattern) {
    switch ((pattern ?? '').trim()) {
      case 'diag':
        return 'maslive_pat_diag';
      case 'cross':
        return 'maslive_pat_cross';
      case 'dots':
        return 'maslive_pat_dots';
      default:
        return null;
    }
  }

  LngLat _centroidOf(List<LngLat> points) {
    if (points.isEmpty) return (lng: -61.533, lat: 16.241);
    var sumLng = 0.0;
    var sumLat = 0.0;
    for (final p in points) {
      sumLng += p.lng;
      sumLat += p.lat;
    }
    return (lng: sumLng / points.length, lat: sumLat / points.length);
  }

  Map<String, dynamic> _buildPoisFeatureCollection(
    List<MarketMapPOI> pois, {
    List<LngLat>? previewParkingZonePoints,
  }) {
    final features = <Map<String, dynamic>>[];

    for (final poi in pois) {
      final perimeter = _poiPerimeterFromMetadata(poi);

      if (perimeter != null) {
        final style = _parkingZoneStyleFromMetadata(poi);
        final fillPattern = _mapboxFillPatternIdFromStylePattern(
          style['pattern'] as String?,
        );
        final ring = <List<double>>[
          for (final p in perimeter) <double>[p.lng, p.lat],
          <double>[perimeter.first.lng, perimeter.first.lat],
        ];
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': poi.id,
          'properties': <String, dynamic>{
            'poiId': poi.id,
            'layerId': poi.layerType,
            'title': poi.name,
            'isZone': true,
            'fillColor': style['fillColor'],
            'fillOpacity': style['fillOpacity'],
            'strokeColor': style['strokeColor'],
            'strokeWidth': style['strokeWidth'],
            'strokeDash': style['strokeDash'],
            if (fillPattern != null) 'fillPattern': fillPattern,
            'patternOpacity': style['patternOpacity'],
          },
          'geometry': <String, dynamic>{
            'type': 'Polygon',
            'coordinates': <List<List<double>>>[ring],
          },
        });

        // Label “P” au centre pour les zones parking.
        if (poi.layerType == 'parking') {
          final c = _centroidOf(perimeter);
          final vehicleTypes = _parkingZoneVehicleTypesFromMetadata(poi);
          final labelPreset = _parkingZoneLabelPresetFromStyle(style);
          final badgeId = _parkingZoneBadgeIdForPerimeter(
            perimeter,
            labelPreset,
          );
          features.add(<String, dynamic>{
            'type': 'Feature',
            'id': '${poi.id}__zone_label',
            'properties': <String, dynamic>{
              'poiId': poi.id,
              'layerId': poi.layerType,
              'title': poi.name,
              'isZoneLabel': true,
              'labelText': _parkingZoneLabelText(vehicleTypes),
              'labelTextSize': _parkingZoneLabelTextSizeForPerimeter(
                perimeter,
                labelPreset,
              ),
              'parkingIconId': _parkingZoneSymbolImageId(vehicleTypes),
              'parkingIconScale': _parkingZoneIconScaleForPerimeter(
                perimeter,
                labelPreset,
              ),
              if (badgeId != null) 'parkingBadgeId': badgeId,
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[c.lng, c.lat],
            },
          });
        }
      } else {
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': poi.id,
          'properties': <String, dynamic>{
            'poiId': poi.id,
            'layerId': poi.layerType,
            'title': poi.name,
            if (poi.metadata?[kMasLivePoiAppearanceKey] is String)
              kMasLivePoiAppearanceKey: poi.metadata![kMasLivePoiAppearanceKey],
          },
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[poi.lng, poi.lat],
          },
        });
      }
    }

    if (previewParkingZonePoints != null &&
        previewParkingZonePoints.isNotEmpty) {
      final previewBaseFill =
          _normalizeColorHex(_parkingZoneFillColorHex) ??
          _parkingZoneDefaultFillHex;
      final previewBaseStroke = _parkingZoneStrokeFollowsFill
          ? previewBaseFill
          : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? previewBaseFill);
      final previewStroke = _applyParkingColorSaturationToHex(
        previewBaseStroke,
        _parkingZoneColorSaturation,
      );

      // Points de prévisualisation: un point visible à chaque tap.
      for (var i = 0; i < previewParkingZonePoints.length; i++) {
        final p = previewParkingZonePoints[i];
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': '__preview_parking_vertex__$i',
          'properties': <String, dynamic>{
            'layerId': 'parking',
            'title': 'Point zone parking',
            'isPreview': true,
            'isPreviewVertex': true,
            'fillColor': '#FFFFFF',
            'strokeColor': previewStroke,
            'strokeWidth': _parkingZoneStrokeWidth,
          },
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[p.lng, p.lat],
          },
        });
      }

      if (previewParkingZonePoints.length >= 2) {
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': '__preview_parking_path__',
          'properties': <String, dynamic>{
            'poiId': '__preview_parking_path__',
            'layerId': 'parking',
            'title': 'Tracé zone parking',
            'isPreview': true,
            'isPreviewEdge': true,
            'strokeColor': previewStroke,
            'strokeWidth': _parkingZoneStrokeWidth,
            'strokeDash': _parkingZoneStrokeDash,
          },
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': [
              for (final p in previewParkingZonePoints) <double>[p.lng, p.lat],
            ],
          },
        });
      }
    }

    if (previewParkingZonePoints != null &&
        previewParkingZonePoints.length >= 3) {
      final ring = <List<double>>[
        for (final p in previewParkingZonePoints) <double>[p.lng, p.lat],
        <double>[
          previewParkingZonePoints.first.lng,
          previewParkingZonePoints.first.lat,
        ],
      ];

      final previewBaseFill =
          _normalizeColorHex(_parkingZoneFillColorHex) ??
          _parkingZoneDefaultFillHex;
      final previewFill = _applyParkingColorSaturationToHex(
        previewBaseFill,
        _parkingZoneColorSaturation,
      );

      final previewBaseStroke = _parkingZoneStrokeFollowsFill
          ? previewBaseFill
          : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? previewBaseFill);
      final previewStroke = _applyParkingColorSaturationToHex(
        previewBaseStroke,
        _parkingZoneColorSaturation,
      );

      final previewPattern = _mapboxFillPatternIdFromStylePattern(
        _parkingZonePattern,
      );

      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': '__preview_parking_zone__',
        'properties': <String, dynamic>{
          'poiId': '__preview_parking_zone__',
          'layerId': 'parking',
          'title': 'Zone parking (aperçu)',
          'isPreview': true,
          'isZone': true,
          'fillColor': previewFill,
          'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
          'strokeColor': previewStroke,
          'strokeWidth': _parkingZoneStrokeWidth,
          'strokeDash': _parkingZoneStrokeDash,
          if (previewPattern != null) 'fillPattern': previewPattern,
          'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
        },
        'geometry': <String, dynamic>{
          'type': 'Polygon',
          'coordinates': <List<List<double>>>[ring],
        },
      });

      // Label preview au centre.
      final c = _centroidOf(previewParkingZonePoints);
      final badgeId = _parkingZoneBadgeIdForPerimeter(
        previewParkingZonePoints,
        _parkingZoneLabelPreset,
      );
      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': '__preview_parking_zone_label__',
        'properties': <String, dynamic>{
          'poiId': '__preview_parking_zone__',
          'layerId': 'parking',
          'title': 'Zone parking (aperçu)',
          'isPreview': true,
          'isZoneLabel': true,
          'labelText': _parkingZoneLabelText(_parkingZoneVehicleTypes),
          'labelTextSize': _parkingZoneLabelTextSizeForPerimeter(
            previewParkingZonePoints,
            _parkingZoneLabelPreset,
          ),
          'parkingIconId': _parkingZoneSymbolImageId(_parkingZoneVehicleTypes),
          'parkingIconScale': _parkingZoneIconScaleForPerimeter(
            previewParkingZonePoints,
            _parkingZoneLabelPreset,
          ),
          if (badgeId != null) 'parkingBadgeId': badgeId,
        },
        'geometry': <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[c.lng, c.lat],
        },
      });
    }

    return <String, dynamic>{'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _onMapTapForPoi(double lng, double lat) async {
    if ((_isDrawingParkingZone || _isEditingParkingZonePerimeter) &&
        _selectedLayer?.type == 'parking') {
      setState(() {
        _parkingZonePoints = <LngLat>[
          ..._parkingZonePoints,
          (lng: lng, lat: lat),
        ];
      });
      try {
        await _refreshPoiMarkers();
      } catch (e) {
        debugPrint('Erreur lors de l\'ajout du point parking: $e');
        if (mounted) {
          _showTopSnackBar(
            '⚠️ Erreur lors de l\'ajout du point',
            isError: true,
          );
        }
      }
      return;
    }

    await _createPoiAt(lng: lng, lat: lat);
  }

  Future<void> _editPoi(MarketMapPOI poi) async {
    final perimeter = _poiPerimeterFromMetadata(poi);
    if (perimeter != null) {
      // Garder l'éditeur inline pour les zones parking (style, etc.).
      _openPoiEditSection(poi);
      return;
    }

    final updated = await showModalBottomSheet<MarketMapPOI>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PoiEditPopup(
        poi: poi,
        projectId: _projectId,
        appearancePresets: kMasLivePoiAppearancePresets,
      ),
    );

    if (updated == null) return;

    setState(() {
      final idx = _pois.indexWhere((p) => p.id == poi.id);
      if (idx >= 0) {
        _pois[idx] = updated;
      }
    });
    _poiSelection.select(updated);
    _refreshPoiMarkers();

    await _persistPoiDraftUpdate(updated);
  }

  String _draftPoiDocId(MarketMapPOI poi) {
    final trimmed = poi.id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'poi_${poi.layerType}_${poi.lng.toStringAsFixed(5)}_${poi.lat.toStringAsFixed(5)}';
  }

  Future<void> _persistPoiDraftUpdate(MarketMapPOI poi) async {
    final projectId = _projectId;
    if (projectId == null || projectId.trim().isEmpty) return;

    try {
      final docId = _draftPoiDocId(poi);
      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .collection('pois')
          .doc(docId)
          .set({
            ...poi.toFirestore(),
            'layerId': (poi.layerId ?? poi.layerType).trim(),
            'isVisible': poi.isVisible,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        '⚠️ POI sauvegardé localement mais Firestore a refusé: $e',
        isError: true,
        duration: const Duration(seconds: 6),
      );
    }
  }

  Future<void> _deletePoiDraft(MarketMapPOI poi) async {
    final projectId = _projectId;
    if (projectId == null || projectId.trim().isEmpty) return;

    final docId = _draftPoiDocId(poi);
    try {
      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .collection('pois')
          .doc(docId)
          .delete();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      rethrow;
    }
  }

  void _startParkingZoneDrawing() {
    if (_selectedLayer?.type != 'parking') return;
    _poiSelection.clear();
    _closePoiInlineEditor(keepSelection: false);

    setState(() {
      _isDrawingParkingZone = true;
      _isEditingParkingZonePerimeter = false;
      _parkingZonePoints = <LngLat>[];
      _parkingZoneVehicleTypes = <String>{'car', 'moto'};

      _parkingZoneFillColorHex = _parkingZoneDefaultFillHex;
      _parkingZoneColorSaturation = _parkingZoneDefaultColorSaturation;
      _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneLabelPreset = _parkingZoneLabelPresetWideBlue;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = _parkingZoneDefaultFillHex;
      _parkingZoneStrokeColorHex = _parkingZoneDefaultStrokeHex;
      _parkingZoneStrokeFollowsFill = false;
      _parkingZoneStrokeColorController.text = _parkingZoneDefaultStrokeHex;
    });
    _refreshPoiMarkers();
  }

  void _cancelParkingZoneDrawing() {
    setState(() {
      _isDrawingParkingZone = false;
      _isEditingParkingZonePerimeter = false;
      _parkingZonePoints = <LngLat>[];
    });
    _refreshPoiMarkers();
  }

  void _startParkingZonePerimeterEditing(MarketMapPOI poi) {
    final perimeter = _poiPerimeterFromMetadata(poi);
    if (perimeter == null || perimeter.length < 3) return;

    _poiSelection.select(poi);
    setState(() {
      _isDrawingParkingZone = false;
      _isEditingParkingZonePerimeter = true;
      _parkingZonePoints = List<LngLat>.from(perimeter);
      _poiInlineError = null;
    });
    _refreshPoiMarkers();
    _scrollPoiBottomSectionIntoView();
  }

  void _cancelParkingZonePerimeterEditing() {
    setState(() {
      _isEditingParkingZonePerimeter = false;
      _parkingZonePoints = <LngLat>[];
      _poiInlineError = null;
    });
    _refreshPoiMarkers();
  }

  void _removeLastParkingZonePoint() {
    if (_parkingZonePoints.isEmpty) return;
    setState(() {
      _parkingZonePoints = _parkingZonePoints.sublist(
        0,
        _parkingZonePoints.length - 1,
      );
    });
    _refreshPoiMarkers();
  }

  void _finishParkingZoneDrawing() {
    if (_selectedLayer?.type != 'parking') return;
    if (_parkingZonePoints.length < 3) return;
    _openPoiCreateZoneSection(perimeterPoints: _parkingZonePoints);
  }

  void _commitPoiInlineEditor() {
    if (_selectedLayer == null) return;

    if (_poiInlineEditorMode == _PoiInlineEditorMode.createZone) {
      if (_selectedLayer?.type != 'parking') {
        setState(
          () => _poiInlineError = 'Zone disponible uniquement en parking.',
        );
        return;
      }
      if (_parkingZonePoints.length < 3) {
        setState(
          () => _poiInlineError = 'Périmètre incomplet (min. 3 points).',
        );
        return;
      }

      final name = _poiInlineNameController.text.trim().isEmpty
          ? 'Zone parking'
          : _poiInlineNameController.text.trim();

      final fillHex =
          _normalizeColorHex(_parkingZoneColorController.text) ??
          _normalizeColorHex(_parkingZoneFillColorHex);
      if (fillHex == null) {
        setState(
          () => _poiInlineError =
              'Couleur invalide (attendu: #RRGGBB, ex: $_parkingZoneDefaultFillHex).',
        );
        return;
      }

      final strokeHex = _parkingZoneStrokeFollowsFill
          ? fillHex
          : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? fillHex);

      final centroid = _centroidOf(_parkingZonePoints);
      final poi = MarketMapPOI(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        layerType: 'parking',
        layerId: 'parking',
        lng: centroid.lng,
        lat: centroid.lat,
        isVisible: true,
        description: null,
        imageUrl: null,
        metadata: <String, dynamic>{
          _parkingZoneVehiclesKey: _parkingZoneVehicleTypes.toList()..sort(),
          'perimeter': [
            for (final p in _parkingZonePoints) {'lng': p.lng, 'lat': p.lat},
          ],
          _parkingZoneStyleKey: <String, dynamic>{
            'fillColor': fillHex,
            'colorSaturation': _parkingZoneColorSaturation.clamp(0.0, 1.0),
            'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
            'strokeColor': strokeHex,
            'strokeWidth': _parkingZoneStrokeWidth,
            _parkingZoneLabelPresetKey: _parkingZoneLabelPreset,
            'strokeDash': _parkingZoneStrokeDash,
            'pattern': _parkingZonePattern,
            'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
          },
        },
      );

      setState(() {
        _pois.add(poi);
        _poiInlineEditorMode = _PoiInlineEditorMode.none;
        _poiInlineError = null;
        _isDrawingParkingZone = false;
        _parkingZonePoints = <LngLat>[];
      });
      _refreshPoiMarkers();
      _poiSelection.select(poi);
      unawaited(_persistPoiDraftUpdate(poi));
      return;
    }

    if (_poiInlineEditorMode == _PoiInlineEditorMode.edit) {
      final poi = _poiEditingPoi;
      if (poi == null) return;
      final nextName = _poiInlineNameController.text.trim();
      if (nextName.isEmpty) {
        setState(() => _poiInlineError = 'Le nom ne peut pas être vide.');
        return;
      }

      final perimeter = _poiPerimeterFromMetadata(poi);
      final isZone = perimeter != null;
      final zonePerimeter = _isEditingParkingZonePerimeter
          ? _parkingZonePoints
          : (perimeter ?? const <LngLat>[]);

      Map<String, dynamic>? nextMetadata = poi.metadata;
      var nextLng = poi.lng;
      var nextLat = poi.lat;
      if (isZone) {
        if (zonePerimeter.length < 3) {
          setState(
            () => _poiInlineError = 'Périmètre incomplet (min. 3 points).',
          );
          return;
        }

        final fillHex =
            _normalizeColorHex(_parkingZoneColorController.text) ??
            _normalizeColorHex(_parkingZoneFillColorHex);
        if (fillHex == null) {
          setState(
            () => _poiInlineError =
                'Couleur invalide (attendu: #RRGGBB, ex: $_parkingZoneDefaultFillHex).',
          );
          return;
        }

        final strokeHex = _parkingZoneStrokeFollowsFill
            ? fillHex
            : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? fillHex);
        final centroid = _centroidOf(zonePerimeter);
        nextLng = centroid.lng;
        nextLat = centroid.lat;
        nextMetadata = <String, dynamic>{
          ...(poi.metadata ?? const <String, dynamic>{}),
          _parkingZoneVehiclesKey: _parkingZoneVehicleTypes.toList()..sort(),
          'perimeter': [
            for (final p in zonePerimeter) {'lng': p.lng, 'lat': p.lat},
          ],
          _parkingZoneStyleKey: <String, dynamic>{
            'fillColor': fillHex,
            'colorSaturation': _parkingZoneColorSaturation.clamp(0.0, 1.0),
            'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
            'strokeColor': strokeHex,
            'strokeWidth': _parkingZoneStrokeWidth,
            _parkingZoneLabelPresetKey: _parkingZoneLabelPreset,
            'strokeDash': _parkingZoneStrokeDash,
            'pattern': _parkingZonePattern,
            'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
          },
        };
      } else {
        nextMetadata = <String, dynamic>{
          ...(poi.metadata ?? const <String, dynamic>{}),
          kMasLivePoiAppearanceKey: normalizeMasLivePoiAppearanceId(
            _poiInlineAppearanceId,
          ),
        };
      }

      setState(() {
        final idx = _pois.indexWhere((p) => p.id == poi.id);
        if (idx >= 0) {
          final updated = MarketMapPOI(
            id: poi.id,
            name: nextName,
            layerType: poi.layerType,
            layerId: poi.layerId,
            lng: nextLng,
            lat: nextLat,
            isVisible: poi.isVisible,
            description: poi.description,
            imageUrl: poi.imageUrl,
            address: poi.address,
            openingHours: poi.openingHours,
            phone: poi.phone,
            website: poi.website,
            instagram: poi.instagram,
            facebook: poi.facebook,
            whatsapp: poi.whatsapp,
            email: poi.email,
            mapsUrl: poi.mapsUrl,
            metadata: nextMetadata,
          );
          _pois[idx] = updated;
          _poiSelection.select(updated);
          unawaited(_persistPoiDraftUpdate(updated));
        }
        _isDrawingParkingZone = false;
        _isEditingParkingZonePerimeter = false;
        _parkingZonePoints = <LngLat>[];
        _poiInlineEditorMode = _PoiInlineEditorMode.none;
        _poiEditingPoi = null;
        _poiInlineError = null;
      });
      _refreshPoiMarkers();
    }
  }

  Widget _buildPoiInlineEditorSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = colorScheme.surface;
    final isCreateZone =
        _poiInlineEditorMode == _PoiInlineEditorMode.createZone;
    final isEdit = _poiInlineEditorMode == _PoiInlineEditorMode.edit;

    final editingPoi = _poiEditingPoi;
    final isEditZone =
        isEdit &&
        editingPoi != null &&
        _poiPerimeterFromMetadata(editingPoi) != null;
    final editZonePerimeter = editingPoi == null
        ? null
        : _poiPerimeterFromMetadata(editingPoi);
    final displayedPerimeterCount = isCreateZone
        ? _parkingZonePoints.length
        : (_isEditingParkingZonePerimeter
              ? _parkingZonePoints.length
              : (editZonePerimeter?.length ?? 0));

    final title = isEdit ? 'Modifier la zone parking' : 'Nouvelle zone parking';

    final primaryLabel = isEdit ? 'Enregistrer' : 'Ajouter la zone';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
      child: Material(
        color: bg,
        elevation: 0,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () {
                      if (isCreateZone) {
                        _cancelParkingZoneDrawing();
                      } else if (_isEditingParkingZonePerimeter) {
                        _cancelParkingZonePerimeterEditing();
                      }
                      _closePoiInlineEditor();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _poiInlineNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isCreateZone || isEditZone) ...[
                const SizedBox(height: 12),
                Text(
                  'Périmètre: $displayedPerimeterCount points',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              if (isEditZone) ...[
                const SizedBox(height: 10),
                if (!_isEditingParkingZonePerimeter)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          _startParkingZonePerimeterEditing(editingPoi),
                      icon: const Icon(Icons.draw_rounded, size: 18),
                      label: const Text('Modifier le périmètre sur la carte'),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _parkingZonePoints.isEmpty
                            ? null
                            : _removeLastParkingZonePoint,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Retirer le dernier point'),
                      ),
                      TextButton(
                        onPressed: _cancelParkingZonePerimeterEditing,
                        child: const Text('Annuler le contour'),
                      ),
                    ],
                  ),
              ],

              if (isCreateZone || isEditZone) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _applyParkingZonePresetWhiteBlue,
                  child: const Text('Preset badge parking blanc/bleu'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Types affichés sur la zone',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilterChip(
                      selected: _parkingZoneVehicleTypes.contains('car'),
                      onSelected: (_) => _toggleParkingZoneVehicleType('car'),
                      avatar: Icon(
                        Icons.directions_car_filled_rounded,
                        size: 18,
                        color: _parkingZoneVehicleTypes.contains('car')
                            ? Colors.white
                            : MasliveTokens.textSoft,
                      ),
                      label: Text(
                        'Voiture',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _parkingZoneVehicleTypes.contains('car')
                              ? Colors.white
                              : MasliveTokens.text,
                        ),
                      ),
                      selectedColor: MasliveTokens.primary,
                      checkmarkColor: Colors.white,
                    ),
                    FilterChip(
                      selected: _parkingZoneVehicleTypes.contains('moto'),
                      onSelected: (_) => _toggleParkingZoneVehicleType('moto'),
                      avatar: Icon(
                        Icons.two_wheeler_rounded,
                        size: 18,
                        color: _parkingZoneVehicleTypes.contains('moto')
                            ? Colors.white
                            : MasliveTokens.textSoft,
                      ),
                      label: Text(
                        'Moto',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _parkingZoneVehicleTypes.contains('moto')
                              ? Colors.white
                              : MasliveTokens.text,
                        ),
                      ),
                      selectedColor: MasliveTokens.primary,
                      checkmarkColor: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _parkingZoneColorController,
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneFillColorHex = v;
                      if (_parkingZoneStrokeFollowsFill) {
                        _parkingZoneStrokeColorHex = v;
                        _parkingZoneStrokeColorController.text = v;
                      }
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Couleur fond (hex, ex: #0A84FF)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _parkingZoneStrokeFollowsFill,
                  onChanged: (value) {
                    setState(() {
                      _parkingZoneStrokeFollowsFill = value;
                      if (value) {
                        _parkingZoneStrokeColorHex = _parkingZoneFillColorHex;
                        _parkingZoneStrokeColorController.text =
                            _parkingZoneFillColorHex;
                      }
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                  title: const Text('Contour suit le fond'),
                  subtitle: const Text(
                    'Désactivez pour choisir une couleur de contour séparée.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _parkingZoneStrokeColorController,
                  enabled: !_parkingZoneStrokeFollowsFill,
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneStrokeColorHex = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                  decoration: InputDecoration(
                    labelText: 'Couleur contour (hex, ex: #FFFFFF)',
                    border: const OutlineInputBorder(),
                    helperText: _parkingZoneStrokeFollowsFill
                        ? 'Le contour reprend actuellement la couleur du fond.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFineAdjustSlider(
                  label: 'Couleurs (saturation)',
                  value: _parkingZoneColorSaturation,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  displayValue:
                      '${(100 * _parkingZoneColorSaturation.clamp(0.0, 1.0)).round()}%',
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneColorSaturation = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                ),
                const SizedBox(height: 12),
                _buildFineAdjustSlider(
                  label: 'Fond (opacité)',
                  value: _parkingZoneFillOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  displayValue: '${(100 * _parkingZoneFillOpacity).round()}%',
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneFillOpacity = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                ),
                const SizedBox(height: 12),
                _buildFineAdjustSlider(
                  label: 'Contour (largeur)',
                  value: _parkingZoneStrokeWidth,
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  displayValue: _parkingZoneStrokeWidth.toStringAsFixed(1),
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneStrokeWidth = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                ),
                const SizedBox(height: 4),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Texture (contour)',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _parkingZoneStrokeDash,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'solid', child: Text('Plein')),
                        DropdownMenuItem(
                          value: 'dashed',
                          child: Text('Pointillé'),
                        ),
                        DropdownMenuItem(
                          value: 'dotted',
                          child: Text('Pointillé fin'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _parkingZoneStrokeDash = v;
                          _poiInlineError = null;
                        });
                        _refreshPoiMarkers();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Texture intérieure (pattern)',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _parkingZonePattern,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('Aucune')),
                        DropdownMenuItem(
                          value: 'diag',
                          child: Text('Diagonale'),
                        ),
                        DropdownMenuItem(
                          value: 'cross',
                          child: Text('Croisillons'),
                        ),
                        DropdownMenuItem(value: 'dots', child: Text('Points')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _parkingZonePattern = v;
                          _poiInlineError = null;
                        });
                        _refreshPoiMarkers();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFineAdjustSlider(
                  label: 'Texture intérieure (opacité)',
                  value: _parkingZonePatternOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  displayValue:
                      '${(100 * _parkingZonePatternOpacity.clamp(0.0, 1.0)).round()}%',
                  onChanged: _parkingZonePattern == 'none'
                      ? null
                      : (v) {
                          setState(() {
                            _parkingZonePatternOpacity = v;
                            _poiInlineError = null;
                          });
                          _refreshPoiMarkers();
                        },
                ),
              ],
              if (_poiInlineError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _poiInlineError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        if (isCreateZone) {
                          _cancelParkingZoneDrawing();
                        } else if (_isEditingParkingZonePerimeter) {
                          _cancelParkingZonePerimeterEditing();
                        }
                        _closePoiInlineEditor();
                      },
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _commitPoiInlineEditor,
                      child: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePoi(MarketMapPOI poi) async {
    final removedIndex = _pois.indexWhere((p) => p.id == poi.id);
    if (removedIndex < 0) return;

    final removedPoi = _pois[removedIndex];
    final shouldClearSelection = _poiSelection.selectedPoi?.id == poi.id;
    final shouldCloseInlineEditor = _poiEditingPoi?.id == poi.id;

    setState(() {
      _pois.removeWhere((p) => p.id == poi.id);
    });

    if (shouldCloseInlineEditor) {
      _closePoiInlineEditor(keepSelection: false);
    }
    if (shouldClearSelection) {
      _poiSelection.clear();
    }
    await _refreshPoiMarkers();

    try {
      await _deletePoiDraft(poi);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final safeIndex = removedIndex.clamp(0, _pois.length);
        _pois.insert(safeIndex, removedPoi);
      });
      await _refreshPoiMarkers();

      _showTopSnackBar(
        '⚠️ Suppression locale effectuée, mais Firestore a refusé: $e',
        isError: true,
        duration: const Duration(seconds: 6),
      );
    }
  }

  Future<void> _addPoiAtCurrentCenter() async {
    final cameraCenter = await _poiMapController.getCameraCenter();

    double lng;
    double lat;

    if (cameraCenter != null) {
      lng = cameraCenter.lng;
      lat = cameraCenter.lat;
    } else if (_poiInitialLng != null && _poiInitialLat != null) {
      lng = _poiInitialLng!;
      lat = _poiInitialLat!;
    } else if (_routePoints.isNotEmpty) {
      lng = _routePoints.first.lng;
      lat = _routePoints.first.lat;
    } else if (_perimeterPoints.isNotEmpty) {
      lng = _perimeterPoints.first.lng;
      lat = _perimeterPoints.first.lat;
    } else {
      lng = -61.533;
      lat = 16.241;
    }

    await _createPoiAt(lng: lng, lat: lat);
  }

  Widget _buildFineAdjustSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int? divisions,
    required String displayValue,
    required ValueChanged<double>? onChanged,
  }) {
    final clamped = value.clamp(min, max);
    final step = divisions != null && divisions > 0
        ? (max - min) / divisions
        : 1.0;

    void nudge(double delta) {
      if (onChanged == null) return;
      final next = (clamped + delta).clamp(min, max);
      if ((next - clamped).abs() < 0.0000001) return;
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label: $displayValue',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Diminuer $label',
              visualDensity: VisualDensity.compact,
              onPressed: onChanged == null || clamped <= min
                  ? null
                  : () => nudge(-step),
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: clamped,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Augmenter $label',
              visualDensity: VisualDensity.compact,
              onPressed: onChanged == null || clamped >= max
                  ? null
                  : () => nudge(step),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactToolbarAdjuster({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required TextStyle labelStyle,
    required ValueChanged<double> onChanged,
  }) {
    final clamped = value.clamp(min, max);
    final step = (max - min) / divisions;

    void nudge(double delta) {
      final next = (clamped + delta).clamp(min, max);
      if ((next - clamped).abs() < 0.0000001) return;
      onChanged(next);
    }

    return Row(
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Diminuer $label',
          visualDensity: VisualDensity.compact,
          onPressed: clamped <= min ? null : () => nudge(-step),
          icon: const Icon(Icons.remove_rounded, size: 16),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 4),
        IconButton.outlined(
          tooltip: 'Augmenter $label',
          visualDensity: VisualDensity.compact,
          onPressed: clamped >= max ? null : () => nudge(step),
          icon: const Icon(Icons.add_rounded, size: 16),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: labelStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildStep7Validation() {
    final report = _qualityReport;
    final compactValidation = MediaQuery.sizeOf(context).width < 520;
    return GlassScrollbar(
      controller: _validationStepScrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: SingleChildScrollView(
        controller: _validationStepScrollController,
        padding: const EdgeInsets.fromLTRB(
          _wizardStepHorizontalPadding,
          0,
          _wizardStepHorizontalPadding,
          kBottomNavigationBarHeight + MasliveTokens.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWizardScrollableHeader(
              padding: const EdgeInsets.only(bottom: MasliveTokens.m),
            ),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.78,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pré-publication',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Score qualité: ${report.score}/100',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: report.canPublish ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: report.score / 100,
                      minHeight: 8,
                      color: report.canPublish ? Colors.green : Colors.orange,
                      backgroundColor: MasliveTokens.borderSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MasliveTokens.m),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.76,
              padding: const EdgeInsets.fromLTRB(
                MasliveTokens.s,
                MasliveTokens.s,
                MasliveTokens.s,
                MasliveTokens.s,
              ),
              child: Column(
                children: [
                  for (final item in report.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MasliveTokens.s,
                        vertical: 6,
                      ),
                      child: compactValidation
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.ok
                                          ? Icons.check_circle
                                          : Icons.error_outline,
                                      color: item.ok
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MasliveTokens.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!item.ok && item.hint != null) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 34),
                                    child: Text(
                                      item.hint!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MasliveTokens.textSoft,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 34),
                                  child: Chip(
                                    label: Text(
                                      item.required ? 'Requis' : 'Optionnel',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  item.ok
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  color: item.ok
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MasliveTokens.text,
                                        ),
                                      ),
                                      if (!item.ok && item.hint != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.hint!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: MasliveTokens.textSoft,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Chip(
                                  label: Text(
                                    item.required ? 'Requis' : 'Optionnel',
                                  ),
                                ),
                              ],
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

  Widget _buildStep8Publish() {
    final report = _qualityReport;
    return GlassScrollbar(
      controller: _publishStepScrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: SingleChildScrollView(
        controller: _publishStepScrollController,
        padding: const EdgeInsets.fromLTRB(
          _wizardStepHorizontalPadding,
          0,
          _wizardStepHorizontalPadding,
          kBottomNavigationBarHeight + MasliveTokens.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWizardScrollableHeader(
              padding: const EdgeInsets.only(bottom: MasliveTokens.m),
            ),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.78,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Publication',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.canPublish
                              ? 'Votre circuit est prêt !'
                              : 'Circuit presque prêt',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: report.canPublish
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nom: ${_nameController.text.trim()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Points périmètre: ${_perimeterPoints.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Points tracé: ${_routePoints.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Score qualité: ${report.score}/100',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!report.canPublish) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '❌ Publication bloquée: corrige les points requis de l’étape Pré-publication.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MasliveTokens.m),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.76,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Options de publication',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    onPressed: (report.canPublish && !_isEnsuringAllPoisLoaded)
                        ? _publishCircuit
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    label: const Text(
                      'PUBLIER LE CIRCUIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isEnsuringAllPoisLoaded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chargement de tous les POIs avant publication…',
                            style: TextStyle(
                              fontSize: 12,
                              color: MasliveTokens.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt),
                    onPressed: () => _saveDraft(createSnapshot: true),
                    label: const Text('Rester en brouillon'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishCircuit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar(
          '⛔ Publication réservée aux admins master.',
          isError: true,
        );
        return;
      }

      // Garde-fou: si on n'a pas chargé tous les POIs (pagination), publier
      // supprimerait les POIs non chargés côté MarketMap (sync par différence).
      if (_hasMorePois || _isLoadingMorePois) {
        if (!mounted) return;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('POIs non chargés'),
            content: const Text(
              'Tous les POIs du brouillon ne sont pas chargés (pagination).\n'
              'Publier maintenant risquerait de supprimer des POIs existants dans MarketMap.\n\n'
              'Charge tous les POIs avant de publier.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('load'),
                child: const Text('Charger tout'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('goto'),
                child: const Text('Aller aux POIs'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (action == 'goto') {
          _pageController.animateToPage(
            5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }
        if (action != 'load') return;

        await _ensureAllPoisLoadedForPublish();

        if (_hasMorePois) {
          // Toujours incomplet: on bloque la publication.
          if (!mounted) return;
          _showTopSnackBar(
            '❌ Impossible de charger tous les POIs.',
            isError: true,
          );
          return;
        }
      }

      setState(() => _isLoading = true);

      final report = _qualityReport;
      if (!report.canPublish) {
        throw StateError(
          'Pré-publication non conforme: corrige les points bloquants.',
        );
      }

      if (_projectId == null) {
        await _saveDraft();
      }

      final projectId = _projectId;
      if (projectId == null) {
        throw Exception('Project not initialized');
      }

      final countryId = _countryController.text.trim();
      final eventId = _eventController.text.trim();
      final marketCircuitId = (widget.circuitId?.trim().isNotEmpty ?? false)
          ? widget.circuitId!.trim()
          : projectId;

      if (countryId.isEmpty || eventId.isEmpty) {
        throw StateError('Pays et événement requis pour publier.');
      }

      await _versioning.lockProject(projectId: projectId, uid: user.uid);
      try {
        await _repository.publishToMarketMap(
          projectId: projectId,
          actorUid: user.uid,
          actorRole: _currentUserRole ?? 'creator',
          groupId: _currentGroupId ?? 'default',
          countryId: countryId,
          eventId: eventId,
          marketCircuitId: marketCircuitId,
          currentData: _buildCurrentData(),
          layers: _layers,
          pois: _pois,
        );
      } finally {
        await _versioning.unlockProject(projectId: projectId);
      }

      if (mounted) {
        _showTopSnackBar('✅ Circuit publié avec succès !');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('WizardPro _publishCircuit error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Publication Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur publication: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 7),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ({
    IconData? icon,
    Widget? iconWidget,
    bool fullBleed,
    bool tintOnSelected,
    bool showBorder,
  })
  _poiNavVisualForLayerType(String type) {
    final norm = type.trim().toLowerCase();

    // Aligné avec les icônes utilisées sur la Home (barre nav verticale).
    // - visit: map_outlined
    // - food: fastfood_rounded
    // - assistance: shield_outlined
    // - parking: asset icon wc/parking
    switch (norm) {
      case 'visit':
      case 'tour':
        return (
          icon: Icons.map_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'food':
        return (
          icon: Icons.fastfood_rounded,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'assistance':
        return (
          icon: Icons.shield_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'parking':
        return (
          icon: null,
          iconWidget: Image.asset(
            'assets/images/icon wc parking.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          fullBleed: false,
          tintOnSelected: false,
          showBorder: true,
        );
      case 'wc':
        // La Home utilise ce slot pour la langue, donc on garde une icône WC.
        return (
          icon: Icons.wc_rounded,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      default:
        return (
          icon: Icons.place_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
    }
  }
}
