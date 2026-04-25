import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/report_block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ReportBlockService.getMyBlocks();
      if (mounted) setState(() { _blocked = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _unblock(Map<String, dynamic> entry) async {
    final userId = entry['userId']?.toString() ?? '';
    final name = entry['displayName']?.toString() ?? 'Kullanıcı';
    setState(() => _unblocking.add(userId));
    try {
      await ReportBlockService.unblockUser(userId);
      if (mounted) {
        setState(() {
          _blocked.removeWhere((e) => e['userId']?.toString() == userId);
          _unblocking.remove(userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name engeli kaldırıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _unblocking.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engellediklerim'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Engellenmiş kullanıcı yok', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blocked.length,
                  itemBuilder: (context, index) {
                    final entry = _blocked[index];
                    final userId = entry['userId']?.toString() ?? '';
                    final name = entry['displayName']?.toString() ?? 'Bilinmiyor';
                    final avatarUrl = entry['avatarUrl'] as String?;
                    final isUnblocking = _unblocking.contains(userId);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text(name),
                      trailing: isUnblocking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _unblock(entry),
                              child: const Text('Engeli Kaldır', style: TextStyle(color: Colors.red)),
                            ),
                    );
                  },
                ),
    );
  }
}
