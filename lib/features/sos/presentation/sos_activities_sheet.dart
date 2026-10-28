import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
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
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final sheetBg = AccessibleColors.cardBackground(isHighContrast);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : const Color(0xFF00695C);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: isHighContrast
                ? const Border(
                    top: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                    left: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                    right: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                  )
                : null,
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
                  color: isHighContrast
                      ? const Color(0xFF4B5563)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Riwayat Aktivitas SOS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              Divider(
                height: 30,
                color: isHighContrast
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CupertinoActivityIndicator(
                          radius: 16,
                          color: tealColor,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: isHighContrast
                                        ? const Color(0xFFFCA5A5)
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: _fetchActivities,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isHighContrast
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF00695C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: isHighContrast
                                          ? const BorderSide(
                                              color: Color(0xFF80CBC4),
                                              width: 1.5,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: const Text('Coba Lagi'),
                                )
                              ],
                            ),
                          )
                        : _activities.isEmpty
                            ? Center(
                                child: Text(
                                  'Belum ada aktivitas tercatat.',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                itemCount: _activities.length,
                                itemBuilder: (context, index) {
                                  final activity = _activities[index];
                                  final description =
                                      activity['deskripsi'] ??
                                          'Update status SOS';
                                  final createdAt =
                                      activity['created_at'] ?? '';
                                  final user = activity['user'];
                                  final userName = user != null
                                      ? (user['nama_lengkap'] ??
                                          user['name'] ??
                                          'Sistem')
                                      : 'Sistem';

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: tealColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            if (index !=
                                                _activities.length - 1)
                                              Container(
                                                width: 2,
                                                height: 50,
                                                color: isHighContrast
                                                    ? const Color(0xFF374151)
                                                    : Colors.grey.shade300,
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                              )
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                description,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Oleh: $userName',
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatDate(createdAt),
                                                style: TextStyle(
                                                  color: textSecondary,
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
      },
    );
  }
}
