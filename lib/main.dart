import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/pod_media_record.dart';
import 'screens/camera_capture_screen.dart';
import 'screens/media_preview_screen.dart';
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
  final _historyKey = GlobalKey<_HistoryPageState>();
  static const _titles = ['Dokumentasi POD', 'Riwayat', 'Pengaturan'];

  Future<void> _openCamera() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    _historyKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TERMUL POD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            Text(_titles[_selectedIndex], style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Status penyimpanan',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Mode offline aktif'),
                content: const Text('Foto dan video disimpan di penyimpanan internal aplikasi. Riwayat tetap tersedia tanpa koneksi internet.'),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup'))],
              ),
            ),
            icon: const Icon(Icons.cloud_off_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _CaptureDashboard(onOpenCamera: _openCamera),
          _HistoryPage(key: _historyKey),
          const _SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) _historyKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Dokumentasi'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Pengaturan'),
        ],
      ),
    );
  }
}

class _CaptureDashboard extends StatelessWidget {
  const _CaptureDashboard({required this.onOpenCamera});
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF125D50), Color(0xFF218A70)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.verified_user_outlined, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text('PROOF OF DELIVERY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
              ]),
              const SizedBox(height: 18),
              const Text('Dokumentasikan\nsetiap pengiriman.', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('Ambil foto atau video bukti serah terima dan simpan secara lokal.', style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Mulai dokumentasi'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF125D50), padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Pilih dokumentasi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionTile(icon: Icons.photo_camera_outlined, title: 'Foto POD', subtitle: 'Bukti serah terima', onTap: onOpenCamera)),
            const SizedBox(width: 12),
            Expanded(child: _ActionTile(icon: Icons.videocam_outlined, title: 'Video POD', subtitle: 'Rekaman pengiriman', onTap: onOpenCamera)),
          ],
        ),
        const SizedBox(height: 22),
        Text('Informasi dokumentasi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const _InfoRow(icon: Icons.schedule, title: 'Tanggal dan waktu', detail: 'Waktu pengambilan dicatat otomatis'),
        const _InfoRow(icon: Icons.photo_camera_outlined, title: 'Foto dan video', detail: 'Disimpan di penyimpanan internal aplikasi'),
        const _InfoRow(icon: Icons.offline_pin_outlined, title: 'Penyimpanan lokal', detail: 'Riwayat dapat dibuka tanpa internet'),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE7F3EF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF146C5A))),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE7F3EF), child: Icon(icon, color: const Color(0xFF146C5A), size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
      )),
    );
  }
}

class _HistoryPage extends StatefulWidget {
  const _HistoryPage({super.key});

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  final _storage = PodStorageService();
  List<PodMediaRecord> _records = const [];
  bool _loading = true;

  Future<void> reload() async {
    setState(() => _loading = true);
    final records = await _storage.loadRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.photo_library_outlined, size: 56, color: Color(0xFF8A9B94)),
          SizedBox(height: 14),
          Text('Belum ada dokumentasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Foto dan video POD yang diambil akan tampil di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ]),
      ));
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final record = _records[index];
          return Card(
            child: ListTile(
              leading: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: const Color(0xFFE7F3EF), borderRadius: BorderRadius.circular(12)),
                child: Icon(record.isVideo ? Icons.videocam : Icons.image, color: const Color(0xFF146C5A), size: 28),
              ),
              title: Text(record.isVideo ? 'Video POD' : 'Foto POD', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(record.createdAt.toLocal())),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => MediaPreviewScreen(record: record),
              )),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: const [
    Card(child: ListTile(leading: Icon(Icons.text_fields), title: Text('Template watermark'), subtitle: Text('Pengaturan watermark akan ditambahkan pada tahap berikutnya.'))),
    Card(child: ListTile(leading: Icon(Icons.gps_fixed), title: Text('Informasi GPS'), subtitle: Text('Integrasi GPS dan alamat sedang dalam tahap berikutnya.'))),
    Card(child: ListTile(leading: Icon(Icons.storage_outlined), title: Text('Penyimpanan'), subtitle: Text('Foto dan video tersimpan di folder privat aplikasi.'))),
    Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Tentang aplikasi'), subtitle: Text('Termul POD Video · 0.1.0'))),
  ]);
}
