import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'dart:async';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:geocoding/geocoding.dart';
import 'report_detail_screen.dart';

enum HistoryStatus { selesai, ditangani, aktif, dibatalkan }

enum HistoryType { sos, laporan }

class HistoryItem {
  final int id;
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
    // Jika lokasi sudah berupa teks alamat yang jelas, gunakan langsung tanpa geocoding
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
        final placemarks = await Geocoding().placemarkFromCoordinates(item.latitude!, item.longitude!);
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
      } catch (e) {
        // Fallback to item.location if geocoding fails
      }
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
    
    // Fallback polling untuk Laporan
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
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final role = prefs.getString('user_role');
      final dio = GetIt.instance<Dio>();

      final headers = {if (token != null) 'Authorization': 'Bearer $token'};
      String endpoint = role == 'relawan' ? ApiConstants.riwayatRelawan : ApiConstants.riwayatPengguna;

      final response = await dio.get(
        '$endpoint?page=$_currentPage&per_page=$_itemsPerPage',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && mounted) {
        final resData = response.data;
        List<dynamic> allData = [];
        int lastPage = _totalPages;
        int total = _totalItems;

        if (resData is Map) {
          lastPage = resData['last_page'] ?? _totalPages;
          total = resData['total'] ?? _totalItems;
          final d = resData['data'];
          if (d is List) {
            allData.addAll(d);
          } else if (d is Map && d['data'] is List) {
            allData.addAll(d['data']);
            lastPage = d['last_page'] ?? lastPage;
            total = d['total'] ?? total;
          }
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
      }
    } catch (e) {
      // Abaikan error saat silent refresh
    }
  }

  void _updateWebsocketSubscriptions() {
    if (WebsocketService.echo == null) return;
    
    for (var item in _allItems) {
      if (item.type == HistoryType.sos && item.status != HistoryStatus.selesai) {
        final channelName = 'sos.${item.id}';
        if (!_subscribedChannels.contains(channelName)) {
          _subscribedChannels.add(channelName);
          WebsocketService.echo?.private(channelName).listen('.SOSUpdateStatus', (e) {
             if (mounted) _fetchHistorySilently();
          });
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
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final role = prefs.getString('user_role');
      final dio = GetIt.instance<Dio>();

      final headers = {if (token != null) 'Authorization': 'Bearer $token'};

      String endpoint = ApiConstants.riwayatPengguna;
      if (role == 'relawan') {
        endpoint = ApiConstants.riwayatRelawan;
      }

      final response = await dio.get(
        '$endpoint?page=$page&per_page=$_itemsPerPage',
        options: Options(headers: headers),
      );

      List<dynamic> allData = [];
      int lastPage = 1;
      int total = 0;

      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is Map) {
          lastPage = resData['last_page'] ?? 1;
          total = resData['total'] ?? 0;
          final d = resData['data'];
          if (d is List) {
            allData.addAll(d);
          } else if (d is Map && d['data'] is List) {
            allData.addAll(d['data']);
            lastPage = d['last_page'] ?? lastPage;
            total = d['total'] ?? total;
          }
        }
      }

      final items = allData.map((item) => _mapToHistoryItem(item)).toList();

      // Sort items by date descending (menggunakan DateTime)
      items.sort((a, b) {
        if (a.rawDateTime != null && b.rawDateTime != null) {
          return b.rawDateTime!.compareTo(a.rawDateTime!);
        }
        return b.dateTime.compareTo(a.dateTime);
      });

      setState(() {
        _allItems = items;
        _currentPage = page;
        _totalPages = lastPage > 0 ? lastPage : 1;
        _totalItems = total > 0 ? total : items.length;
        _isLoading = false;
      });
      
      _updateWebsocketSubscriptions();
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response != null
            ? 'Error dari server: ${e.response?.statusCode}'
            : 'Gagal terhubung ke server. Pastikan IP backend benar.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan sistem: $e';
        _isLoading = false;
      });
    }
  }

  HistoryItem _mapToHistoryItem(dynamic data) {
    String extractString(dynamic value, [String defaultVal = 'Lainnya']) {
      if (value == null) return defaultVal;
      if (value is Map) {
        return (value['nama_kategori'] ?? value['nama'] ?? value['name'] ?? defaultVal).toString();
      }
      return value.toString();
    }
    
    String rawKategori = extractString(data['kategori'] ?? data['kategori_laporan'], 'Lainnya');
    String kategori = rawKategori
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    String statusStr = (data['status'] ?? data['status_sos'] ?? 'aktif').toString().toLowerCase();

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

    String? relawanName = data['relawan']?['name'];
    String? officerInfo = relawanName != null ? 'Relawan $relawanName' : null;

    String rawDate =
        (data['waktu'] ?? data['waktu_laporan'] ?? data['waktu_sos'] ?? data['created_at'] ?? '').toString();
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
        String year = rawParsedDate.year.toString().padLeft(4, '0');
        String month = rawParsedDate.month.toString().padLeft(2, '0');
        String day = rawParsedDate.day.toString().padLeft(2, '0');
        String hour = rawParsedDate.hour.toString().padLeft(2, '0');
        String minute = rawParsedDate.minute.toString().padLeft(2, '0');
        displayDate = '$year-$month-$day $hour:$minute';
      }
    } catch (e) {
      if (rawDate.length >= 16) {
        displayDate = rawDate.replaceAll('T', ' ').substring(0, 16);
      }
    }

    // Resolusi media foto & audio
    String? foto = data['foto_laporan_url']?.toString() ??
        (data['foto_laporan'] ?? data['foto'] ?? data['foto_url'])?.toString();
    String? audio = data['rekam_suara_url']?.toString() ??
        (data['audio_laporan'] ??
            data['rekam_suara'] ??
            data['rekaman_suara'] ??
            data['audio'])?.toString();

    String? resolvedImageUrl = foto != null
        ? (foto.startsWith('http')
            ? foto
            : '${ApiConstants.storageUrl}/${foto.replaceFirst('public/', '')}')
        : null;

    String? resolvedAudioUrl = audio != null
        ? (audio.startsWith('http')
            ? audio
            : '${ApiConstants.storageUrl}/${audio.replaceFirst('public/', '')}')
        : null;

    // Parsing lokasi bersih (dukung Map atau String tanpa regex potong koma)
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
    } else if (data['lokasi'] != null || data['lokasi_laporan'] != null || data['lokasi_user'] != null) {
      locationStr = (data['lokasi_laporan'] ?? data['lokasi'] ?? data['lokasi_user']).toString();
    }

    if (lat == null && data['latitude'] != null) {
      lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : double.tryParse(data['latitude'].toString());
    }
    if (lng == null && data['longitude'] != null) {
      lng = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : double.tryParse(data['longitude'].toString());
    }

    // Judul kasus asli
    String title;
    if (type == HistoryType.sos) {
      String customTitle = (data['judul_sos'] ?? data['sub_judul'] ?? data['jenis_laporan'] ?? '').toString();
      if (customTitle.isNotEmpty && customTitle != 'Darurat' && customTitle != 'SOS') {
        title = customTitle;
      } else {
        title = 'SOS Darurat: $kategori';
      }
    } else {
      String customTitle = (data['sub_judul'] ?? data['jenis_laporan'] ?? data['judul'] ?? '').toString();
      if (customTitle.isNotEmpty) {
        title = customTitle;
      } else {
        title = 'Laporan: $kategori';
      }
    }

    return HistoryItem(
      id: data['id'] is int ? data['id'] : int.tryParse(data['id'].toString()) ?? 0,
      type: type,
      status: status,
      title: title,
      dateTime: displayDate,
      rawDateTime: rawParsedDate,
      location: locationStr,
      description: data['deskripsi']?.toString(),
      officerInfo: officerInfo,
      detailButtonLabel: type == HistoryType.sos
          ? 'Lihat Detail SOS'
          : 'Lihat Detail Laporan',
      imagePlaceholderIcon: type == HistoryType.sos
          ? CupertinoIcons.map
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
        final itemDate = item.rawDateTime ?? DateTime.tryParse(item.dateTime.replaceAll(' ', 'T'));
        if (itemDate == null) return true;
        if (_selectedTimeFilter == 1) {
          // 1 Minggu
          return now.difference(itemDate).inDays <= 7;
        } else if (_selectedTimeFilter == 2) {
          // 1 Bulan
          return now.difference(itemDate).inDays <= 30;
        } else if (_selectedTimeFilter == 3) {
          // Kustom
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

  List<HistoryItem> get _paginatedItems => _filteredItems;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _fetchHistory(page: _currentPage),
            color: primaryTeal,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Text(
                  'Riwayat Kasus & Laporan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_totalItems > 0 ? _totalItems : _allItems.length} catatan riwayat',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                _buildTypeFilterTabs(),
                const SizedBox(height: 12),
                _buildStatusFilterChips(),
                const SizedBox(height: 12),
                _buildTimeFilterChips(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredItems.map((item) => _buildHistoryCard(item)),
                if (!_isLoading &&
                    _errorMessage == null &&
                    _filteredItems.isNotEmpty &&
                    _totalPages > 1)
                  _buildPagination(),
                const SizedBox(height: 8),
                _buildEncryptedFooter(),
                const SizedBox(height: 80), // Make space for the bottom nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          const Text(
            'Sahabat SOS',
            style: TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterTabs() {
    final icons = [
      CupertinoIcons.tray_fill,
      CupertinoIcons.exclamationmark_triangle_fill,
      CupertinoIcons.doc_text,
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
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTypeFilter = index;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00695C) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      size: 18,
                      color: isSelected ? Colors.white : primaryTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _typeFilters[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white24
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
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

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_statusFilters.length, (index) {
          final isSelected = _selectedStatusFilter == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedStatusFilter = index;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _statusFilters[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? primaryTeal : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_timeFilters.length, (index) {
          final isSelected = _selectedTimeFilter == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () async {
                if (index == 3) {
                  // Kustom
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          scaffoldBackgroundColor: Colors.transparent,
                          appBarTheme: const AppBarTheme(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            iconTheme: IconThemeData(color: Colors.black87),
                            actionsIconTheme: IconThemeData(color: primaryTeal),
                          ),
                          colorScheme: const ColorScheme.light(
                            primary: primaryTeal,
                            onPrimary: Colors.white,
                            onSurface: Colors.black87,
                            surface: Colors.transparent,
                            onSurfaceVariant: Colors.black54,
                          ),
                          datePickerTheme: const DatePickerThemeData(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            headerBackgroundColor: Colors.transparent,
                          ),
                          dialogTheme: const DialogThemeData(
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: child!,
                          ),
                        ),
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryTeal.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    if (index == 3 && isSelected && _customStartDate != null)
                      const Icon(
                        CupertinoIcons.calendar,
                        size: 14,
                        color: primaryTeal,
                      )
                    else
                      Icon(
                        CupertinoIcons.time,
                        size: 14,
                        color: isSelected ? primaryTeal : Colors.grey.shade500,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      index == 3 && isSelected && _customStartDate != null
                          ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                          : _timeFilters[index],
                      style: TextStyle(
                        color: isSelected ? primaryTeal : Colors.grey.shade600,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
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

  Widget _buildPagination() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _fetchHistory(page: _currentPage - 1)
                : null,
            color: _currentPage > 1 ? primaryTeal : Colors.grey,
          ),
          ...List.generate(_totalPages, (index) {
            final page = index + 1;
            if (_totalPages > 5) {
              if (page != 1 &&
                  page != _totalPages &&
                  (page < _currentPage - 1 || page > _currentPage + 1)) {
                if (page == 2 || page == _totalPages - 1) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: Colors.grey)),
                  );
                }
                return const SizedBox.shrink();
              }
            }

            final isSelected = _currentPage == page;
            return GestureDetector(
              onTap: () => _fetchHistory(page: page),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _fetchHistory(page: _currentPage + 1)
                : null,
            color: _currentPage < _totalPages ? primaryTeal : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red.shade400,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Terjadi Kesalahan',
            style: TextStyle(
              color: Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchHistory,
            icon: const Icon(CupertinoIcons.refresh, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.folder,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada riwayat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Laporan yang Anda kirim akan muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
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
        color: const Color(0xFF1565C0),
      );
    } else if (lowerTitle.contains('medis') ||
        lowerTitle.contains('obat') ||
        lowerTitle.contains('ambulans')) {
      return (
        icon: CupertinoIcons.add_circled,
        color: const Color(0xFFD32F2F),
      );
    } else if (lowerTitle.contains('ancaman') ||
        lowerTitle.contains('bahaya')) {
      return (
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: const Color(0xFFE65100),
      );
    } else if (lowerTitle.contains('tersesat')) {
      return (
        icon: CupertinoIcons.compass_fill,
        color: const Color(0xFF00838F),
      );
    } else if (lowerTitle.contains('aksesibilitas')) {
      return (icon: CupertinoIcons.person_crop_circle, color: const Color(0xFF6A1B9A));
    } else if (lowerTitle.contains('lainnya')) {
      return (
        icon: CupertinoIcons.ellipsis_circle_fill,
        color: const Color(0xFF546E7A),
      );
    }

    // Default fallback
    return isSos
        ? (
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            color: Colors.red.shade600,
          )
        : (icon: CupertinoIcons.doc_text, color: primaryTeal);
  }

  Widget _buildHistoryCard(HistoryItem item) {
    final isSos = item.type == HistoryType.sos;
    final isSelesai = item.status == HistoryStatus.selesai;
    final isAktif = item.status == HistoryStatus.aktif;
    final isDibatalkan = item.status == HistoryStatus.dibatalkan;

    String statusLabel = 'Sedang Ditangani';
    Color statusColor = Colors.orange;

    if (isAktif) {
      statusLabel = 'Menunggu Relawan';
      statusColor = Colors.red.shade600;
    } else if (isSelesai) {
      statusLabel = 'Selesai';
      statusColor = Colors.green.shade600;
    } else if (isDibatalkan) {
      statusLabel = 'Dibatalkan';
      statusColor = Colors.grey.shade600;
    }

    final categoryMeta = _getCategoryIconAndColor(item.title, isSos);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToDetail(item),
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
                            color: categoryMeta.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            categoryMeta.icon,
                            color: categoryMeta.color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    item.dateTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStatusBadge(statusLabel, statusColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.location,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _getAddress(item),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? item.location,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            CupertinoIcons.doc_text,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _navigateToDetail(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: categoryMeta.color,
                          side: BorderSide(
                            color: categoryMeta.color.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Lihat Detail',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptedFooter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.shield,
                    color: primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Terenkripsi & Aman',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Data panggilan dan lokasi hanya dapat diakses oleh Anda dan otoritas resmi yang berwenang saat darurat.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
