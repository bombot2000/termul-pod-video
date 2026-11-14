import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'models/pod_media_record.dart';
import 'screens/camera_capture_screen.dart';
import 'screens/media_preview_screen.dart';
import 'services/gallery_media_service.dart';
import 'services/pod_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TermulPodApp());
}

class TermulPodApp extends StatelessWidget {
  const TermulPodApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF146C5A);
    return MaterialApp(
      title: 'Termul POD Video',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F6),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE7ECE9)),
          ),
        ),
      ),
      home: const PodHomePage(),
    );
  }
}

class PodHomePage extends StatefulWidget {
  const PodHomePage({super.key});

  @override
  State<PodHomePage> createState() => _PodHomePageState();
}

class _PodHomePageState extends State<PodHomePage> {
  int _selectedIndex = 0;
  int _historyVersion = 0;
  static const _titles = ['Dokumentasi POD', 'Riwayat', 'Pengaturan'];

  Future<void> _openCamera({bool videoMode = false}) async {
    final record = await Navigator.of(context).push<PodMediaRecord>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(initialVideoMode: videoMode),
      ),
    );
    if (!mounted) return;
    if (record != null) {
      var savedRecord = record;
      try {
        await GalleryMediaService().save(record);
        savedRecord = await PodStorageService().updateGalleryStatus(record, true);
      } catch (_) {
        try {
          savedRecord = await PodStorageService().updateGalleryStatus(record, false);
        } catch (_) {
          // The original history entry and media file remain safe.
        }
      }
      if (!mounted) return;
      setState(() => _historyVersion++);
      final label = savedRecord.type == 'video' ? 'Video' : 'Foto';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(savedRecord.gallerySaved == true
            ? '$label POD tersimpan di Galeri dan riwayat.'
            : '$label POD tersimpan di riwayat, tetapi gagal disalin ke Galeri.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TERMUL POD',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            Text(_titles[_selectedIndex],
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Status penyimpanan',
            onPressed: () => _showInfo(
              context,
              'Penyimpanan offline',
              'Foto dan video tersimpan di riwayat lokal aplikasi serta disalin ke album Galeri Termul POD. Penyimpanan lokal tetap tersedia tanpa internet.',
            ),
            icon: const Icon(Icons.cloud_off_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _CaptureDashboard(
            onCapture: () => _openCamera(),
            onPhotoCapture: () => _openCamera(),
            onVideoCapture: () => _openCamera(videoMode: true),
          ),
          _HistoryPage(key: ValueKey(_historyVersion)),
          const _SettingsPlaceholder(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt),
              label: 'Dokumentasi'),
          NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Pengaturan'),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'))
        ],
      ),
    );
  }
}

