// Page carte live affichant position moyenne du groupe

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/group_admin.dart';
import '../../services/group/group_average_service.dart';
import '../../ui/map/maslive_map.dart';
import '../../ui/map/maslive_map_controller.dart';

class GroupMapLivePage extends StatefulWidget {
  final String adminGroupId;

  const GroupMapLivePage({super.key, required this.adminGroupId});

  @override
  State<GroupMapLivePage> createState() => _GroupMapLivePageState();
}

class _GroupMapLivePageState extends State<GroupMapLivePage> {
  final _averageService = GroupAverageService.instance;
  final _mapController = MasLiveMapController();

  GeoPosition? _lastAvgPos;
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _applyAverageToMap({required GeoPosition pos, bool recenter = false}) async {
    if (!_mapReady) return;

    await _mapController.setMarkers([
      MapMarker(
        id: 'group_avg',
        lng: pos.lng,
        lat: pos.lat,
        label: 'Position moyenne',
      ),
    ]);

    if (recenter) {
      await _mapController.moveTo(lng: pos.lng, lat: pos.lat, zoom: 15.0, animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte Live Groupe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              final pos = _lastAvgPos;
              if (pos == null) return;
              _applyAverageToMap(pos: pos, recenter: true);
            },
          ),
        ],
      ),
      body: StreamBuilder<GeoPosition?>(
        stream: _averageService.streamAveragePosition(widget.adminGroupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final avgPos = snapshot.data;

          if (avgPos == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune position disponible',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Démarrez le tracking',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          if (_lastAvgPos != avgPos) {
            _lastAvgPos = avgPos;
            // Ne pas await dans build().
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_applyAverageToMap(pos: avgPos));
            });
          }

          return MasLiveMap(
            controller: _mapController,
            initialLat: avgPos.lat,
            initialLng: avgPos.lng,
            initialZoom: 15.0,
            onMapReady: (_) {
              _mapReady = true;
              final pos = _lastAvgPos;
              if (pos != null) {
                unawaited(_applyAverageToMap(pos: pos));
              }
            },
          );
        },
      ),
    );
  }
}
