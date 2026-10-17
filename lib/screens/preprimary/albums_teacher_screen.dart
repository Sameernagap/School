import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'diary_common.dart';
import 'photos_screen.dart';

const _stateLabels = {'draft': 'Draft', 'pending': 'Waiting approval', 'published': 'Shared'};
const _stateColors = {'draft': AppColors.slate, 'pending': AppColors.amber, 'published': AppColors.emerald};

/// Teacher: photo albums of my classes.
class TeacherAlbumsScreen extends StatefulWidget {
  const TeacherAlbumsScreen({super.key});

  @override
  State<TeacherAlbumsScreen> createState() => _TeacherAlbumsScreenState();
}

class _TeacherAlbumsScreenState extends State<TeacherAlbumsScreen> {
  int _version = 0;

  Future<void> _newAlbum() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewAlbumSheet(),
    );
    if (created == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherAlbumScreen(albumId: created['id'] as int)));
    setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Photos',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.sun,
        foregroundColor: AppColors.ink,
        onPressed: _newAlbum,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('New album', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AsyncView<dynamic>(
        reloadKey: _version,
        loader: () => api.get('/teacher/albums', query: {'limit': '60'}),
        builder: (context, data, reload) {
          final albums = ((data as Map)['items'] as List? ?? const []).cast<Map>();
          if (albums.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyView(
                icon: Icons.photo_camera_rounded,
                color: AppColors.pink,
                message: 'Make an album, take photos of the activity and share them privately with the parents.',
              ),
            ]);
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 0.82),
            itemCount: albums.length,
            itemBuilder: (context, i) {
              final album = Map<String, dynamic>.from(albums[i]);
              final state = (album['state'] ?? 'draft').toString();
              return AlbumCard(
                album: album,
                badge: StatusChip(label: _stateLabels[state] ?? state, color: _stateColors[state]),
                onTap: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => TeacherAlbumScreen(albumId: album['id'] as int)));
                  setState(() => _version++);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Title, classes and who may see the photos.
class _NewAlbumSheet extends StatefulWidget {
  const _NewAlbumSheet();

  @override
  State<_NewAlbumSheet> createState() => _NewAlbumSheetState();
}

class _NewAlbumSheetState extends State<_NewAlbumSheet> {
  final _title = TextEditingController();
  final Set<int> _sections = {};
  String _audience = 'class';
  List<Map> _mySections = [];
  bool _busy = false;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _api.get('/teacher/sections').then((data) {
      if (!mounted) return;
      setState(() {
        _mySections = (data as List).cast<Map>();
        if (_mySections.length == 1) _sections.add(_mySections.first['id'] as int);
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty || _sections.isEmpty) {
      showMessage(context, 'Write a title and choose a class.', error: true);
      return;
    }
    setState(() => _busy = true);
    Map<String, dynamic>? album;
    await runAction(context, () async {
      album = Map<String, dynamic>.from(await _api.post('/teacher/albums', {
        'title': _title.text.trim(),
        'section_ids': _sections.toList(),
        'audience': _audience,
      }) as Map);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (album != null) Navigator.pop(context, album);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New photo album', style: headingStyle(size: 21)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Diwali celebration'),
          ),
          const SizedBox(height: 14),
          const Text('Classes', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _mySections)
                FilterChip(
                  label: Text((s['name'] ?? '').toString()),
                  selected: _sections.contains(s['id']),
                  onSelected: (on) => setState(() => on ? _sections.add(s['id'] as int) : _sections.remove(s['id'])),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Who can see the photos', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'class',
            groupValue: _audience,
            onChanged: (v) => setState(() => _audience = v!),
            title: const Text('All families of these classes'),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'tagged',
            groupValue: _audience,
            onChanged: (v) => setState(() => _audience = v!),
            title: const Text('Only families of children tagged in a photo'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : _create,
            child: Text(_busy ? 'Please wait…' : 'Create and add photos'),
          ),
        ],
      ),
    );
  }
}

/// Teacher: one album. Add photos (camera / gallery), tag children, share with parents.
class TeacherAlbumScreen extends StatefulWidget {
  const TeacherAlbumScreen({super.key, required this.albumId});

  final int albumId;

  @override
  State<TeacherAlbumScreen> createState() => _TeacherAlbumScreenState();
}

class _TeacherAlbumScreenState extends State<TeacherAlbumScreen> {
  final _picker = ImagePicker();
  Map<String, dynamic>? _album;
  String? _error;
  int _uploading = 0;
  int _uploaded = 0;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _album = Map<String, dynamic>.from(await _api.get('/teacher/albums/${widget.albumId}') as Map);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _add(ImageSource source) async {
    List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
        files = file == null ? [] : [file];
      } else {
        files = await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80, limit: 30);
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.', error: true);
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      _uploading = files.length;
      _uploaded = 0;
    });
    var failed = 0;
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        await _api.post('/teacher/albums/${widget.albumId}/photos', {'image': base64Encode(bytes)});
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _uploaded++);
    }
    if (!mounted) return;
    setState(() => _uploading = 0);
    if (failed > 0) showMessage(context, '$failed photo(s) could not be uploaded.', error: true);
    await _load();
    if (source == ImageSource.camera && mounted) _add(ImageSource.camera); // keep taking photos
  }

  Future<void> _share() async {
    final album = _album!;
    final ok = await confirmDialog(
      context,
      'Share with parents?',
      album['audience'] == 'tagged'
          ? 'Each family will see only the photos in which their child is tagged.'
          : 'All families of ${(album['sections'] as List).map((s) => s['name']).join(', ')} will get a notification.',
      ok: 'Share',
    );
    if (!ok || !mounted) return;
    await runAction(context, () async {
      _album = Map<String, dynamic>.from(await _api.post('/teacher/albums/${widget.albumId}/share') as Map);
    }, success: 'Done');
    _load();
  }

  Future<void> _editPhoto(Map photo) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoSheet(
        albumId: widget.albumId,
        photo: photo,
        students: ((_album?['students'] as List?) ?? const []).cast<Map>(),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final album = _album;
    if (album == null) {
      return PageScaffold(
        title: 'Album',
        body: _error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final photos = (album['photos'] as List? ?? const []).cast<Map>();
    final state = (album['state'] ?? 'draft').toString();
    return PageScaffold(
      title: 'Album',
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text((album['title'] ?? '').toString(), style: headingStyle(size: 22))),
                            StatusChip(label: _stateLabels[state] ?? state, color: _stateColors[state]),
                          ],
                        ),
                        Text(
                          '${(album['sections'] as List).map((s) => s['name']).join(', ')} · '
                          '${album['audience'] == 'tagged' ? 'tagged families only' : 'all families'}',
                          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                        ),
                        if (photos.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Long-press a photo to tag children or add a caption.',
                                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ),
                        if (_uploading > 0) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: _uploaded / _uploading, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                          const SizedBox(height: 4),
                          Text('Uploading $_uploaded of $_uploading…', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (photos.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyView(
                          icon: Icons.add_photo_alternate_rounded,
                          color: AppColors.pink,
                          message: 'Take photos or choose them from the gallery.'),
                    ),
                  )
                else
                  PhotoGrid(photos: photos, onLongPress: _editPhoto),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Camera',
                    onPressed: _uploading > 0 ? null : () => _add(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Gallery',
                    onPressed: _uploading > 0 ? null : () => _add(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sun, foregroundColor: AppColors.ink, minimumSize: const Size.fromHeight(50)),
                      onPressed: state != 'draft' || photos.isEmpty || _uploading > 0 ? null : _share,
                      icon: const Icon(Icons.share_rounded),
                      label: Text(state == 'draft' ? 'Share with parents' : (_stateLabels[state] ?? state)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caption, children in the photo, delete.
class _PhotoSheet extends StatefulWidget {
  const _PhotoSheet({required this.albumId, required this.photo, required this.students});

  final int albumId;
  final Map photo;
  final List<Map> students;

  @override
  State<_PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<_PhotoSheet> {
  late final TextEditingController _caption = TextEditingController(text: (widget.photo['caption'] ?? '').toString());
  late final Set<int> _tagged = {
    for (final s in (widget.photo['students'] as List? ?? const [])) (s as Map)['id'] as int,
  };
  bool _busy = false;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runAction(context, () async {
      await _api.post('/teacher/albums/${widget.albumId}/photos/${widget.photo['id']}',
          {'caption': _caption.text, 'student_ids': _tagged.toList()});
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Delete this photo?', 'Parents will not see it any more.', ok: 'Delete');
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await _api.post('/teacher/albums/${widget.albumId}/photos/${widget.photo['id']}/delete');
    });
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ServerImage(path: widget.photo['thumb_url'] as String, width: 72, height: 72),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Photo details', style: headingStyle(size: 19))),
              IconButton(
                  tooltip: 'Delete', onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Caption (optional)')),
          const SizedBox(height: 12),
          const Text('Children in this photo', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in widget.students)
                    FilterChip(
                      label: Text((s['name'] ?? '').toString()),
                      selected: _tagged.contains(s['id']),
                      onSelected: (on) => setState(() => on ? _tagged.add(s['id'] as int) : _tagged.remove(s['id'])),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
