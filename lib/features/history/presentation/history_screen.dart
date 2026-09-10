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
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] is List 
            ? response.data['data'] 
            : (response.data['data']['data'] ?? []);
            
        setState(() {
          _allItems = (data as List).map((item) => _mapToHistoryItem(item)).toList();
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
    String kategori = data['kategori_laporan'] ?? 'Lainnya';
    String statusStr = data['status'] ?? 'aktif';
    
    HistoryType type = HistoryType.laporan;
    if (kategori.toLowerCase() == 'sos' || kategori.toLowerCase() == 'sos darurat') {
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

    String baseUrlStorage = ApiConstants.baseUrl.replaceAll('/api', '/storage/');
    String? foto = data['foto_laporan'] ?? data['foto'];
    String? audio = data['audio_laporan'] ?? data['rekam_suara'] ?? data['rekaman_suara'] ?? data['audio'];

    return HistoryItem(
      id: data['id'],
      type: type,
      status: status,
      title: type == HistoryType.sos ? 'SOS Darurat: $kategori' : 'Laporan: $kategori',
      dateTime: displayDate,
      location: data['lokasi_laporan'] ?? 'Lokasi tidak diketahui',
      description: data['deskripsi'],
      officerInfo: officerInfo,
      detailButtonLabel: type == HistoryType.sos ? 'Lihat Detail SOS' : 'Lihat Detail Laporan',
      imagePlaceholderIcon: type == HistoryType.sos ? Icons.map_outlined : Icons.image_outlined,
      imageUrl: foto != null ? (foto.startsWith('http') ? foto : '$baseUrlStorage${foto.replaceFirst('public/', '')}') : null,
      audioUrl: audio != null ? (audio.startsWith('http') ? audio : '$baseUrlStorage${audio.replaceFirst('public/', '')}') : null,
      latitude: (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : double.tryParse(data['latitude']?.toString() ?? ''),
      longitude: (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : double.tryParse(data['longitude']?.toString() ?? ''),
    );
  }

  List<HistoryItem> get _filteredItems {
    if (_selectedFilter == 0) return _allItems; // Semua
    if (_selectedFilter == 1) return _allItems.where((i) => i.type == HistoryType.sos).toList(); // SOS
    if (_selectedFilter == 2) return _allItems.where((i) => i.type == HistoryType.laporan).toList(); // Laporan
    if (_selectedFilter == 3) return _allItems.where((i) => i.status == HistoryStatus.selesai).toList(); // Selesai
    return _allItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchHistory,
          color: primaryTeal,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const Text(
                'Riwayat Laporan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${_allItems.length} laporan tercatat',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _buildFilterChips(),
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
                ..._filteredItems.map((item) => _buildHistoryCard(item)),
              const SizedBox(height: 8),
              _buildEncryptedFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: const [
          Icon(Icons.accessibility_new, color: primaryTeal, size: 22),
          SizedBox(width: 8),
          Text(
            'Sahabat SOS',
            style: TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final icons = [Icons.all_inbox_rounded, Icons.sos, Icons.description_outlined, Icons.check_circle_outline];
    
    int getCount(int index) {
      if (index == 0) return _allItems.length;
      if (index == 1) return _allItems.where((i) => i.type == HistoryType.sos).length;
      if (index == 2) return _allItems.where((i) => i.type == HistoryType.laporan).length;
      if (index == 3) return _allItems.where((i) => i.status == HistoryStatus.selesai).length;
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
              onTap: () => setState(() => _selectedFilter = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF004D40)])
                      : const LinearGradient(colors: [Colors.white, Colors.white]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: primaryTeal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white24 : Colors.grey.shade200,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
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
            child: Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade400),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _getCategoryIconAndColor(String title, bool isSos) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('pendamping')) {
      return (icon: Icons.people_alt_rounded, color: const Color(0xFF1565C0));
    } else if (lowerTitle.contains('medis') || lowerTitle.contains('obat') || lowerTitle.contains('ambulans')) {
      return (icon: Icons.local_hospital_rounded, color: const Color(0xFFD32F2F));
    } else if (lowerTitle.contains('ancaman') || lowerTitle.contains('bahaya')) {
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

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryMeta.color.withOpacity(0.1),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(item.dateTime, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  _buildStatusBadge(statusLabel, statusColor),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.location,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.description!,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                    side: BorderSide(color: categoryMeta.color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Lihat Detail', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(HistoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(item: item),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: primaryTeal, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Terenkripsi & Aman',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                SizedBox(height: 4),
                Text(
                  'Data panggilan dan lokasi hanya dapat diakses oleh Anda dan otoritas resmi yang berwenang saat darurat.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
