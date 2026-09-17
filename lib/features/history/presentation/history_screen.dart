import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'report_detail_screen.dart';

enum HistoryStatus { selesai, ditangani, aktif }

enum HistoryType { sos, laporan }

class HistoryItem {
  final int id;
  final HistoryType type;
  final HistoryStatus status;
  final String title;
  final String dateTime;
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
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const Color primaryTeal = Color(0xFF00695C);

  int _selectedFilter = 0;
  final List<String> _filters = ['Semua', 'SOS', 'Laporan', 'Selesai'];

  bool _isLoading = true;
  List<HistoryItem> _allItems = [];
  String? _errorMessage;

  int _selectedTimeFilter = 0; // 0: Semua Waktu, 1: 1 Minggu, 2: 1 Bulan, 3: Kustom
  final List<String> _timeFilters = ['Semua Waktu', '1 Minggu', '1 Bulan', 'Kustom'];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final dio = GetIt.instance<Dio>();

      final response = await dio.get(
        ApiConstants.laporan,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] is List
            ? response.data['data']
            : (response.data['data']['data'] ?? []);

        setState(() {
          _allItems = (data as List)
              .map((item) => _mapToHistoryItem(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal mengambil data riwayat.';
          _isLoading = false;
        });
      }
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
    String rawKategori = data['kategori_laporan'] ?? 'Lainnya';
    String kategori = rawKategori
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    String statusStr = data['status'] ?? 'aktif';

    HistoryType type = HistoryType.laporan;
    if (kategori.toLowerCase() == 'sos' ||
        kategori.toLowerCase() == 'sos darurat') {
      type = HistoryType.sos;
    }

    HistoryStatus status = HistoryStatus.aktif;
    if (statusStr == 'selesai') {
      status = HistoryStatus.selesai;
    } else if (statusStr == 'proses') {
      status = HistoryStatus.ditangani;
    }

    String? relawanName = data['relawan']?['name'];
    String? officerInfo = relawanName != null ? 'Relawan $relawanName' : null;

    String rawDate = data['waktu_laporan'] ?? data['created_at'] ?? '';
    String displayDate = rawDate;
    if (rawDate.length >= 16) {
      displayDate = rawDate.replaceAll('T', ' ').substring(0, 16);
    }

    String baseUrlStorage = ApiConstants.baseUrl.replaceAll(
      '/api',
      '/storage/',
    );
    String? foto = data['foto_laporan'] ?? data['foto'];
    String? audio =
        data['audio_laporan'] ??
        data['rekam_suara'] ??
        data['rekaman_suara'] ??
        data['audio'];

    return HistoryItem(
      id: data['id'],
      type: type,
      status: status,
      title: type == HistoryType.sos
          ? 'SOS Darurat: $kategori'
          : 'Laporan: $kategori',
      dateTime: displayDate,
      location: data['lokasi_laporan'] ?? 'Lokasi tidak diketahui',
      description: data['deskripsi'],
      officerInfo: officerInfo,
      detailButtonLabel: type == HistoryType.sos
          ? 'Lihat Detail SOS'
          : 'Lihat Detail Laporan',
      imagePlaceholderIcon: type == HistoryType.sos
          ? Icons.map_outlined
          : Icons.image_outlined,
      imageUrl: foto != null
          ? (foto.startsWith('http')
                ? foto
                : '$baseUrlStorage${foto.replaceFirst('public/', '')}')
          : null,
      audioUrl: audio != null
          ? (audio.startsWith('http')
                ? audio
                : '$baseUrlStorage${audio.replaceFirst('public/', '')}')
          : null,
      latitude: (data['latitude'] is num)
          ? (data['latitude'] as num).toDouble()
          : double.tryParse(data['latitude']?.toString() ?? ''),
      longitude: (data['longitude'] is num)
          ? (data['longitude'] as num).toDouble()
          : double.tryParse(data['longitude']?.toString() ?? ''),
    );
  }

  List<HistoryItem> get _filteredItems {
    List<HistoryItem> items = _allItems;

    // Kategori Filter
    if (_selectedFilter == 1) {
      items = items.where((i) => i.type == HistoryType.sos).toList();
    } else if (_selectedFilter == 2) {
      items = items.where((i) => i.type == HistoryType.laporan).toList();
    } else if (_selectedFilter == 3) {
      items = items.where((i) => i.status == HistoryStatus.selesai).toList();
    }

    // Waktu Filter
    if (_selectedTimeFilter != 0) {
      final now = DateTime.now();
      items = items.where((item) {
        try {
          final itemDate = DateTime.parse(item.dateTime.replaceAll(' ', 'T'));
          if (_selectedTimeFilter == 1) { // 1 Minggu
            return now.difference(itemDate).inDays <= 7;
          } else if (_selectedTimeFilter == 2) { // 1 Bulan
            return now.difference(itemDate).inDays <= 30;
          } else if (_selectedTimeFilter == 3) { // Kustom
            if (_customStartDate != null && _customEndDate != null) {
              return itemDate.isAfter(_customStartDate!.subtract(const Duration(days: 1))) && 
                     itemDate.isBefore(_customEndDate!.add(const Duration(days: 1)));
            }
          }
        } catch (e) {
          return true; // Jika parsing gagal, biarkan saja
        }
        return true;
      }).toList();
    }

    return items;
  }