class _CaptureDashboard extends StatelessWidget {
  const _CaptureDashboard({
    required this.onCapture,
    required this.onPhotoCapture,
    required this.onVideoCapture,
  });
  final VoidCallback onCapture;
  final VoidCallback onPhotoCapture;
  final VoidCallback onVideoCapture;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF125D50), Color(0xFF218A70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.verified_user_outlined,
                    color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text('PROOF OF DELIVERY',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
              ]),
              const SizedBox(height: 18),
              const Text('Dokumentasikan\nsetiap pengiriman.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                  'Foto dan video dengan informasi waktu serta lokasi.',
                  style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Mulai dokumentasi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF125D50),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Pilih dokumentasi',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.photo_camera_outlined,
                title: 'Foto POD',
                subtitle: 'Bukti serah terima',
                onTap: onPhotoCapture,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.videocam_outlined,
                title: 'Video POD',
                subtitle: 'Rekaman pengiriman',
                onTap: onVideoCapture,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Informasi dokumentasi',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const _InfoRow(
            icon: Icons.schedule,
            title: 'Tanggal dan waktu',
            detail: 'Dicatat saat pengambilan',
            status: 'AKTIF'),
        const _InfoRow(
            icon: Icons.location_on_outlined,
            title: 'Lokasi GPS',
            detail: 'Koordinat dan akurasi jika izin tersedia',
            status: 'OPSIONAL'),
        const _InfoRow(
            icon: Icons.layers_outlined,
            title: 'Watermark',
            detail: 'Watermark waktu dan lokasi tertanam pada foto serta video',
            status: 'FOTO + VIDEO'),
        const _InfoRow(
            icon: Icons.offline_pin_outlined,
            title: 'Penyimpanan lokal',
            detail: 'Foto dan video tersimpan di perangkat tanpa internet',
            status: 'AKTIF OFFLINE'),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFE7F3EF),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: const Color(0xFF146C5A)),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE7F3EF),
            child: Icon(icon, color: const Color(0xFF146C5A), size: 20),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
          trailing: Text(
            status,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF58746B),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPage extends StatefulWidget {
  const _HistoryPage({super.key});

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  late Future<List<PodMediaRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = PodStorageService().getRecords();
  }

  Future<void> _openPreview(PodMediaRecord record) async {
    final file = File(record.path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File dokumentasi tidak ditemukan.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MediaPreviewScreen(record: record)),
    );
  }

  Future<void> _saveToGallery(PodMediaRecord record) async {
    try {
      await GalleryMediaService().save(record);
      await PodStorageService().updateGalleryStatus(record, true);
      if (!mounted) return;
      setState(() => _records = PodStorageService().getRecords());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(record.type == 'video'
            ? 'Video berhasil disimpan ke Galeri.'
            : 'Foto berhasil disimpan ke Galeri.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan ke Galeri: $error')),
      );
    }
  }

  Future<void> _delete(PodMediaRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dokumentasi?'),
        content: const Text(
            'File ini akan dihapus dari penyimpanan aplikasi dan tidak dapat dipulihkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await PodStorageService().deleteRecord(record);
    if (!mounted) return;
    setState(() => _records = PodStorageService().getRecords());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PodMediaRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Gagal membaca riwayat: ${snapshot.error}'));
        }
        final records = snapshot.data ?? const <PodMediaRecord>[];
        if (records.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 56, color: Color(0xFF8A9B94)),
                  SizedBox(height: 14),
                  Text('Belum ada dokumentasi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('Hasil foto dan video POD akan tampil di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = records[index];
            final isVideo = record.type == 'video';
            final file = File(record.path);
            final coordinates = record.latitude == null
                ? 'Koordinat GPS tidak tersedia'
                : '${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}';
            final addressLine = record.address?.trim().isNotEmpty == true
                ? record.address!
                : 'Alamat lokasi tidak tersedia';
            final watermarkStatus = record.watermarkApplied == true
                ? 'Watermark waktu dan lokasi tertanam'
                : record.watermarkApplied == false
                    ? 'Watermark gagal diterapkan'
                    : isVideo
                        ? 'Watermark belum diterapkan pada rekaman lama'
                        : 'Status watermark tidak tercatat';
            return Card(
              child: ListTile(
                onTap: () => _openPreview(record),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: isVideo
                        ? Container(
                            color: const Color(0xFFE7F3EF),
                            child: const Icon(Icons.play_circle_outline,
                                color: Color(0xFF146C5A), size: 34),
                          )
                        : Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFE7F3EF),
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                title: Text(isVideo ? 'Video POD' : 'Foto POD',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy • HH:mm').format(record.createdAt)}\n$addressLine\n$coordinates\n$watermarkStatus${record.gallerySaved == true ? '\nTersimpan di Galeri' : record.gallerySaved == false ? '\nBelum tersimpan di Galeri' : ''}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: record.gallerySaved == true
                          ? 'Tersimpan di Galeri'
                          : 'Simpan ke Galeri',
                      onPressed: record.gallerySaved == true
                          ? null
                          : () => _saveToGallery(record),
                      icon: Icon(
                        record.gallerySaved == true
                            ? Icons.check_circle_outline
                            : Icons.save_alt_outlined,
                        color: record.gallerySaved == true
                            ? const Color(0xFF146C5A)
                            : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus dokumentasi',
                      onPressed: () => _delete(record),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(
              child: ListTile(
                  leading: Icon(Icons.text_fields),
                  title: Text('Template watermark'),
                  subtitle: Text(
                      'Watermark waktu, koordinat GPS, akurasi, dan alamat (jika tersedia) tertanam pada foto serta video. Template belum dapat diubah.'))),
          Card(
              child: ListTile(
                  leading: Icon(Icons.gps_fixed),
                  title: Text('Informasi GPS'),
                  subtitle: Text('Koordinat, akurasi, dan alamat dicatat jika GPS serta layanan geocoding tersedia. Jika alamat gagal diperoleh, dokumentasi tetap disimpan.'))),
          Card(
              child: ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Penyimpanan'),
                  subtitle: Text('Foto dan video tersimpan di perangkat dan diekspor ke album Galeri Termul POD. Backup cloud belum tersedia.'))),
          Card(
              child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Tentang aplikasi'),
                  subtitle: Text('Termul POD Video · 0.1.0'))),
        ],
      );
}
