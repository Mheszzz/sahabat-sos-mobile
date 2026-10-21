import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/sos/data/datasources/sos_remote_data_source.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class SosActivitiesSheet extends StatefulWidget {
  final int sosId;

  const SosActivitiesSheet({super.key, required this.sosId});

  static void show(BuildContext context, int sosId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SosActivitiesSheet(sosId: sosId),
    );
  }

  @override
  State<SosActivitiesSheet> createState() => _SosActivitiesSheetState();
}

class _SosActivitiesSheetState extends State<SosActivitiesSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _activities = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _fetchActivities();
    });
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sosDataSource = sl<SosRemoteDataSource>();
      final activities = await sosDataSource.getSosActivities(widget.sosId);

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan jaringan: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Riwayat Aktivitas SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _fetchActivities,
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      )
                    : _activities.isEmpty
                        ? const Center(child: Text('Belum ada aktivitas tercatat.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _activities.length,
                            itemBuilder: (context, index) {
                              final activity = _activities[index];
                              final description = activity['deskripsi'] ?? 'Update status SOS';
                              final createdAt = activity['created_at'] ?? '';
                              final user = activity['user'];
                              final userName = user != null ? (user['nama_lengkap'] ?? user['name'] ?? 'Sistem') : 'Sistem';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00695C),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (index != _activities.length - 1)
                                          Container(
                                            width: 2,
                                            height: 50,
                                            color: Colors.grey.shade300,
                                            margin: const EdgeInsets.only(top: 4),
                                          )
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            description,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Oleh: $userName',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDate(createdAt),
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
