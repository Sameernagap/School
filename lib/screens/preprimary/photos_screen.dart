import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'diary_common.dart';

/// Parent / student: photo albums the family may see.
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Photos',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/albums'),
        builder: (context, data, reload) {
          final albums = (data as List? ?? const []).cast<Map>();
          if (albums.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyView(
                icon: Icons.photo_library_rounded,
                color: AppColors.pink,
                message: 'No photos yet. Photos of class activities shared by the teacher appear here.',
              ),
            ]);
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 0.82),
            itemCount: albums.length,
            itemBuilder: (context, i) => AlbumCard(
              album: Map<String, dynamic>.from(albums[i]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AlbumScreen(studentId: studentId, albumId: albums[i]['id'] as int)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Album tile: cover photo, title, date and number of photos.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap, this.badge});

  final Map<String, dynamic> album;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cover = album['cover_url'] as String?;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover == null
                      ? Container(
                          color: AppColors.soft(AppColors.pink),
                          child: const Icon(Icons.photo_camera_rounded, color: AppColors.pink, size: 40))
                      : ServerImage(path: cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.night.withAlpha(200), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('${album['photo_count'] ?? 0}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  if (badge != null) Positioned(left: 8, top: 8, child: badge!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((album['title'] ?? '').toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(fmtDate(album['date']), style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.studentId, required this.albumId});

  final int studentId;
  final int albumId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Album',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/albums/$albumId'),
        builder: (context, data, reload) {
          final album = Map<String, dynamic>.from(data as Map);
          final photos = (album['photos'] as List? ?? const []).cast<Map>();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((album['title'] ?? '').toString(), style: headingStyle(size: 22)),
                      Text('${fmtDate(album['date'])} · ${photos.length} photos',
                          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                      if ((album['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(album['description'].toString()),
                      ],
                    ],
                  ),
                ),
              ),
              PhotoGrid(photos: photos),
            ],
          );
        },
      ),
    );
  }
}

/// Square photo grid; tap opens the full-screen viewer.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, this.onLongPress});

  final List<Map> photos;
  final void Function(Map photo)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverGrid(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final photo = photos[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PhotoViewer(photos: photos, initial: i)),
              ),
              onLongPress: onLongPress == null ? null : () => onLongPress!(photo),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ServerImage(path: photo['thumb_url'] as String),
              ),
            );
          },
          childCount: photos.length,
        ),
      ),
    );
  }
}

/// Full-screen photos: swipe, pinch to zoom, open / share the full photo.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, required this.initial});

  final List<Map> photos;
  final int initial;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final caption = (photo['caption'] ?? '').toString();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Open / save',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => openRemoteFile(context, photo['url'] as String, 'school_photo_${photo['id']}.jpg'),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(child: ServerImage(path: widget.photos[i]['url'] as String, fit: BoxFit.contain)),
            ),
          ),
          if (caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: BorderRadius.circular(14)),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}
