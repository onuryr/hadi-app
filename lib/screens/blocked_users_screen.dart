import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: $e')),
        );
      }
    }
  }

  Future<void> _unblock(Map<String, dynamic> entry) async {
    final userId = entry['userId']?.toString() ?? '';
    final l = AppLocalizations.of(context);
    final name = entry['displayName']?.toString() ?? l.unknownUser;
    setState(() => _unblocking.add(userId));
    try {
      await ReportBlockService.unblockUser(userId);
      if (mounted) {
        setState(() {
          _blocked.removeWhere((e) => e['userId']?.toString() == userId);
          _unblocking.remove(userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name — ${AppLocalizations.of(context).unblockedSuccess}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _unblocking.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).unblockFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.blockedUsers),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(l.noBlockedUsers, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blocked.length,
                  itemBuilder: (context, index) {
                    final entry = _blocked[index];
                    final userId = entry['userId']?.toString() ?? '';
                    final name = entry['displayName']?.toString() ?? l.unknownUser;
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
                              child: Text(l.unblock, style: const TextStyle(color: Colors.red)),
                            ),
                    );
                  },
                ),
    );
  }
}
