import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import 'map_picker_screen.dart';

class CreateActivityScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final LatLng? existingLocation;
  final bool lockCategory;
  final Map<String, dynamic>? prefill;
  final LatLng? prefillLocation;

  const CreateActivityScreen({
    super.key,
    this.existing,
    this.existingLocation,
    this.lockCategory = false,
    this.prefill,
    this.prefillLocation,
  });

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedCategory;
  int _maxParticipants = 10;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  LatLng? _selectedLocation;
  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e['title'] ?? '';
      _descriptionController.text = e['description'] ?? '';
      _locationNameController.text = e['location_name'] ?? '';
      _selectedCategory = e['category_id'] as int?;
      _maxParticipants = e['max_participants'] ?? 10;
      if (e['scheduled_at'] != null) {
        _scheduledAt = DateTime.parse(e['scheduled_at']).toLocal();
      }
      _existingImageUrl = e['image_url'];
      _selectedLocation = widget.existingLocation;
    } else if (widget.prefill != null) {
      final p = widget.prefill!;
      _titleController.text = p['title'] ?? '';
      _descriptionController.text = p['description'] ?? '';
      _locationNameController.text = p['location_name'] ?? '';
      _selectedCategory = p['category_id'] as int?;
      _maxParticipants = p['max_participants'] ?? 10;
      _selectedLocation = widget.prefillLocation;
      // Don't copy old date or image — user picks fresh
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (image != null) setState(() => _selectedImage = image);
  }

  String? _buildChangeSummary() {
    final e = widget.existing;
    if (e == null) return null;
    final changes = <String>[];

    if ((e['title'] ?? '') != _titleController.text.trim()) changes.add('başlık');
    if ((e['description'] ?? '') != _descriptionController.text.trim()) changes.add('açıklama');
    if ((e['location_name'] ?? '') != _locationNameController.text.trim()) changes.add('konum adı');
    if ((e['max_participants'] ?? 0) != _maxParticipants) changes.add('katılımcı sayısı');

    final origDate = e['scheduled_at'] != null ? DateTime.parse(e['scheduled_at']).toLocal() : null;
    if (origDate == null || origDate != _scheduledAt) changes.add('tarih/saat');

    if (widget.existingLocation != null &&
        (widget.existingLocation!.latitude != _selectedLocation?.latitude ||
            widget.existingLocation!.longitude != _selectedLocation?.longitude)) {
      changes.add('konum');
    }

    if (_selectedImage != null) changes.add('resim');

    if (changes.isEmpty) return null;
    if (changes.length == 1) return '${changes.first} değişti';
    final last = changes.removeLast();
    return '${changes.join(', ')} ve $last değişti';
  }

  Future<String?> _uploadImage(String activityId) async {
    if (_selectedImage == null) return null;
    final ext = _selectedImage!.path.split('.').last.toLowerCase();
    final path = '$activityId/cover.$ext';
    await _supabase.storage.from('activity-images').upload(
          path,
          File(_selectedImage!.path),
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('activity-images').getPublicUrl(path);
  }

  List<Map<String, dynamic>> _categoriesFor(AppLocalizations l) => [
        {'id': 1, 'name': l.catWalk, 'icon': '🚶'},
        {'id': 2, 'name': l.catRun, 'icon': '🏃'},
        {'id': 3, 'name': l.catFootball, 'icon': '⚽'},
        {'id': 4, 'name': l.catBasketball, 'icon': '🏀'},
        {'id': 5, 'name': l.catCycling, 'icon': '🚴'},
        {'id': 6, 'name': l.catConcert, 'icon': '🎵'},
        {'id': 7, 'name': l.catTheatre, 'icon': '🎭'},
        {'id': 8, 'name': l.catFood, 'icon': '🍽️'},
        {'id': 9, 'name': l.catMuseum, 'icon': '🏛️'},
        {'id': 10, 'name': l.catCinema, 'icon': '🎬'},
        {'id': 11, 'name': l.catCoffee, 'icon': '☕'},
        {'id': 12, 'name': l.catGames, 'icon': '🎲'},
        {'id': 13, 'name': l.catNature, 'icon': '⛺'},
        {'id': 14, 'name': l.catDance, 'icon': '💃'},
        {'id': 15, 'name': l.catWorkshop, 'icon': '🎨'},
        {'id': 16, 'name': l.catYoga, 'icon': '🧘'},
        {'id': 17, 'name': l.catOther, 'icon': '✨'},
      ];

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result.location;
        if (_locationNameController.text.trim().isEmpty && result.suggestedName != null) {
          _locationNameController.text = result.suggestedName!;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _scheduledAt.isBefore(now) ? now : _scheduledAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).pastDateNotAllowed)),
        );
      }
      return;
    }
    setState(() => _scheduledAt = picked);
  }

  Future<void> _createActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      if (_selectedLocation == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).pleasePickLocation)),
          );
        }
        return;
      }

      final payload = {
        'category_id': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location_name': _locationNameController.text.trim(),
        'scheduled_at': _scheduledAt.toUtc().toIso8601String(),
        'max_participants': _maxParticipants,
        'location': 'POINT(${_selectedLocation!.longitude} ${_selectedLocation!.latitude})',
      };

      String activityId;
      if (_isEdit) {
        activityId = widget.existing!['id'].toString();
        await _supabase.from('activities').update(payload).eq('id', activityId);
      } else {
        final inserted = await _supabase.from('activities').insert({
          ...payload,
          'creator_id': userId,
          'status': 'active',
        }).select('id').single();
        activityId = inserted['id'].toString();
        await _supabase.from('activity_participants').insert({
          'activity_id': activityId,
          'user_id': userId,
          'status': 'approved',
        });
      }

      if (_selectedImage != null) {
        final imageUrl = await _uploadImage(activityId);
        if (imageUrl != null) {
          await _supabase.from('activities').update({'image_url': imageUrl}).eq('id', activityId);
        }
      }

      if (_isEdit) {
        final changes = _buildChangeSummary();
        await NotificationService.notifyActivityUpdated(
          activityId,
          _titleController.text.trim(),
          changes: changes,
        );
      } else {
        // Notify followers about the new activity (fire-and-forget)
        unawaited(NotificationService.notifyFollowersOfNewActivity(
          activityId,
          _titleController.text.trim(),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).activityCreated)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories = _categoriesFor(l);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editActivityTitle : l.createActivity),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(File(_selectedImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : (_existingImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_existingImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: (_selectedImage == null && _existingImageUrl == null)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate, size: 48, color: Color(0xFF616161)),
                          const SizedBox(height: 8),
                          Text(l.imageOptionalAdd, style: const TextStyle(color: Color(0xFF616161))),
                          Text(l.optionalImageHint,
                              style: const TextStyle(color: Color(0xFF616161), fontSize: 12)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l.titleLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? l.titleRequired : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.categoryLabel,
                hintText: l.categoryHint,
                border: const OutlineInputBorder(),
                helperText: widget.lockCategory ? l.categoryLockedHelper : null,
                suffixIcon: widget.lockCategory ? const Icon(Icons.lock, size: 18) : null,
              ),
              items: categories.map((c) {
                return DropdownMenuItem<int>(
                  value: c['id'] as int,
                  child: Row(
                    children: [
                      Text(c['icon'] as String, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(c['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: widget.lockCategory ? null : (v) => setState(() => _selectedCategory = v),
              validator: (v) => v == null ? l.categoryRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationNameController,
              decoration: InputDecoration(
                labelText: l.locationNameLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
              ),
              validator: (v) => v!.isEmpty ? l.locationRequired : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map),
              label: Text(
                _selectedLocation == null
                    ? l.pickLocationFromMap
                    : l.locationPickedAt(
                        _selectedLocation!.latitude.toStringAsFixed(4),
                        _selectedLocation!.longitude.toStringAsFixed(4),
                      ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l.descriptionOptionalLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.dateTimeLabel),
              subtitle: Text(
                '${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year} '
                '${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),
            Row(
              children: [
                Text(l.maxParticipantsRowLabel),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _maxParticipants > 2
                      ? () => setState(() => _maxParticipants--)
                      : null,
                ),
                Text('$_maxParticipants',
                    style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _maxParticipants < 100
                      ? () => setState(() => _maxParticipants++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _createActivity,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(_isEdit ? l.update : l.createButton),
            ),
          ],
        ),
      ),
    );
  }
}
