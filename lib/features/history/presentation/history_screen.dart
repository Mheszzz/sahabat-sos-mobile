import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';

import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../data/datasources/history_remote_data_source.dart';
import 'report_detail_screen.dart';

enum HistoryStatus { selesai, ditangani, aktif, dibatalkan }

enum HistoryType { sos, laporan }

class HistoryItem {
  final int id;
  final String? nomorKasus;
  final HistoryType type;
  final HistoryStatus status;
  final String title;
  final String dateTime;
  final DateTime? rawDateTime;
  final String location;
  final String? officerInfo;
  final String? description;
  final String detailButtonLabel;
  final IconData imagePlaceholderIcon;
  final String? imageUrl;
  final String? audioUrl;
  final double? latitude;
  final double? longitude;

  HistoryItem({
    required this.id,
    this.nomorKasus,
    required this.type,
    required this.status,
    required this.title,
    required this.dateTime,
    this.rawDateTime,
    required this.location,
    this.officerInfo,
    this.description,
    required this.detailButtonLabel,
    required this.imagePlaceholderIcon,
    this.imageUrl,
    this.audioUrl,
    this.latitude,
    this.longitude,
  });
}

class HistoryPage extends StatefulWidget {
  final int initialTypeFilter;
  const HistoryPage({super.key, this.initialTypeFilter = 0});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _historyDataSource = sl<HistoryRemoteDataSource>();

  late int _selectedTypeFilter;
  final List<String> _typeFilters = ['Semua', 'SOS', 'Laporan'];

  int _selectedStatusFilter = 0;
  final List<String> _statusFilters = [
    'Semua Status',
    'Menunggu',
    'Ditangani',
    'Selesai',
    'Dibatalkan',
  ];

  bool _isLoading = true;
  List<HistoryItem> _allItems = [];
  String? _errorMessage;

  final Map<int, String> _addressCache = {};

