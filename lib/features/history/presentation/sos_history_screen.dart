import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../data/datasources/history_remote_data_source.dart';
import 'history_screen.dart';
import 'report_detail_screen.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _historyDataSource = sl<HistoryRemoteDataSource>();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _sosHistory = [];

  final Map<dynamic, String> _addressCache = {};

  Future<String> _getAddress(Map<String, dynamic> item, int index) async {
    final id = item['id'] ?? index;
    if (_addressCache.containsKey(id)) {
      return _addressCache[id]!;
    }

    String defaultLocation = 'Lokasi tidak diketahui';
    if (item['lokasi_sos'] is Map) {
      final loc = item['lokasi_sos'] as Map;
      defaultLocation = loc['alamat']?.toString() ?? 'Lokasi tidak diketahui';
    } else if (item['lokasi'] is Map) {
      final loc = item['lokasi'] as Map;
      defaultLocation = loc['alamat']?.toString() ?? 'Lokasi tidak diketahui';
    } else if (item['lokasi_sos'] != null) {
      defaultLocation = item['lokasi_sos'].toString();
    } else if (item['lokasi'] != null) {
      defaultLocation = item['lokasi'].toString();
    }

    if (defaultLocation.contains('alamat:')) {
      final alamatMatch =
          RegExp(r'alamat:\s*([^,}]+)').firstMatch(defaultLocation);
      if (alamatMatch != null) {
        defaultLocation = alamatMatch.group(1)!.trim();
      }
    }

    final hasLatLonOnly = defaultLocation.toLowerCase().contains('latitude') ||
        defaultLocation.toLowerCase().contains('lokasi') ||
        defaultLocation.isEmpty ||
        defaultLocation == 'Lokasi tidak diketahui';

    if (!hasLatLonOnly && defaultLocation.length > 5) {
      _addressCache[id] = defaultLocation;
      return defaultLocation;
    }

    final latVal = item['latitude'] ??
        (item['lokasi'] is Map ? item['lokasi']['latitude'] : null);
    double? latitude;
    if (latVal != null) {
      latitude = (latVal is num)
          ? latVal.toDouble()
          : double.tryParse(latVal.toString());
    } else {
      final latMatch =
          RegExp(r'latitude:\s*(-?\d+\.\d+)').firstMatch(defaultLocation);
      if (latMatch != null) latitude = double.tryParse(latMatch.group(1)!);
    }

    final lngVal = item['longitude'] ??
        (item['lokasi'] is Map ? item['lokasi']['longitude'] : null);
    double? longitude;
    if (lngVal != null) {
      longitude = (lngVal is num)
          ? lngVal.toDouble()
          : double.tryParse(lngVal.toString());
    } else {
      final lngMatch =
          RegExp(r'longitude:\s*(-?\d+\.\d+)').firstMatch(defaultLocation);
      if (lngMatch != null) longitude = double.tryParse(lngMatch.group(1)!);
    }

    if (latitude != null && longitude != null) {
      try {
        final placemarks =
            await Geocoding().placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          final address = addressList.join(', ');
          if (address.isNotEmpty) {
            _addressCache[id] = address;
            return address;
          }
        }
      } catch (_) {}
    }

    _addressCache[id] = defaultLocation;
    return defaultLocation;
  }

  @override
  void initState() {
    super.initState();
    _fetchSosHistory();
  }

  Future<void> _fetchSosHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _historyDataSource.getSosHistory();
      if (mounted) {
        setState(() {
          _sosHistory = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String status, bool isHighContrast) {
    Color bg;
    Color text;
    Border? border;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'selesai':
        bg = isHighContrast ? const Color(0xFF064E3B) : primaryLightTeal;
        text = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        border = isHighContrast
            ? Border.all(color: const Color(0xFF80CBC4), width: 1.2)
            : null;
        icon = CupertinoIcons.checkmark_circle_fill;
        label = 'Selesai';
        break;
      case 'batal':
      case 'dibatalkan':
        bg = isHighContrast ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
        text = isHighContrast ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
        border = isHighContrast
            ? Border.all(color: const Color(0xFF9CA3AF), width: 1.2)
            : null;
        icon = CupertinoIcons.xmark_circle_fill;
        label = 'Dibatalkan';
        break;
      case 'ditangani':
      case 'proses':
        bg = isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        text = isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        border = isHighContrast
            ? Border.all(color: const Color(0xFFFDE68A), width: 1.2)
            : null;
        icon = CupertinoIcons.wrench_fill;
        label = 'Sedang Ditangani';
        break;
      default:
        bg = isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
        text = isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        border = isHighContrast
            ? Border.all(color: const Color(0xFFFCA5A5), width: 1.2)
            : null;
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        label = 'Menunggu Relawan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  HistoryStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return HistoryStatus.selesai;
      case 'ditangani':
      case 'proses':
        return HistoryStatus.ditangani;
      case 'batal':
      case 'dibatalkan':
        return HistoryStatus.dibatalkan;
      default:
        return HistoryStatus.aktif;
    }
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Border? border,
    bool isHighContrast = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: border ?? AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
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
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF8FAFC);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  'Riwayat Khusus SOS',
                  style: TextStyle(
                    color: tealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(color: tealColor),
          ),
          body: RefreshIndicator(
            color: tealColor,
            onRefresh: _fetchSosHistory,
            child: _isLoading
                ? Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: tealColor,
                    ),
                  )
                : _errorMessage != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildCard(
                            isHighContrast: isHighContrast,
                            color: isHighContrast
                                ? const Color(0xFF450A0A)
                                : const Color(0xFFFEF2F2),
                            border: Border.all(
                              color: isHighContrast
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFFCA5A5),
                              width: isHighContrast ? 1.5 : 1.0,
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_circle,
                                  size: 48,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Gagal Memuat Riwayat Darurat',
                                  style: TextStyle(
                                    color: isHighContrast
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF991B1B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isHighContrast
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFB91C1C),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _fetchSosHistory,
                                  icon: const Icon(CupertinoIcons.refresh, size: 18),
                                  label: const Text('Coba Lagi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isHighContrast
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isHighContrast
                                          ? const BorderSide(
                                              color: Color(0xFFFCA5A5),
                                              width: 1.5,
                                            )
                                          : BorderSide.none,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _sosHistory.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 80,
                                  horizontal: 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isHighContrast
                                            ? const Color(0xFF1E2430)
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                        border: isHighContrast
                                            ? Border.all(
                                                color: const Color(0xFF4B5563),
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.bell_slash,
                                        size: 56,
                                        color: isHighContrast
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Belum Ada Riwayat SOS',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Semua sinyal darurat SOS Anda akan tercatat di sini secara aman.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _sosHistory.length,
                            itemBuilder: (context, index) {
                              final item = _sosHistory[index];
                              final id = item['id'] is int
                                  ? item['id'] as int
                                  : int.tryParse(item['id']?.toString() ?? '0') ??
                                      0;
                              final nomorKasus =
                                  item['nomor_kasus']?.toString() ?? 'SOS-$id';
                              final title = item['judul_sos'] ?? 'Darurat SOS';
                              final status = item['status_sos'] ?? 'aktif';
                              final date = item['waktu_sos'] ??
                                  item['created_at'] ??
                                  '';
                              final location = item['lokasi_sos']?.toString() ??
                                  'Lokasi tidak diketahui';
                              final relawan = item['relawan'] != null
                                  ? item['relawan']['name']
                                  : null;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      final double? lat = (item['latitude'] is num)
                                          ? (item['latitude'] as num).toDouble()
                                          : double.tryParse(
                                              item['latitude']?.toString() ?? '');
                                      final double? lng = (item['longitude'] is num)
                                          ? (item['longitude'] as num).toDouble()
                                          : double.tryParse(
                                              item['longitude']?.toString() ?? '');

                                      final resolvedLoc =
                                          _addressCache[id] ?? location;

                                      final historyItem = HistoryItem(
                                        id: id,
                                        nomorKasus: nomorKasus,
                                        type: HistoryType.sos,
                                        status: _mapStatus(status),
                                        title: title,
                                        dateTime: _formatDate(date),
                                        rawDateTime: DateTime.tryParse(date),
                                        location: resolvedLoc,
                                        officerInfo: relawan != null
                                            ? 'Relawan: $relawan'
                                            : null,
                                        description: item['deskripsi_sos'] ??
                                            item['keterangan'] ??
                                            'Panggilan darurat SOS dari pengguna.',
                                        detailButtonLabel: 'Lihat Detail',
                                        imagePlaceholderIcon:
                                            CupertinoIcons
                                                .exclamationmark_triangle_fill,
                                        imageUrl: item['foto_sos_url'] ??
                                            item['foto_url'],
                                        audioUrl: item['audio_sos_url'] ??
                                            item['audio_url'],
                                        latitude: lat,
                                        longitude: lng,
                                      );

                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReportDetailScreen(
                                            item: historyItem,
                                          ),
                                        ),
                                      );
                                      await _fetchSosHistory();
                                    },
                                    child: _buildCard(
                                      isHighContrast: isHighContrast,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 16,
                                                        color: textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      nomorKasus,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusBadge(status, isHighContrast),
                                            ],
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 12),
                                            child: Divider(
                                              height: 1,
                                              color: isHighContrast
                                                  ? const Color(0xFF374151)
                                                  : const Color(0xFFF3F4F6),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: isHighContrast
                                                      ? const Color(0xFF1E3A34)
                                                      : primaryLightTeal,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.clock,
                                                  size: 15,
                                                  color: tealColor,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _formatDate(date),
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: isHighContrast
                                                      ? const Color(0xFF450A0A)
                                                      : const Color(0xFFFEF2F2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  CupertinoIcons.location_solid,
                                                  size: 15,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: FutureBuilder<String>(
                                                  future: _getAddress(item, index),
                                                  builder: (context, snapshot) {
                                                    return Text(
                                                      snapshot.data ?? location,
                                                      style: TextStyle(
                                                        color: textSecondary,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (relawan != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: isHighContrast
                                                        ? const Color(0xFF1E3A34)
                                                        : primaryLightTeal,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.person_fill,
                                                    size: 15,
                                                    color: tealColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Relawan: $relawan',
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Lihat detail kasus',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: tealColor,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                CupertinoIcons.chevron_right,
                                                size: 13,
                                                color: tealColor,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        );
      },
    );
  }
}
