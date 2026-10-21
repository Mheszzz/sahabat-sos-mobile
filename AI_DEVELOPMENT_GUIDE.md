# Panduan AI Developer (AI Development Guide)
**Proyek:** Sahabat SOS Mobile (Flutter)
**Stack:** Flutter 3.x, Dart ^3.12.0, GoRouter, GetIt, Dio, Shared Preferences, Pusher/WebSocket, Tuya SDK

Dokumen ini berfungsi sebagai **SUMBER KEBENARAN MUTLAK** (Source of Truth) bagi setiap AI atau Developer yang akan memodifikasi, menambah, atau melakukan refaktor pada *source code* aplikasi mobile ini.
Aturan di bawah diadopsi langsung dari standar arsitektur clean Flutter dan aturan kurasi kode **RulesCoding** (*Anti-Slop*, *Impeccable UI/UX*, *Layout Mobile*, dan *Code Hygiene*).

---

## 1. Arsitektur Proyek (Feature-First Clean Architecture)
Struktur *folder* memisahkan UI, logika, dan sumber data per fitur:
```text
lib/
├── app.dart             # Root MaterialApp.router & konfigurasi tema
├── main.dart            # Inisialisasi service background, notifikasi, & injection
├── core/                # Modul global terpusat
│   ├── constants/       # Konstanta API, URL, config (api_constants.dart)
│   ├── di/              # Dependency Injection GetIt (injection.dart)
│   ├── services/        # Service inti (location, notification, background, websocket)
│   ├── utils/           # Helper, event bus (global_event_bus.dart, device_info_helper.dart)
│   └── widgets/         # Widget global reusable (AppLoadingIndicator, PermissionGate)
├── features/            # Fitur spesifik per domain (Feature-First)
│   ├── [feature_name]/
│   │   ├── data/        # Model, DataSource (remote/local), Repositories
│   │   └── presentation/# Screen/Page, widgets lokal, controllers/state
└── routing/             # Konfigurasi GoRouter (app_router.dart, routes.dart)
```

---

## 2. Aturan Emas Modifikasi Kode (Golden Rules)
1. **Pemisahan UI dan Komunikasi API:**
   - DILARANG melakukan pemanggilan HTTP mentah (seperti `sl<Dio>().get(...)`) langsung di dalam method `build()` atau `initState()` komponen UI.
   - Pindahkan logika pemanggilan API dan manipulasi data ke dalam *DataSource* atau *Service* di `features/[feature]/data/` atau `core/services/`, lalu daftarkan di `core/di/injection.dart`.
2. **Kepatuhan Routing (GoRouter):**
   - Gunakan `context.push()`, `context.go()`, atau helper rute `AppRoutes` dari `routing/routes.dart`.
   - Hindari manipulasi `Navigator.push` manual kecuali untuk dialog atau modal lokal.
3. **Manajemen State & Dependency Injection:**
   - Gunakan `GetIt` (`sl<T>()`) untuk mengambil dependensi singleton (Dio, SharedPreferences, Services).
   - Untuk komunikasi antar layar/tab, gunakan `GlobalEventBus` yang berbasis `ValueNotifier`.
4. **Resiliensi Aplikasi Darurat (Life-Critical Resiliency):**
   - Aplikasi ini adalah aplikasi darurat (SOS). Penanganan GPS/Lokasi WAJIB memiliki *multi-tier fallback* (Cached Position → `getLastKnownPosition` → `getCurrentPosition` dengan timeout ketat → koordinat default).
   - Jangan pernah membiarkan error jaringan menghentikan alur aplikasi tanpa feedback jelas ke pengguna.
   - Gunakan `debugPrint()` untuk pencatatan debug, **DILARANG** menggunakan `print()` mentah.

---

## 3. Aturan Anti-Slop UI & Visual (Impeccable Craft)
1. **Larangan Generic AI Gradients & Orbs:**
   - DILARANG menggunakan gradien ungu-kebiruan atau bola-bola blur (*radial glowing orbs*) dekoratif yang tidak bermakna.
   - Warna latar belakang standar adalah `#F5F6F8` (Light Theme) dengan kartu putih bersih `#FFFFFF`.
   - Warna aksen utama:
     - Primary Teal: `#00695C` / `#006D77`
     - SOS Danger Red: `#DC2626` / `#E50000`
2. **Batasi Glassmorphism (BackdropFilter):**
   - DILARANG menerapkan `BackdropFilter` pada setiap kartu atau elemen berulang di grid/list. Hal ini menyebabkan penurunan drastis performa (*frame rate drop*) pada perangkat Android kelas menengah ke bawah.
   - Gunakan permukaan solid (`#FFFFFF`) dengan border halus (`#E5E7EB` / border tipis) dan *shadow* lembut untuk hierarki kedalaman.
   - Efek blur hanya diizinkan maksimal 1 tempat (misalnya floating navbar atau header transparan saat scroll).
3. **Kontras & Aksesibilitas Teks (WCAG AA):**
   - Semua teks informasi penting harus memiliki kontras tinggi terhadap latar belakangnya.
   - Hindari teks abu-abu pudar di atas background transparan yang sulit dibaca di luar ruangan di bawah sinar matahari.
   - Ukuran font minimal untuk keterangan sekunder adalah `12sp`.
4. **Desain Tombol SOS:**
   - Tombol darurat SOS harus tegas, berukuran besar, memiliki kontras tinggi, dan memberikan umpan balik taktil (*press animation* / *haptic*).
   - Hindari efek *neumorphic* putih bertumpuk yang terkesan usang dan artifisial.

---

## 4. Aturan Anti-Slop Mobile Layout & Responsiveness
1. **Pencegahan RenderFlex Overflow:**
   - Jangan pernah menyusun layout dengan `Column` kaku berisi `Expanded` + `Spacer` + elemen berukuran tetap tanpa mekanisme *fallback scroll*.
   - Pada layar berdimensi kecil (tinggi < 700dp) atau saat pengguna mengaktifkan pembesaran ukuran font sistem (Accessibility Font Scale), layout harus otomatis dapat di-scroll (`SingleChildScrollView` atau `LayoutBuilder`) agar tidak memunculkan garis kuning-hitam *RenderFlex overflow*.
2. **Touch Targets (Area Sentuh Minimum):**
   - Setiap elemen interaktif (tombol, menu, ikon filter) harus memiliki area sentuh minimum **48x48 dp** agar mudah ditekan oleh pengguna dalam kondisi panik atau oleh lansia.

---

## 5. Aturan Anti-Slop Code & Hygiene Komentar
1. **Hapus Komentar AI yang Restating the Obvious:**
   - DILARANG menulis komentar yang hanya mendikte baris kode berikutnya:
     - ❌ `// Call API` di atas `api.get()`
     - ❌ `// Show loading` di atas `showDialog()`
     - ❌ `// Step 1: Validate input`
     - ❌ `// ================= NAVBAR =================`
   - DILARANG menggunakan emoji dekoratif di komentar kode (`// 🚀`, `// ✅`).
2. **Pertahankan Komentar Alasan & Batasan Sistem (The "Why"):**
   - Jelaskan alasan teknis pada batasan penting, seperti:
     - Alasan tombol SOS memerlukan 5 ketukan cepat dalam 2 detik (mencegah *accidental trigger*).
     - Alasan timeout GPS dibatasi 5 detik agar sinyal SOS tidak tertahan lama jika GPS lambat terkunci.
     - Penanganan integrasi background service dan sinkronisasi hardware Tuya.
