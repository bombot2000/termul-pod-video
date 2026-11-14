import 'package:flutter/material.dart';

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

  static const _titles = ['Dokumentasi POD', 'Riwayat', 'Pengaturan'];

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
            onPressed: () => _showInfo(context, 'Mode offline aktif', 'Dokumentasi disiapkan agar dapat disimpan secara lokal saat jaringan tidak tersedia.'),
            icon: const Icon(Icons.cloud_off_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_CaptureDashboard(), _HistoryPlaceholder(), _SettingsPlaceholder()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Dokumentasi'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Pengaturan'),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }
}

class _CaptureDashboard extends StatelessWidget {
  const _CaptureDashboard();

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
              const Text('Foto dan video dengan informasi waktu serta lokasi.', style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showComingSoon(context, 'Kamera POD'),
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
            Expanded(child: _ActionTile(icon: Icons.photo_camera_outlined, title: 'Foto POD', subtitle: 'Bukti serah terima', onTap: () => _showComingSoon(context, 'Kamera foto'))),
            const SizedBox(width: 12),
            Expanded(child: _ActionTile(icon: Icons.videocam_outlined, title: 'Video POD', subtitle: 'Rekaman pengiriman', onTap: () => _showComingSoon(context, 'Kamera video'))),
          ],
        ),
        const SizedBox(height: 22),
        Text('Informasi dokumentasi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const _InfoRow(icon: Icons.schedule, title: 'Tanggal dan waktu', detail: 'Timestamp otomatis'),
        const _InfoRow(icon: Icons.location_on_outlined, title: 'Lokasi GPS', detail: 'Koordinat dan akurasi lokasi'),
        const _InfoRow(icon: Icons.layers_outlined, title: 'Watermark', detail: 'Template yang dapat disesuaikan'),
        const _InfoRow(icon: Icons.offline_pin_outlined, title: 'Penyimpanan lokal', detail: 'Siap digunakan tanpa koneksi internet'),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('Modul ini sedang disiapkan. Fondasi antarmuka sudah tersedia; integrasi kamera, GPS, dan watermark akan ditambahkan bertahap.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))],
      ),
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
        trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF27836D), size: 20),
      )),
    );
  }
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.photo_library_outlined, size: 56, color: Color(0xFF8A9B94)),
        SizedBox(height: 14),
        Text('Belum ada dokumentasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('Hasil foto dan video POD akan tampil di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ]),
    ),
  );
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: const [
    Card(child: ListTile(leading: Icon(Icons.text_fields), title: Text('Template watermark'), subtitle: Text('Pengaturan desain watermark akan tersedia pada tahap berikutnya.'))),
    Card(child: ListTile(leading: Icon(Icons.gps_fixed), title: Text('Informasi GPS'), subtitle: Text('Pengaturan akurasi dan tampilan lokasi.'))),
    Card(child: ListTile(leading: Icon(Icons.storage_outlined), title: Text('Penyimpanan'), subtitle: Text('Lokasi penyimpanan dokumentasi lokal.'))),
    Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Tentang aplikasi'), subtitle: Text('Termul POD Video · 0.1.0'))),
  ]);
}
