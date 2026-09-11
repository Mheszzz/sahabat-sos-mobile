# Sahabat SOS Mobile

Aplikasi Sahabat SOS Mobile (Flutter).

## Cara Menjalankan dengan Docker (Rekomendasi)

Agar lebih mudah dan tidak perlu melakukan instalasi SDK Android atau Flutter, Anda dapat menjalankan versi Web dari aplikasi ini menggunakan Docker.

1. Pastikan Anda sudah menginstal [Docker](https://docs.docker.com/get-docker/) dan Docker Compose di komputer Anda.
2. Buka terminal, lalu arahkan ke direktori proyek ini.
3. Jalankan perintah berikut untuk membangun dan menghidupkan container:
   ```bash
   docker-compose up --build -d
   ```
4. Setelah proses selesai, buka browser Anda dan akses aplikasi di:
   **http://localhost:8080**
5. Untuk mematikan aplikasi, jalankan perintah:
   ```bash
   docker-compose down
   ```

---

## Cara Instalasi Manual (Development)

Jika Anda ingin melakukan modifikasi kode atau menjalankan di emulator Android/iOS secara *native*, ikuti langkah-langkah berikut:

1. Pastikan Anda sudah menginstal [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Buka terminal, lalu arahkan ke direktori proyek.
3. Unduh semua dependensi yang dibutuhkan dengan menjalankan perintah:
   ```bash
   flutter pub get
   ```
4. Jalankan aplikasi pada emulator atau perangkat fisik yang terhubung:
   ```bash
   flutter run
   ```