  List<HistoryItem> get _paginatedItems {
    final items = _filteredItems;
    if (_selectedFilter == 0) {
      final startIndex = (_currentPage - 1) * _itemsPerPage;
      if (startIndex >= items.length) return [];
      final endIndex = (startIndex + _itemsPerPage < items.length) ? startIndex + _itemsPerPage : items.length;
      return items.sublist(startIndex, endIndex);
    }
    return items;
  }

  int get _totalPages {
    if (_selectedFilter == 0) {
      return (_filteredItems.length / _itemsPerPage).ceil();
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA), // Light blue/teal
              Color(0xFFF5F6F8), // Greyish white
              Color(0xFFE0F2F1), // Light teal
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchHistory,
            color: primaryTeal,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Text(
                  'Riwayat Laporan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_allItems.length} laporan tercatat',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 12),
                _buildTimeFilterChips(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: primaryTeal),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ..._paginatedItems.map((item) => _buildHistoryCard(item)),
                if (!_isLoading && _errorMessage == null && _filteredItems.isNotEmpty && _selectedFilter == 0 && _totalPages > 1)
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
      backgroundColor: Colors.transparent, // Glassy look for app bar
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: const [
          Icon(Icons.accessibility_new, color: primaryTeal, size: 24),
          SizedBox(width: 8),
          Text(
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

  Widget _buildFilterChips() {
    final icons = [
      Icons.all_inbox_rounded,
      Icons.sos,
      Icons.description_outlined,
      Icons.check_circle_outline,
    ];

    int getCount(int index) {
      if (index == 0) return _allItems.length;
      if (index == 1) {
        return _allItems.where((i) => i.type == HistoryType.sos).length;
      }
      if (index == 2) {
        return _allItems.where((i) => i.type == HistoryType.laporan).length;
      }
      if (index == 3) {
        return _allItems.where((i) => i.status == HistoryStatus.selesai).length;
      }
      return 0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilter == index;
          final count = getCount(index);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedFilter = index;
                _currentPage = 1; // Reset pagination when filter changes
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF00695C), Color(0xFF004D40)],
                        )
                      : const LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ),
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
                      _filters[index],
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
                            surface: Colors.transparent, // Background of dialog/scaffold
                            onSurfaceVariant: Colors.black54, // For header text
                          ),
                          datePickerTheme: const DatePickerThemeData(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            headerBackgroundColor: Colors.transparent,
                          ), dialogTheme: DialogThemeData(backgroundColor: Colors.transparent),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.7),
                                  Colors.white.withValues(alpha: 0.4),
                                ],
                              ),
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
                      _currentPage = 1;
                    });
                  }
                } else {
                  setState(() {
                    _selectedTimeFilter = index;
                    _currentPage = 1;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    if (index == 3 && isSelected && _customStartDate != null)
                      const Icon(Icons.date_range, size: 14, color: primaryTeal)
                    else
                      Icon(Icons.access_time, size: 14, color: isSelected ? primaryTeal : Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      index == 3 && isSelected && _customStartDate != null
                          ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                          : _timeFilters[index],
                      style: TextStyle(
                        color: isSelected ? primaryTeal : Colors.grey.shade600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            color: _currentPage > 1 ? primaryTeal : Colors.grey,
          ),
          ...List.generate(_totalPages, (index) {
            final page = index + 1;
            // Basic pagination to not overflow screen if too many pages
            if (_totalPages > 5) {
              if (page != 1 && page != _totalPages && (page < _currentPage - 1 || page > _currentPage + 1)) {
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
              onTap: () => setState(() => _currentPage = page),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => setState(() => _currentPage++)
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
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
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
            icon: const Icon(Icons.refresh, size: 18),
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
              Icons.folder_open_rounded,
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
      return (icon: Icons.people_alt_rounded, color: const Color(0xFF1565C0));
    } else if (lowerTitle.contains('medis') ||
        lowerTitle.contains('obat') ||
        lowerTitle.contains('ambulans')) {
      return (
        icon: Icons.local_hospital_rounded,
        color: const Color(0xFFD32F2F),
      );
    } else if (lowerTitle.contains('ancaman') ||
        lowerTitle.contains('bahaya')) {
      return (icon: Icons.shield_rounded, color: const Color(0xFFE65100));
    } else if (lowerTitle.contains('tersesat')) {
      return (icon: Icons.explore_rounded, color: const Color(0xFF00838F));
    } else if (lowerTitle.contains('aksesibilitas')) {
      return (icon: Icons.accessible_rounded, color: const Color(0xFF6A1B9A));
    } else if (lowerTitle.contains('lainnya')) {
      return (icon: Icons.more_horiz_rounded, color: const Color(0xFF546E7A));
    }

    // Default fallback
    return isSos
        ? (icon: Icons.sos, color: Colors.red.shade600)
        : (icon: Icons.assignment_outlined, color: primaryTeal);
  }

  Widget _buildHistoryCard(HistoryItem item) {
    final isSos = item.type == HistoryType.sos;
    final isSelesai = item.status == HistoryStatus.selesai;
    final isAktif = item.status == HistoryStatus.aktif;

    String statusLabel = 'Sedang Ditangani';
    Color statusColor = Colors.orange;

    if (isAktif) {
      statusLabel = 'Menunggu Relawan';
      statusColor = Colors.red.shade600;
    } else if (isSelesai) {
      statusLabel = 'Selesai';
      statusColor = Colors.green.shade600;
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
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.location,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                            Icons.description_outlined,
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
                    Icons.shield_outlined,
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
