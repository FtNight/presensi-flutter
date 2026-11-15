import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class ServerSettingsDialog extends StatefulWidget {
  final VoidCallback? onSaved;

  const ServerSettingsDialog({super.key, this.onSaved});

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final current = await ApiConfig.getBaseUrl();
    setState(() {
      _controller.text = current;
      _isLoading = false;
    });
  }

  Future<void> _saveUrl(String url) async {
    if (url.trim().isEmpty) return;
    await ApiConfig.setBaseUrl(url.trim());
    ApiService().resetClient();
    if (widget.onSaved != null) widget.onSaved!();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL Server berhasil disimpan: ${url.trim()}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text('Pengaturan URL Server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubah IP / Port server backend FastAPI jika koneksi Wi-Fi berubah:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Base URL Server',
                    hintText: 'http://10.205.87.242:8000',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    _controller.text = ApiConfig.defaultBaseUrl;
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Gunakan IP Default Laptop', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => _saveUrl(_controller.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
