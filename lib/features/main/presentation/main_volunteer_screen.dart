import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/volunteer_dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_task_list_page.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/volunteer_map_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/volunteer_profile_screen.dart';

import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as event_bus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/widgets/new_assignment_dialog.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_active_task_page.dart';
import 'package:sahabat_sos_mobile/core/services/notification_service.dart';
import 'package:sahabat_sos_mobile/core/services/sos_rejection_storage.dart';

class MainVolunteerScreen extends StatefulWidget {
  final int initialIndex;
  const MainVolunteerScreen({super.key, this.initialIndex = 0});

  @override
  State<MainVolunteerScreen> createState() => _MainVolunteerScreenState();
}

class _MainVolunteerScreenState extends State<MainVolunteerScreen> {
  late int _selectedIndex;
  bool? _isVerified;
  bool _isActive = true;
  String _verificationStatus = 'pending';
  String? _rejectionReason;
  bool _isSosDialogShowing = false;
  final List<int> _rejectedSosIds = [];
  final LocationService _locationService = sl<LocationService>();

  // Key untuk akses langsung ke VolunteerMapPage state
  final GlobalKey<VolunteerMapPageState> _mapPageKey =
      GlobalKey<VolunteerMapPageState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initVolunteerServices();
    event_bus.GlobalEventBus.navigateToMapWithSos.addListener(_onNavigateToMap);
    event_bus.GlobalEventBus.changeVolunteerTab.addListener(_onChangeTab);
    event_bus.GlobalEventBus.volunteerVerificationStatus.addListener(_onVerificationStatusChanged);
    event_bus.GlobalEventBus.volunteerActiveStatus.addListener(_onActiveStatusChanged);
    event_bus.GlobalEventBus.showSosAssignmentPopup.addListener(_onShowSosAssignmentPopup);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onShowSosAssignmentPopup();
    });
  }

  void _onActiveStatusChanged() {
    final status = event_bus.GlobalEventBus.volunteerActiveStatus.value;
    if (status != null && status != _isActive) {
      setState(() {
        _isActive = status;
        if (!_isActive && _selectedIndex != 3) {
          _selectedIndex = 3;
        }
      });
      if (_isActive && _isVerified == true) {
        _startOperationalServices();
      } else {
        _locationService.stopTracking();
      }
    }
  }

  void _onVerificationStatusChanged() {
    final status = event_bus.GlobalEventBus.volunteerVerificationStatus.value;
    if (status == true && _isVerified != true) {
      setState(() {
        _isVerified = true;
        _verificationStatus = 'terverifikasi';
      });
      if (_isActive) {
        _startOperationalServices();
      }
    } else if (status == false && _isVerified != false) {
      setState(() {
        _isVerified = false;
        _selectedIndex = 3;
      });
      _locationService.stopTracking();
    }
  }

  void _onChangeTab() {
    final targetIndex = event_bus.GlobalEventBus.changeVolunteerTab.value;
    if (targetIndex != null) {
      if ((_isVerified == false || !_isActive) && targetIndex != 3) {
        if (_verificationStatus == 'ditolak') {
          _showRejectedDialog();
        } else if (!_isActive) {
          _showDeactivatedDialog();
        } else {
          _showUnverifiedDialog();
        }
      } else {
        setState(() {
          _selectedIndex = targetIndex;
        });
      }
      event_bus.GlobalEventBus.changeVolunteerTab.value = null;
    }
  }

  void _showRejectedDialog() {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isHighContrast ? Brightness.dark : Brightness.light,
          primaryColor: isHighContrast ? const Color(0xFF80CBC4) : primaryTeal,
        ),
        child: CupertinoAlertDialog(
          title: const Text('Pengajuan Relawan Ditolak'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _rejectionReason != null && _rejectionReason!.isNotEmpty
                  ? 'Pengajuan verifikasi relawan Anda ditolak oleh admin dengan catatan:\n\n"$_rejectionReason"\n\nSilakan periksa halaman Profil untuk informasi lebih lanjut atau hubungi admin posko.'
                  : 'Pengajuan relawan Anda belum memenuhi kualifikasi verifikasi administrator.\n\nSilakan cek status di tab Profil atau hubungi admin posko koordinasi.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivatedDialog() {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isHighContrast ? Brightness.dark : Brightness.light,
          primaryColor: isHighContrast ? const Color(0xFF80CBC4) : primaryTeal,
        ),
        child: CupertinoAlertDialog(
          title: const Text('Akun Dinonaktifkan'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Akun relawan Anda saat ini telah dinonaktifkan oleh administrator.\n\nFitur Beranda, Tugas, dan Peta tidak dapat diakses selama status akun nonaktif.\n\nSilakan cek status akun Anda di halaman Profil atau hubungi admin.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnverifiedDialog() {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isHighContrast ? Brightness.dark : Brightness.light,
          primaryColor: isHighContrast ? const Color(0xFF80CBC4) : primaryTeal,
        ),
        child: CupertinoAlertDialog(
          title: const Text('Akun Dalam Tahap Verifikasi'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Akun relawan Anda sedang dalam peninjauan oleh admin Sahabat SOS.\n\nFitur Beranda, Tugas, dan Peta akan dapat diakses setelah akun Anda diverifikasi oleh admin.\n\nSilakan cek status verifikasi Anda di halaman Profil.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dipanggil saat relawan menerima tugas → pindah ke tab Peta & tampilkan rute
  void _onNavigateToMap() {
    if (_isVerified == false || !_isActive) return;
    final sosData = event_bus.GlobalEventBus.navigateToMapWithSos.value;
    if (sosData == null) return;

    setState(() {
      _selectedIndex = 2; // Tab Peta
    });

    // Beri sedikit jeda agar tab Peta sudah ter-render
    Future.delayed(const Duration(milliseconds: 400), () {
      _mapPageKey.currentState?.acceptSosAndRoute(sosData);
      // Reset event agar tidak trigger ulang
      event_bus.GlobalEventBus.navigateToMapWithSos.value = null;
    });
  }

  void _onShowSosAssignmentPopup() {
    final sosData = event_bus.GlobalEventBus.showSosAssignmentPopup.value;
    if (sosData == null) return;
    if (_isSosDialogShowing) return;
    if (_isVerified != true || !_isActive) {
      debugPrint("⛔ Akun relawan tidak aktif atau belum terverifikasi, mengabaikan popup.");
      event_bus.GlobalEventBus.showSosAssignmentPopup.value = null;
      return;
    }

    final dynamic rawId = sosData['id'];
    final int sosId =
        (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;
    if (_rejectedSosIds.contains(sosId) ||
        (sosId > 0 && SosRejectionStorage.isRejected(sosId))) {
      debugPrint("ℹ️ SOS #$sosId sudah pernah ditolak.");
      event_bus.GlobalEventBus.showSosAssignmentPopup.value = null;
      return;
    }

    _isSosDialogShowing = true;
    event_bus.GlobalEventBus.showSosAssignmentPopup.value = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewAssignmentDialog(
        sosData: sosData,
        onAccept: () async {
          _isSosDialogShowing = false;
          Navigator.pop(ctx);
          try {
            final volunteerDataSource = sl<VolunteerRemoteDataSource>();
            await volunteerDataSource.updateSosStatus(sosId, 'ditangani');

            if (!mounted) return;
            event_bus.GlobalEventBus.refreshMap.value =
                !event_bus.GlobalEventBus.refreshMap.value;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VolunteerActiveTaskPage(
                  initialTask: sosData,
                ),
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tugas diterima! Menuju lokasi korban...'),
                backgroundColor: primaryTeal,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menerima tugas: $e')),
            );
          }
        },
        onReject: (String? reason) async {
          _isSosDialogShowing = false;
          _rejectedSosIds.add(sosId);
          if (sosId > 0) {
            final prefs = sl<SharedPreferences>();
            await SosRejectionStorage.addRejectedId(sosId, prefs);
          }
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }

          try {
            final volunteerDataSource = sl<VolunteerRemoteDataSource>();
            await volunteerDataSource.rejectSos(sosId, alasan: reason);

            event_bus.GlobalEventBus.refreshMap.value =
                !event_bus.GlobalEventBus.refreshMap.value;

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  reason != null && reason.isNotEmpty
                      ? 'Tugas dialihkan ($reason).'
                      : 'Tugas dialihkan ke relawan lain.',
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengalihkan tugas: $e')),
            );
          }
        },
      ),
    ).then((_) {
      _isSosDialogShowing = false;
    });
  }

  @override
  void dispose() {
    event_bus.GlobalEventBus.showSosAssignmentPopup.removeListener(
      _onShowSosAssignmentPopup,
    );
    event_bus.GlobalEventBus.navigateToMapWithSos.removeListener(
      _onNavigateToMap,
    );
    event_bus.GlobalEventBus.changeVolunteerTab.removeListener(_onChangeTab);
    event_bus.GlobalEventBus.volunteerVerificationStatus.removeListener(_onVerificationStatusChanged);
    event_bus.GlobalEventBus.volunteerActiveStatus.removeListener(_onActiveStatusChanged);
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _startOperationalServices() async {
    // 1. Start Location Tracking
    final hasPerm = await _locationService.requestPermission();
    if (hasPerm) {
      _locationService.startTracking();
    }

    // 2. Initialize Notification & WebSocket so popup notifications can arrive
    try {
      await NotificationService().init();
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final volunteerId = prefs.getInt('volunteer_id') ?? 0;
      if (token != null) {
        await WebsocketService.init(token);
        WebsocketService.listenToNewSosForVolunteer(volunteerId, (payload) {});
      }
    } catch (e) {
      debugPrint('WebSocket init error in MainVolunteer: $e');
    }
  }

  Future<void> _initVolunteerServices() async {
    // Cek cache SharedPreferences dulu agar responsif
    try {
      final prefs = sl<SharedPreferences>();
      final cachedStatus = prefs.getString('verification_status');
      final cachedActive = prefs.getBool('user_is_active') ?? true;
      final cachedReason = prefs.getString('rejection_reason');
      if (mounted) {
        setState(() {
          _isActive = cachedActive;
          _rejectionReason = cachedReason;
          if (cachedStatus != null) {
            _verificationStatus = cachedStatus;
            _isVerified = cachedStatus == 'terverifikasi';
          }
          if ((_isVerified == false || !_isActive) && _selectedIndex != 3) {
            _selectedIndex = 3;
          }
        });
      }
    } catch (_) {}

    // 0. Check Verification Status ke server
    try {
      final volunteerDataSource = sl<VolunteerRemoteDataSource>();
      final response = await volunteerDataSource.getRelawanProfile();
      final userData = response['user'];
      if (userData != null) {
        final status = (userData['status_verifikasi'] ?? 'pending').toString().toLowerCase();
        final active = (userData['is_active'] == true || userData['is_active'] == 1);
        final reason = userData['alasan_penolakan']?.toString();
        final volunteerId = (userData['id'] is int)
            ? userData['id'] as int
            : int.tryParse(userData['id']?.toString() ?? '');
        final prefs = sl<SharedPreferences>();
        if (volunteerId != null && volunteerId > 0) {
          await prefs.setInt('volunteer_id', volunteerId);
        }
        await prefs.setString('verification_status', status);
        await prefs.setBool('user_is_active', active);
        if (reason != null && reason.isNotEmpty) {
          await prefs.setString('rejection_reason', reason);
        } else {
          await prefs.remove('rejection_reason');
        }

        if (mounted) {
          setState(() {
            _verificationStatus = status;
            _isVerified = status == 'terverifikasi';
            _isActive = active;
            _rejectionReason = reason;
            if ((_isVerified == false || !_isActive) && _selectedIndex != 3) {
              _selectedIndex = 3; // Force to Profile tab
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching verification status: $e');
      if (mounted && _isVerified == null) {
        setState(() {
          _isVerified = false; // default to block
          if (_selectedIndex != 3) {
            _selectedIndex = 3;
          }
        });
      }
    }

    if (_isVerified == true && _isActive == true) {
      await _startOperationalServices();
    } else {
      _locationService.stopTracking();
    }
  }

  @override
  void didUpdateWidget(MainVolunteerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  static const Color primaryTeal = Color(0xFF006D77);
  static const Color _unselectedColor = Colors.grey;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: 'Beranda',
    ),
    _NavItem(
      icon: CupertinoIcons.doc_text,
      selectedIcon: CupertinoIcons.doc_text_fill,
      label: 'Tugas',
    ),
    _NavItem(
      icon: CupertinoIcons.map,
      selectedIcon: CupertinoIcons.map_fill,
      label: 'Peta',
    ),
    _NavItem(
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_solid,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const VolunteerDashboardPage(),
      const VolunteerTaskListPage(),
      VolunteerMapPage(key: _mapPageKey),
      const VolunteerProfileScreen(),
    ];

    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final selectedColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final unselectedColor =
            isHighContrast ? const Color(0xFFD1D5DB) : _unselectedColor;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(index: _selectedIndex, children: pages),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF121212)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB),
                      width: isHighContrast ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isHighContrast ? 0.35 : 0.08,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(_navItems.length, (index) {
                          final isSelected = _selectedIndex == index;
                          final item = _navItems[index];
                          final isLocked = (_isVerified == false || !_isActive) && index != 3;

                          return GestureDetector(
                            onTap: () {
                              AccessibilityService.instance.hapticSelection();
                              if (isLocked) {
                                if (_verificationStatus == 'ditolak') {
                                  _showRejectedDialog();
                                } else if (!_isActive) {
                                  _showDeactivatedDialog();
                                } else {
                                  _showUnverifiedDialog();
                                }
                                return;
                              }
                              AccessibilityService.instance.speak("Tab ${item.label}");
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected && isHighContrast
                                    ? const Color(0xFF1E2430)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        isSelected ? item.selectedIcon : item.icon,
                                        color: isLocked
                                            ? (isHighContrast
                                                ? const Color(0xFF6B7280)
                                                : Colors.grey.withValues(alpha: 0.35))
                                            : isSelected
                                                ? selectedColor
                                                : unselectedColor,
                                        size: 24,
                                      ),
                                      if (isLocked)
                                        Positioned(
                                          top: -3,
                                          right: -7,
                                          child: Container(
                                            padding: const EdgeInsets.all(2.5),
                                            decoration: BoxDecoration(
                                              color: !_isActive ? Colors.red.shade700 : Colors.amber.shade800,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.lock_fill,
                                              color: Colors.white,
                                              size: 8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isLocked
                                          ? (isHighContrast
                                              ? const Color(0xFF6B7280)
                                              : Colors.grey.withValues(alpha: 0.35))
                                          : isSelected
                                              ? selectedColor
                                              : unselectedColor,
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
