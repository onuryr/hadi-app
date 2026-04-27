import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../widgets/error_state.dart';
import 'profile_screen.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListMode mode;
  const FollowListScreen({super.key, required this.userId, required this.mode});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final selfCol = widget.mode == FollowListMode.followers ? 'followee_id' : 'follower_id';
      final otherCol = widget.mode == FollowListMode.followers ? 'follower_id' : 'followee_id';
      final rows = await _supabase
          .from('follows')
          .select('$otherCol, users!follows_${otherCol}_fkey(id, display_name, avatar_url)')
          .eq(selfCol, widget.userId)
          .order('created_at', ascending: false);
      final list = (rows as List)
          .map<Map<String, dynamic>>((r) {
            final u = r['users'] as Map<String, dynamic>?;
            return u ?? {'id': r[otherCol]};
          })
          .toList();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = widget.mode == FollowListMode.followers ? l.followers : l.followingTitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? ErrorState(onRetry: _load)
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        widget.mode == FollowListMode.followers ? l.noFollowers : l.noFollowing,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final u = _items[i];
                          final name = (u['display_name'] as String?) ?? l.unknownUser;
                          final avatarUrl = u['avatar_url'] as String?;
                          final id = u['id']?.toString();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                                  : null,
                            ),
                            title: Text(name),
                            onTap: id == null
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(userId: id),
                                      ),
                                    ),
                          );
                        },
                      ),
                    ),
    );
  }
}
