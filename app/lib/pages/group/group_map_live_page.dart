// Page carte live affichant position moyenne du groupe

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/group_admin.dart';
import '../../services/group/group_average_service.dart';

class GroupMapLivePage extends StatefulWidget {
  final String adminGroupId;

  const GroupMapLivePage({super.key, required this.adminGroupId});

  @override
  State<GroupMapLivePage> createState() => _GroupMapLivePageState();
}

class _GroupMapLivePageState extends State<GroupMapLivePage> {
  final _averageService = GroupAverageService.instance;
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte Live Groupe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Recentre sur position moyenne
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

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(avgPos.lat, avgPos.lng),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.maslive.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(avgPos.lat, avgPos.lng),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Groupe',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