  Future<String> _getAddress(HistoryItem item) async {
    if (_addressCache.containsKey(item.id)) {
      return _addressCache[item.id]!;
    }
    if (item.location.isNotEmpty &&
        item.location != 'Lokasi tidak diketahui' &&
        !item.location.startsWith('Koordinat GPS') &&
        !item.location.startsWith('-') &&
        !item.location.startsWith('latitude')) {
      _addressCache[item.id] = item.location;
      return item.location;
    }

    if (item.latitude != null && item.longitude != null) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          item.latitude!,
          item.longitude!,
        );
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
            _addressCache[item.id] = address;
            return address;
          }
        }
      } catch (_) {}
    }
    _addressCache[item.id] = item.location;
    return item.location;
  }

  int _selectedTimeFilter = 0; // 0: Semua Waktu, 1: 1 Minggu, 2: 1 Bulan, 3: Kustom
  final List<String> _timeFilters = [
    'Semua Waktu',
    '1 Minggu',
    '1 Bulan',
    'Kustom',
  ];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _itemsPerPage = 10;

  Timer? _refreshTimer;
  final List<String> _subscribedChannels = [];

  @override
  void initState() {
    super.initState();
    _selectedTypeFilter = widget.initialTypeFilter;
    _fetchHistory(page: 1);

    // Periodic silent refresh for live status updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && !_isLoading) {
        _fetchHistorySilently();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _unsubscribeAll();
    super.dispose();
  }

  void _unsubscribeAll() {
    for (var channel in _subscribedChannels) {
      WebsocketService.echo?.leave(channel);
    }
    _subscribedChannels.clear();
  }

  Future<void> _fetchHistorySilently() async {
    try {
      final resData = await _historyDataSource.getHistory(
        page: _currentPage,
        perPage: _itemsPerPage,
      );

      if (!mounted) return;

      final List<dynamic> allData = [];
      int lastPage = resData['last_page'] ?? _totalPages;
      int total = resData['total'] ?? _totalItems;
      final d = resData['data'];
      if (d is List) {
        allData.addAll(d);
      } else if (d is Map && d['data'] is List) {
        allData.addAll(d['data']);
        lastPage = d['last_page'] ?? lastPage;
        total = d['total'] ?? total;
      }

      final items = allData.map((item) => _mapToHistoryItem(item)).toList();
      items.sort((a, b) {
        if (a.rawDateTime != null && b.rawDateTime != null) {
          return b.rawDateTime!.compareTo(a.rawDateTime!);
        }
        return b.dateTime.compareTo(a.dateTime);
      });

      setState(() {
        _allItems = items;
        _totalPages = lastPage > 0 ? lastPage : 1;
        _totalItems = total > 0 ? total : items.length;
      });
      _updateWebsocketSubscriptions();
    } catch (_) {}
  }

  void _updateWebsocketSubscriptions() {
    if (WebsocketService.echo == null) return;

    for (var item in _allItems) {
      if (item.type == HistoryType.sos && item.status != HistoryStatus.selesai) {
        final channelName = 'sos.${item.id}';
        if (!_subscribedChannels.contains(channelName)) {
          _subscribedChannels.add(channelName);
          WebsocketService.echo?.private(channelName).listen(
            '.SOSUpdateStatus',
            (e) {
              if (mounted) _fetchHistorySilently();
            },
          );
        }
      }
    }
  }

  Future<void> _fetchHistory({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resData = await _historyDataSource.getHistory(
        page: page,
        perPage: _itemsPerPage,
      );

      final List<dynamic> allData = [];
      int lastPage = resData['last_page'] ?? 1;
      int total = resData['total'] ?? 0;
      final d = resData['data'];
      if (d is List) {
        allData.addAll(d);
      } else if (d is Map && d['data'] is List) {
        allData.addAll(d['data']);
        lastPage = d['last_page'] ?? lastPage;
        total = d['total'] ?? total;
      }

      final items = allData.map((item) => _mapToHistoryItem(item)).toList();
      items.sort((a, b) {
        if (a.rawDateTime != null && b.rawDateTime != null) {
          return b.rawDateTime!.compareTo(a.rawDateTime!);
        }
        return b.dateTime.compareTo(a.dateTime);
      });

      if (!mounted) return;

      setState(() {
        _allItems = items;
        _currentPage = page;
        _totalPages = lastPage > 0 ? lastPage : 1;
        _totalItems = total > 0 ? total : items.length;
        _isLoading = false;
      });

      _updateWebsocketSubscriptions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  HistoryItem _mapToHistoryItem(dynamic data) {
    String extractString(dynamic value, [String defaultVal = 'Lainnya']) {
      if (value == null) return defaultVal;
      if (value is Map) {
        return (value['nama_kategori'] ??
                value['nama'] ??
                value['name'] ??
                defaultVal)
            .toString();
      }
      return value.toString();
    }

    final String rawKategori = extractString(
      data['kategori'] ?? data['kategori_laporan'],
      'Lainnya',
    );
    final String kategori = rawKategori
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    final String statusStr = (data['status'] ?? data['status_sos'] ?? 'aktif')
        .toString()
        .toLowerCase();

    HistoryType type = HistoryType.laporan;
    if (data['tipe']?.toString().toLowerCase() == 'sos' ||
        data['jenis']?.toString().toLowerCase() == 'sos' ||
        kategori.toLowerCase() == 'sos' ||
        kategori.toLowerCase() == 'sos darurat' ||
        kategori.toLowerCase().contains('sos') ||
        data['status_sos'] != null ||
        data['waktu_sos'] != null) {
      type = HistoryType.sos;
    }

    HistoryStatus status = HistoryStatus.aktif;
    if (statusStr == 'selesai') {
      status = HistoryStatus.selesai;
    } else if (statusStr == 'ditangani') {
      status = HistoryStatus.ditangani;
    } else if (statusStr == 'dibatalkan' || statusStr == 'batal') {
      status = HistoryStatus.dibatalkan;
    }

    final String? relawanName = data['relawan']?['name'];
    final String? officerInfo = relawanName != null ? 'Relawan $relawanName' : null;

    final String rawDate = (data['waktu'] ??
            data['waktu_laporan'] ??
            data['waktu_sos'] ??
            data['created_at'] ??
            '')
        .toString();
    String displayDate = rawDate;
    DateTime? rawParsedDate;
    try {
      if (rawDate.isNotEmpty) {
        String parseableDate = rawDate.replaceAll(' ', 'T');
        if (!parseableDate.endsWith('Z') &&
            !parseableDate.contains('+') &&
            (!parseableDate.contains('T') ||
                parseableDate.indexOf('-', parseableDate.indexOf('T')) == -1)) {
          parseableDate += 'Z';
        }
        rawParsedDate = DateTime.parse(parseableDate).toLocal();
        final String year = rawParsedDate.year.toString().padLeft(4, '0');
        final String month = rawParsedDate.month.toString().padLeft(2, '0');
        final String day = rawParsedDate.day.toString().padLeft(2, '0');
        final String hour = rawParsedDate.hour.toString().padLeft(2, '0');
        final String minute = rawParsedDate.minute.toString().padLeft(2, '0');
        displayDate = '$year-$month-$day $hour:$minute';
      }
    } catch (_) {
      if (rawDate.length >= 16) {
        displayDate = rawDate.replaceAll('T', ' ').substring(0, 16);
      }
    }

    final String? foto = data['foto_laporan_url']?.toString() ??
        (data['foto_laporan'] ?? data['foto'] ?? data['foto_url'])?.toString();
    final String? audio = data['rekam_suara_url']?.toString() ??
        (data['audio_laporan'] ??
                data['rekam_suara'] ??
                data['rekaman_suara'] ??
                data['audio'])
            ?.toString();

    final String? resolvedImageUrl = foto != null
        ? (foto.startsWith('http')
            ? foto
            : '${ApiConstants.storageUrl}/${foto.replaceFirst('public/', '')}')
        : null;

    final String? resolvedAudioUrl = audio != null
        ? (audio.startsWith('http')
            ? audio
            : '${ApiConstants.storageUrl}/${audio.replaceFirst('public/', '')}')
        : null;

    String locationStr = 'Lokasi tidak diketahui';
    double? lat;
    double? lng;

    if (data['lokasi'] is Map) {
      locationStr = data['lokasi']['alamat']?.toString() ?? 'Lokasi tidak diketahui';
      if (data['lokasi']['latitude'] != null) {
        lat = (data['lokasi']['latitude'] is num)
            ? (data['lokasi']['latitude'] as num).toDouble()
            : double.tryParse(data['lokasi']['latitude'].toString());
      }
      if (data['lokasi']['longitude'] != null) {
        lng = (data['lokasi']['longitude'] is num)
            ? (data['lokasi']['longitude'] as num).toDouble()
            : double.tryParse(data['lokasi']['longitude'].toString());
      }
    } else if (data['lokasi'] != null ||
        data['lokasi_laporan'] != null ||
        data['lokasi_user'] != null) {
      locationStr = (data['lokasi_laporan'] ??
              data['lokasi'] ??
              data['lokasi_user'])
          .toString();
    }

    if (lat == null && data['latitude'] != null) {
      lat = (data['latitude'] is num)
          ? (data['latitude'] as num).toDouble()
          : double.tryParse(data['latitude'].toString());
    }
    if (lng == null && data['longitude'] != null) {
      lng = (data['longitude'] is num)
          ? (data['longitude'] as num).toDouble()
          : double.tryParse(data['longitude'].toString());
    }

    String title;
    if (type == HistoryType.sos) {
      final String customTitle = (data['judul_sos'] ??
              data['sub_judul'] ??
              data['jenis_laporan'] ??
              '')
          .toString();
      if (customTitle.isNotEmpty &&
          customTitle != 'Darurat' &&
          customTitle != 'SOS') {
        title = customTitle;
      } else {
        title = 'SOS Darurat: $kategori';
      }
    } else {
      final String customTitle = (data['sub_judul'] ??
              data['jenis_laporan'] ??
              data['judul'] ??
              '')
          .toString();
      if (customTitle.isNotEmpty) {
        title = customTitle;
      } else {
        title = 'Laporan: $kategori';
      }
    }

    int itemId = 0;
    if (data['id'] is int) {
      itemId = data['id'];
    } else if (data['id'] != null) {
      itemId = int.tryParse(data['id'].toString()) ?? 0;
    }

    final nomorKasus = data['nomor_kasus']?.toString() ??
        (type == HistoryType.sos ? 'SOS-$itemId' : 'LP-$itemId');

    return HistoryItem(
      id: itemId,
      nomorKasus: nomorKasus,
      type: type,
      status: status,
      title: title,
      dateTime: displayDate,
      rawDateTime: rawParsedDate,
      location: locationStr,
      officerInfo: officerInfo,
      description: data['deskripsi']?.toString() ??
          data['deskripsi_sos']?.toString() ??
          data['catatan']?.toString(),
      detailButtonLabel: 'Lihat Detail',
      imagePlaceholderIcon: type == HistoryType.sos
          ? CupertinoIcons.exclamationmark_triangle_fill
          : CupertinoIcons.doc_text,
      imageUrl: resolvedImageUrl,
      audioUrl: resolvedAudioUrl,
      latitude: lat,
      longitude: lng,
    );
  }

  List<HistoryItem> get _filteredItems {
    List<HistoryItem> items = _allItems;

    // Filter Tipe (0: Semua, 1: SOS, 2: Laporan)
    if (_selectedTypeFilter == 1) {
      items = items.where((i) => i.type == HistoryType.sos).toList();
    } else if (_selectedTypeFilter == 2) {
      items = items.where((i) => i.type == HistoryType.laporan).toList();
    }

    // Filter Status (0: Semua Status, 1: Menunggu, 2: Ditangani, 3: Selesai, 4: Dibatalkan)
    if (_selectedStatusFilter == 1) {
      items = items.where((i) => i.status == HistoryStatus.aktif).toList();
    } else if (_selectedStatusFilter == 2) {
      items = items.where((i) => i.status == HistoryStatus.ditangani).toList();
    } else if (_selectedStatusFilter == 3) {
      items = items.where((i) => i.status == HistoryStatus.selesai).toList();
    } else if (_selectedStatusFilter == 4) {
      items = items.where((i) => i.status == HistoryStatus.dibatalkan).toList();
    }

    // Filter Waktu
    if (_selectedTimeFilter != 0) {
      final now = DateTime.now();
      items = items.where((item) {
        final itemDate = item.rawDateTime ??
            DateTime.tryParse(item.dateTime.replaceAll(' ', 'T'));
        if (itemDate == null) return true;
        if (_selectedTimeFilter == 1) {
          return now.difference(itemDate).inDays <= 7;
        } else if (_selectedTimeFilter == 2) {
          return now.difference(itemDate).inDays <= 30;
        } else if (_selectedTimeFilter == 3) {
          if (_customStartDate != null && _customEndDate != null) {
            return itemDate.isAfter(
                  _customStartDate!.subtract(const Duration(days: 1)),
                ) &&
                itemDate.isBefore(
                  _customEndDate!.add(const Duration(days: 1)),
                );
          }
        }
        return true;
      }).toList();
    }

    return items;
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
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
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

        return Scaffold(
          backgroundColor: currentBg,
          appBar: _buildAppBar(isHighContrast),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _fetchHistory(page: _currentPage),
              color: tealColor,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  Text(
                    'Riwayat Kasus & Laporan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isHighContrast
                          ? Colors.white
                          : const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_totalItems > 0 ? _totalItems : _allItems.length} catatan riwayat bantuan',
                    style: TextStyle(
                      fontSize: 13,
                      color: isHighContrast
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTypeFilterTabs(isHighContrast),
                  const SizedBox(height: 12),
                  _buildStatusFilterChips(isHighContrast),
                  const SizedBox(height: 12),
                  _buildTimeFilterChips(isHighContrast),
                  const SizedBox(height: 18),
                  if (_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: CupertinoActivityIndicator(
                          radius: 16,
                          color: tealColor,
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState(isHighContrast)
                  else if (_filteredItems.isEmpty)
                    _buildEmptyState(isHighContrast)
                  else
                    ..._filteredItems
                        .map((item) => _buildHistoryCard(item, isHighContrast)),
                  if (!_isLoading &&
                      _errorMessage == null &&
                      _filteredItems.isNotEmpty &&
                      _totalPages > 1)
                    _buildPagination(isHighContrast),
                  const SizedBox(height: 12),
                  _buildEncryptedFooter(isHighContrast),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    return AppBar(
      backgroundColor: isHighContrast ? Colors.black : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: tealColor),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            'Sahabat SOS',
            style: TextStyle(
              color: tealColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterTabs(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final selectedBg = isHighContrast ? const Color(0xFF1E3A34) : primaryTeal;
    final unselectedBg = AccessibleColors.cardBackground(isHighContrast);

    final icons = [
      CupertinoIcons.tray_fill,
      CupertinoIcons.exclamationmark_triangle_fill,
      CupertinoIcons.doc_text_fill,
    ];

    int getCount(int index) {
      if (index == 0) return _allItems.length;
      if (index == 1) {
        return _allItems.where((i) => i.type == HistoryType.sos).length;
      }
      if (index == 2) {
        return _allItems.where((i) => i.type == HistoryType.laporan).length;
      }
      return 0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_typeFilters.length, (index) {
          final isSelected = _selectedTypeFilter == index;
          final count = getCount(index);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'history_filter_type_$index',
                  speakText: "Filter ${_typeFilters[index]}",
                  hintText: "Tekan sekali lagi untuk memilih filter ini.",
                  onAction: () {
                    setState(() {
                      _selectedTypeFilter = index;
                    });
                  },
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.cardBorderColor(isHighContrast),
                    width: isSelected || isHighContrast ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: tealColor.withValues(alpha: 0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : const [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      size: 16,
                      color: isSelected ? Colors.white : tealColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _typeFilters[index],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AccessibleColors.textPrimary(isHighContrast),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : (isHighContrast
                                ? const Color(0xFF263238)
                                : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AccessibleColors.textSecondary(isHighContrast),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatusFilterChips(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final selectedBg =
        isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal;
    final unselectedBg = AccessibleColors.cardBackground(isHighContrast);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_statusFilters.length, (index) {
          final isSelected = _selectedStatusFilter == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'history_filter_status_$index',
                  speakText: "Status ${_statusFilters[index]}",
                  hintText: "Tekan sekali lagi untuk memilih status ini.",
                  onAction: () {
                    setState(() {
                      _selectedStatusFilter = index;
                    });
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.cardBorderColor(isHighContrast),
                    width: isSelected || isHighContrast ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  _statusFilters[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.textSecondary(isHighContrast),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeFilterChips(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final selectedBg =
        isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal;
    final unselectedBg = AccessibleColors.cardBackground(isHighContrast);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_timeFilters.length, (index) {
          final isSelected = _selectedTimeFilter == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'history_filter_time_$index',
                  speakText: "Rentang waktu ${_timeFilters[index]}",
                  hintText: "Tekan sekali lagi untuk memilih rentang waktu ini.",
                  onAction: () async {
                    if (index == 3) {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: tealColor,
                                onPrimary: Colors.white,
                                onSurface: isHighContrast
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _customStartDate = picked.start;
                          _customEndDate = picked.end;
                          _selectedTimeFilter = index;
                        });
                      }
                    } else {
                      setState(() {
                        _selectedTimeFilter = index;
                      });
                    }
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.cardBorderColor(isHighContrast),
                    width: isSelected || isHighContrast ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      index == 3 && isSelected && _customStartDate != null
                          ? CupertinoIcons.calendar
                          : CupertinoIcons.time,
                      size: 14,
                      color: isSelected
                          ? tealColor
                          : AccessibleColors.textSecondary(isHighContrast),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      index == 3 && isSelected && _customStartDate != null
                          ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                          : _timeFilters[index],
                      style: TextStyle(
                        color: isSelected
                            ? tealColor
                            : AccessibleColors.textSecondary(isHighContrast),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPagination(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            onPressed: _currentPage > 1
                ? () {
                    AccessibilityService.instance.hapticSelection();
                    _fetchHistory(page: _currentPage - 1);
                  }
                : null,
            color: _currentPage > 1
                ? tealColor
                : const Color(0xFF9CA3AF),
          ),
          ...List.generate(_totalPages, (index) {
            final page = index + 1;
            if (_totalPages > 5) {
              if (page != 1 &&
                  page != _totalPages &&
                  (page < _currentPage - 1 || page > _currentPage + 1)) {
                if (page == 2 || page == _totalPages - 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '...',
                      style: TextStyle(
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
            }

            final isSelected = _currentPage == page;
            return GestureDetector(
              onTap: () {
                AccessibilityService.instance.hapticSelection();
                _fetchHistory(page: page);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? tealColor : defaultBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.cardBorderColor(isHighContrast),
                    width: isSelected || isHighContrast ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AccessibleColors.textPrimary(isHighContrast),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_right, size: 18),
            onPressed: _currentPage < _totalPages
                ? () {
                    AccessibilityService.instance.hapticSelection();
                    _fetchHistory(page: _currentPage + 1);
                  }
                : null,
            color: _currentPage < _totalPages
                ? tealColor
                : const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isHighContrast) {
    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.all(24),
      color: isHighContrast ? const Color(0xFF3B1515) : const Color(0xFFFEF2F2),
      border: Border.all(
        color: isHighContrast ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5),
        width: isHighContrast ? 1.5 : 1.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFDC2626),
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            'Gagal Memuat Riwayat',
            style: TextStyle(
              color: isHighContrast ? Colors.white : const Color(0xFF991B1B),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isHighContrast
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFB91C1C),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _fetchHistory(page: _currentPage),
            icon: const Icon(CupertinoIcons.refresh, size: 16),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isHighContrast) {
    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.tray,
            size: 54,
            color: isHighContrast
                ? const Color(0xFF6B7280)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Riwayat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AccessibleColors.textPrimary(isHighContrast),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Laporan darurat atau panggilan SOS Anda akan tercatat rapi di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AccessibleColors.textSecondary(isHighContrast),
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _getCategoryIconAndColor(
    String title,
    bool isSos,
  ) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('pendamping')) {
      return (
        icon: CupertinoIcons.person_2_fill,
        color: const Color(0xFF1D4ED8),
      );
    } else if (lowerTitle.contains('medis') ||
        lowerTitle.contains('obat') ||
        lowerTitle.contains('ambulans')) {
      return (
        icon: CupertinoIcons.bandage_fill,
        color: const Color(0xFFDC2626),
      );
    } else if (lowerTitle.contains('ancaman') ||
        lowerTitle.contains('bahaya')) {
      return (
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: const Color(0xFFEA580C),
      );
    } else if (lowerTitle.contains('tersesat')) {
      return (
        icon: CupertinoIcons.compass_fill,
        color: const Color(0xFF0F766E),
      );
    } else if (lowerTitle.contains('aksesibilitas')) {
      return (
        icon: CupertinoIcons.person_crop_circle_fill,
        color: const Color(0xFF7E22CE),
      );
    } else if (lowerTitle.contains('lainnya')) {
      return (
        icon: CupertinoIcons.ellipsis_circle_fill,
        color: const Color(0xFF475569),
      );
    }

    return isSos
        ? (
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            color: const Color(0xFFDC2626),
          )
        : (icon: CupertinoIcons.doc_text_fill, color: primaryTeal);
  }

  Widget _buildHistoryCard(HistoryItem item, bool isHighContrast) {
    final isSos = item.type == HistoryType.sos;
    final isSelesai = item.status == HistoryStatus.selesai;
    final isAktif = item.status == HistoryStatus.aktif;
    final isDibatalkan = item.status == HistoryStatus.dibatalkan;
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    String statusLabel = 'Sedang Ditangani';
    Color statusBg =
        isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    Color statusText =
        isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFB45309);

    if (isAktif) {
      statusLabel = 'Menunggu Relawan';
      statusBg =
          isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
      statusText =
          isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    } else if (isSelesai) {
      statusLabel = 'Selesai';
      statusBg = isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal;
      statusText = tealColor;
    } else if (isDibatalkan) {
      statusLabel = 'Dibatalkan';
      statusBg =
          isHighContrast ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
      statusText =
          isHighContrast ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    }

    final categoryMeta = _getCategoryIconAndColor(item.title, isSos);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AccessibilityService.instance.hapticSelection();
            _navigateToDetail(item);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: categoryMeta.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryMeta.icon,
                        color: categoryMeta.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AccessibleColors.textPrimary(isHighContrast),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (item.nomorKasus != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHighContrast
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isHighContrast
                                          ? const Color(0xFF475569)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    item.nomorKasus!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isHighContrast
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              Text(
                                item.dateTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AccessibleColors.textSecondary(
                                      isHighContrast),
                                ),
                              ),
                              _buildStatusBadge(
                                statusLabel,
                                statusBg,
                                statusText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: isHighContrast
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.location_solid,
                      size: 15,
                      color: AccessibleColors.textSecondary(isHighContrast),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FutureBuilder<String>(
                        future: _getAddress(item),
                        builder: (context, snapshot) {
                          final addressText = snapshot.data ?? item.location;
                          return Text(
                            addressText.isNotEmpty
                                ? addressText
                                : 'Lokasi GPS Tercatat',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AccessibleColors.textSecondary(
                                  isHighContrast),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (item.officerInfo != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.person_solid,
                        size: 15,
                        color: tealColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.officerInfo!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tealColor,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.text_quote,
                        size: 15,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color:
                                AccessibleColors.textSecondary(isHighContrast),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      AccessibilityService.instance.handleTalkbackTap(
                        id: 'history_detail_${item.id}_${item.nomorKasus}',
                        speakText: "Lihat detail ${item.title}",
                        hintText: "Tekan sekali lagi untuk membuka rincian kasus.",
                        onAction: () => _navigateToDetail(item),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tealColor,
                      side: BorderSide(
                        color: isHighContrast
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFE5E7EB),
                        width: isHighContrast ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Lihat Detail Kasus',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(HistoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReportDetailScreen(item: item)),
    );
  }

  Widget _buildStatusBadge(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEncryptedFooter(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF1E3A34)
                  : primaryLightTeal,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              CupertinoIcons.shield_fill,
              color: tealColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Terenkripsi & Aman',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Seluruh rekaman darurat, lampiran foto, koordinat GPS, dan data penanganan terlindungi sesuai standar privasi darurat.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AccessibleColors.textSecondary(isHighContrast),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
