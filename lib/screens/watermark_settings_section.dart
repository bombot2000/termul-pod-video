import 'package:flutter/material.dart';

import '../services/pod_watermark_settings_service.dart';

class WatermarkSettingsSection extends StatefulWidget {
  const WatermarkSettingsSection({super.key});

  @override
  State<WatermarkSettingsSection> createState() =>
      _WatermarkSettingsSectionState();
}

class _WatermarkSettingsSectionState extends State<WatermarkSettingsSection> {
  final _settings = PodWatermarkSettingsService();
  late Future<PodWatermarkLayout> _layout = _settings.loadLayout();
  bool _saving = false;

  Future<void> _save(PodWatermarkLayout layout) async {
    setState(() => _saving = true);
    try {
      await _settings.saveLayout(layout);
      if (!mounted) return;
      setState(() => _layout = Future.value(layout));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template watermark berhasil disimpan.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan template: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Tampilan watermark',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 6),
        Text(
          'Pilih susunan informasi yang akan tertanam pada foto dan video POD berikutnya.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FutureBuilder<PodWatermarkLayout>(
          future: _layout,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Pengaturan watermark belum dapat dibaca.'),
                ),
              );
            }
            final selected = snapshot.data!;
            return Column(
              children: PodWatermarkLayout.values.map((layout) {
                final active = layout == selected;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _saving || active ? null : () => _save(layout),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WatermarkLayoutPreview(layout: layout, selected: active),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(layout.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Text(layout.description,
                                    style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 8),
                                if (active)
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Color(0xFF146C5A), size: 17),
                                      SizedBox(width: 5),
                                      Text('Sedang digunakan',
                                          style: TextStyle(
                                            color: Color(0xFF146C5A),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          )),
                                    ],
                                  )
                                else
                                  const Text('Ketuk untuk memilih',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (_saving) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.gps_fixed),
            title: Text('Informasi GPS'),
            subtitle: Text(
              'Koordinat, akurasi, dan alamat dicatat jika izin GPS serta layanan geocoding tersedia. Jika alamat gagal diperoleh, dokumentasi tetap disimpan.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Penyimpanan'),
            subtitle: Text(
              'Foto dan video tersimpan di perangkat dan dapat diekspor ke album Galeri Termul POD. Backup cloud belum tersedia.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Tentang aplikasi'),
            subtitle: Text('Termul POD Video · 0.1.0'),
          ),
        ),
      ],
    );
  }
}

class _WatermarkLayoutPreview extends StatelessWidget {
  const _WatermarkLayoutPreview({
    required this.layout,
    required this.selected,
  });

  final PodWatermarkLayout layout;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF132C26);
    const mint = Color(0xFF78E0BE);
    return Container(
      width: 92,
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECE9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF146C5A) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFD5DED9),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          if (layout == PodWatermarkLayout.classic)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 31,
              child: Container(
                padding: const EdgeInsets.all(4),
                color: ink,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewLine(width: 48, color: mint),
                    SizedBox(height: 4),
                    _PreviewLine(width: 70, color: Colors.white),
                    SizedBox(height: 3),
                    _PreviewLine(width: 58, color: Colors.white),
                  ],
                ),
              ),
            ),
          if (layout == PodWatermarkLayout.compact)
            Positioned(
              left: 0,
              bottom: 0,
              width: 61,
              height: 38,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewLine(width: 48, color: mint),
                    SizedBox(height: 5),
                    _PreviewLine(width: 40, color: Colors.white),
                    SizedBox(height: 4),
                    _PreviewLine(width: 30, color: Colors.white),
                  ],
                ),
              ),
            ),
          if (layout == PodWatermarkLayout.header)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 32,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: ink,
                  border: Border(left: BorderSide(color: mint, width: 4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewLine(width: 50, color: mint),
                    SizedBox(height: 4),
                    _PreviewLine(width: 72, color: Colors.white),
                    SizedBox(height: 3),
                    _PreviewLine(width: 43, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
