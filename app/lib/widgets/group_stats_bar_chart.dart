// Widget Bar Chart statistiques groupe avec fl_chart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/track_session.dart';

class GroupStatsBarChart extends StatelessWidget {
  final List<TrackSession> sessions;
  final String metric; // "distance" ou "duration"

  const GroupStatsBarChart({
    super.key,
    required this.sessions,
    this.metric = 'distance',
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text('Aucune donnée à afficher'),
      );
    }

    final data = _prepareData();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric == 'distance' ? 'Distance par session (km)' : 'Durée par session (min)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.isEmpty ? 10 : data.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          metric == 'distance'
                              ? '${rod.toY.toStringAsFixed(1)} km'
                              : '${rod.toY.toStringAsFixed(0)} min',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sessions.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'S${value.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: data.isEmpty ? 1 : null,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    data.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data[index],
                          color: _getBarColor(index),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  List<double> _prepareData() {
    return sessions.map((session) {
      if (session.summary == null) return 0.0;
      
      if (metric == 'distance') {
        return session.summary!.distanceM / 1000; // km
      } else {
        return session.summary!.durationSec / 60; // minutes
      }
    }).toList();
  }

  Color _getBarColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  Widget _buildLegend() {
    final total = sessions.fold<double>(
      0,
      (sum, session) {
        if (session.summary == null) return sum;
        if (metric == 'distance') {
          return sum + (session.summary!.distanceM / 1000);
        } else {
          return sum + (session.summary!.durationSec / 60);
        }
      },
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem(
          'Sessions',
          sessions.length.toString(),
          Icons.route,
        ),
        _buildLegendItem(
          'Total',
          metric == 'distance'
              ? '${total.toStringAsFixed(1)} km'
              : '${total.toStringAsFixed(0)} min',
          Icons.analytics,
        ),
        _buildLegendItem(
          'Moyenne',
          metric == 'distance'
              ? '${(total / sessions.length).toStringAsFixed(1)} km'
              : '${(total / sessions.length).toStringAsFixed(0)} min',
          Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
