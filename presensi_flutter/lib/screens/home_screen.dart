import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/absensi_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'riwayat_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _processStatus = '';
  AbsensiModel? _todayAbsen;

  @override
  void initState() {
    super.initState();
    _fetchTodayStatus();
  }

  Future<void> _fetchTodayStatus() async {
    try {
      final list = await ApiService().getRiwayatSaya();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      AbsensiModel? found;
      for (final a in list) {
        if (a.tanggal == todayStr) {
          found = a;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _todayAbsen = found;
        });
      }
    } catch (_) {
      // Abaikan jika error jaringan saat pertama kali memuat info hari ini
    }
  }

  Future<void> _handleAbsen({required bool isMasuk}) async {
    final title = isMasuk ? 'Absen Masuk' : 'Absen Pulang';

    setState(() {
      _isLoading = true;
      _processStatus = 'Mengakses GPS presisi tinggi...';
    });

    try {
      // 1. Ambil GPS
      final position = await LocationService.determinePosition();

      if (!mounted) return;
      setState(() {
        _processStatus = 'Membuka kamera depan...';
      });

      // 2. Buka Kamera Depan
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
      );

      if (photo == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _processStatus = '';
          });
        }
        return; // Dibatalkan oleh pengguna
      }

      if (!mounted) return;
      setState(() {
        _processStatus = 'Mengirim data & memverifikasi wajah...';
      });

      // 3. Kirim ke Backend FastAPI
      final file = File(photo.path);
      final result = isMasuk
          ? await ApiService().absenMasuk(
              latitude: position.latitude,
              longitude: position.longitude,
              fotoFile: file,
            )
          : await ApiService().absenPulang(
              latitude: position.latitude,
              longitude: position.longitude,
              fotoFile: file,
            );

      await _fetchTodayStatus();

      if (!mounted) return;

      // 4. Tampilkan Dialog Sukses
      final statusPresensi = result['status']?.toString() ?? 'Tercatat';
      final jarak = isMasuk ? result['jarak_masuk'] : result['jarak_pulang'];

      _showResultDialog(
        isSuccess: true,
        title: '$title Berhasil!',
        message:
            'Presensi berhasil diverifikasi oleh server.\n\n'
            '• Status: ${statusPresensi.toUpperCase()}\n'
            '• Jarak ke kantor: ${jarak ?? "-"} meter\n'
            '• Koordinat: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      );
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(
        isSuccess: false,
        title: '$title Gagal',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _processStatus = '';
        });
      }
    }
  }

  void _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isSuccess ? Colors.green : Colors.red,
          size: 60,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiConfig.clearSession();
      ApiService().resetClient();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayFormatted =
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Geofence'),
        actions: [
          IconButton(
            tooltip: 'Riwayat Kehadiran',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RiwayatScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchTodayStatus,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profil User Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.nama,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${widget.user.employeeId}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        widget.user.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    if (widget.user.jabatan != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${widget.user.jabatan}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tanggal & Status Hari ini
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Status Hari Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              todayFormatted,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeBox(
                                label: 'Jam Masuk',
                                time: _todayAbsen?.jamMasuk != null
                                    ? DateFormat('HH:mm').format(
                                        DateTime.parse(_todayAbsen!.jamMasuk!))
                                    : '--:--',
                                status: _todayAbsen?.status,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimeBox(
                                label: 'Jam Pulang',
                                time: _todayAbsen?.jamPulang != null
                                    ? DateFormat('HH:mm').format(
                                        DateTime.parse(_todayAbsen!.jamPulang!))
                                    : '--:--',
                                status: _todayAbsen?.jamPulang != null
                                    ? 'selesai'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Aksi Utama
                  Text(
                    'Presensi Mandiri',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pastikan GPS aktif & Anda berada di radius kantor untuk validasi wajah.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Check In
                  FilledButton.icon(
                    onPressed: (_isLoading || _todayAbsen != null)
                        ? null
                        : () => _handleAbsen(isMasuk: true),
                    icon: const Icon(Icons.login_rounded, size: 24),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      child: Text(
                        _todayAbsen != null
                            ? 'Sudah Absen Masuk'
                            : 'Absen Masuk (Check-In)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tombol Check Out
                  OutlinedButton.icon(
                    onPressed: (_isLoading ||
                            _todayAbsen == null ||
                            _todayAbsen?.jamPulang != null)
                        ? null
                        : () => _handleAbsen(isMasuk: false),
                    icon: const Icon(Icons.logout_rounded, size: 24),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      child: Text(
                        _todayAbsen?.jamPulang != null
                            ? 'Sudah Absen Pulang'
                            : 'Absen Pulang (Check-Out)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Lihat Riwayat
                  Card(
                    elevation: 0,
                    color: Colors.blue.shade50.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade100),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month_rounded,
                          color: Colors.blueAccent),
                      title: const Text(
                        'Riwayat Kehadiran Pribadi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Cek rekapan tanggal dan status presensi'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RiwayatScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _processStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required String time,
    String? status,
  }) {
    Color statusColor = Colors.grey;
    String statusText = '';

    if (status != null) {
      if (status == 'tepat_waktu') {
        statusColor = Colors.green;
        statusText = 'Tepat Waktu';
      } else if (status == 'terlambat') {
        statusColor = Colors.orange;
        statusText = 'Terlambat';
      } else if (status == 'selesai') {
        statusColor = Colors.blue;
        statusText = 'Selesai';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (statusText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
