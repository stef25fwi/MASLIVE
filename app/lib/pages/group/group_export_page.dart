// Page exports CSV/JSON

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/track_session.dart';
import '../../services/group/group_download.dart';
import '../../services/group/group_tracking_service.dart';
import '../../services/group/group_export_service.dart';
import '../../ui/snack/top_snack_bar.dart';

class GroupExportPage extends StatefulWidget {
  final String adminGroupId;
  final String? uid;

  const GroupExportPage({
    super.key,
    required this.adminGroupId,
    this.uid,
  });

  @override
  State<GroupExportPage> createState() => _GroupExportPageState();
}

class _GroupExportPageState extends State<GroupExportPage> {
  final _trackingService = GroupTrackingService.instance;
  final _exportService = GroupExportService.instance;

  bool _isExporting = false;

  Future<void> _exportSession(TrackSession session, String format) async {
    setState(() => _isExporting = true);
    try {
      String content;
      String fileName;

      if (format == 'CSV') {
        content = await _exportService.exportSessionToCSV(
          widget.adminGroupId,
          session.id,
        );
        fileName = 'session_${session.id}.csv';
      } else {
        content = await _exportService.exportSessionToJSON(
          widget.adminGroupId,
          session.id,
        );
        fileName = 'session_${session.id}.json';
      }

      downloadTextFile(
        fileName: fileName,
        content: content,
        mimeType: format == 'CSV' ? 'text/csv' : 'application/json',
      );

      await Clipboard.setData(ClipboardData(text: content));
      await Share.share(content, subject: 'Export session $format');

      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Export $format réussi')),
        );
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAllSessions(String format) async {
    setState(() => _isExporting = true);
    try {
      final sessions = await _trackingService
          .streamGroupSessions(widget.adminGroupId)
          .first;

      String content;
      String fileName;

      if (format == 'CSV') {
        content = await _exportService.exportSessionsSummaryToCSV(sessions);
        fileName = 'sessions_summary.csv';
      } else {
        content = await _exportService.exportMultipleSessionsToJSON(
          widget.adminGroupId,
          sessions,
        );
        fileName = 'sessions_all.json';
      }

      downloadTextFile(
        fileName: fileName,
        content: content,
        mimeType: format == 'CSV' ? 'text/csv' : 'application/json',
      );

      await Clipboard.setData(ClipboardData(text: content));
      await Share.share(content, subject: 'Export toutes sessions $format');

      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Export global $format réussi')),
        );
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exports'),
      ),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export global',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _exportAllSessions('CSV'),
                                icon: const Icon(Icons.table_chart),
                                label: const Text('CSV'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _exportAllSessions('JSON'),
                                icon: const Icon(Icons.code),
                                label: const Text('JSON'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sessions individuelles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<TrackSession>>(
                  stream: widget.uid != null
                      ? _trackingService.streamUserSessions(widget.adminGroupId, widget.uid!)
                      : _trackingService.streamGroupSessions(widget.adminGroupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Aucune session')),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final session = snapshot.data![index];
                        return Card(
                          child: ListTile(
                            title: Text('Session ${session.id.substring(0, 8)}'),
                            subtitle: session.summary != null
                                ? Text('${session.summary!.distanceKm} km')
                                : const Text('En cours'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.table_chart),
                                  onPressed: () => _exportSession(session, 'CSV'),
                                  tooltip: 'CSV',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.code),
                                  onPressed: () => _exportSession(session, 'JSON'),
                                  tooltip: 'JSON',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}
