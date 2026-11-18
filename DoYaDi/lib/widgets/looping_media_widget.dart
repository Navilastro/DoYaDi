import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../core/utils/app_translations.dart';

/// Desteklenen medya formatları: Görsel, GIF, Video (.mp4, .webm, .mov, vb.)
enum AppMediaType {
  none,
  image, // PNG, JPG, WEBP, GIF
  video, // MP4, MKV, WEBM, MOV
}

class AppMediaHelper {
  static const List<String> videoExtensions = [
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    '3gp',
    'flv',
  ];

  static const List<String> imageExtensions = [
    'gif',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
  ];

  static AppMediaType getMediaType(String? path) {
    if (path == null || path.trim().isEmpty) return AppMediaType.none;
    final lower = path.trim().toLowerCase();
    for (final ext in videoExtensions) {
      if (lower.endsWith('.$ext') || lower.contains('.$ext?')) {
        return AppMediaType.video;
      }
    }
    return AppMediaType.image;
  }

  static bool isVideo(String? path) => getMediaType(path) == AppMediaType.video;
  static bool isImageOrGif(String? path) => getMediaType(path) == AppMediaType.image;
  static bool hasMedia(String? path) => path != null && path.trim().isNotEmpty;
}

/// Döngüde video veya GIF / görsel oynatan evrensel widget.
class LoopingMediaWidget extends StatefulWidget {
  final String? mediaPath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;
  final Alignment alignment;

  const LoopingMediaWidget({
    super.key,
    required this.mediaPath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
    this.alignment = Alignment.center,
  });

  @override
  State<LoopingMediaWidget> createState() => _LoopingMediaWidgetState();
}

class _LoopingMediaWidgetState extends State<LoopingMediaWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _currentPath;
  ImageProvider? _cachedImageProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPath = widget.mediaPath;
    _initMedia();
  }

  @override
  void didUpdateWidget(covariant LoopingMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaPath != oldWidget.mediaPath) {
      _currentPath = widget.mediaPath;
      _disposeController();
      _initMedia();
    } else if (_controller != null &&
        _isInitialized &&
        !_controller!.value.isPlaying &&
        !_controller!.value.isBuffering) {
      _controller!.play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _controller != null &&
        _isInitialized &&
        !_controller!.value.isPlaying) {
      _controller!.play();
    }
  }

  void _onVideoControllerUpdate() {
    final ctrl = _controller;
    if (!mounted || ctrl == null || !_isInitialized) return;
    if (!ctrl.value.isPlaying && !ctrl.value.isBuffering && !ctrl.value.hasError) {
      ctrl.play();
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onVideoControllerUpdate);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _cachedImageProvider = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  void _initMedia() {
    final path = _currentPath?.trim();
    if (path == null || path.isEmpty) {
      _cachedImageProvider = null;
      return;
    }

    if (AppMediaHelper.isVideo(path)) {
      _cachedImageProvider = null;
      final isNetwork = path.startsWith('http://') || path.startsWith('https://');
      final isAsset = path.startsWith('assets/');
      final options = VideoPlayerOptions(mixWithOthers: true);

      if (isNetwork) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(path),
          videoPlayerOptions: options,
        );
      } else if (isAsset) {
        _controller = VideoPlayerController.asset(
          path,
          videoPlayerOptions: options,
        );
      } else {
        _controller = VideoPlayerController.file(
          File(path),
          videoPlayerOptions: options,
        );
      }

      _controller?.setLooping(true);
      _controller?.setVolume(0.0); // Arka plan videoları sessiz oynatılır
      _controller?.initialize().then((_) {
        if (mounted && _controller != null) {
          setState(() {
            _isInitialized = true;
          });
          _controller?.play();
          _controller?.addListener(_onVideoControllerUpdate);
        }
      }).catchError((err) {
        debugPrint('Video oynatıcı başlatma hatası ($path): $err');
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
      });
    } else {
      final isNetwork = path.startsWith('http://') || path.startsWith('https://');
      final isAsset = path.startsWith('assets/');
      if (isNetwork) {
        _cachedImageProvider = NetworkImage(path);
      } else if (isAsset) {
        _cachedImageProvider = AssetImage(path);
      } else {
        _cachedImageProvider = FileImage(File(path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPath?.trim();
    if (path == null || path.isEmpty) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    if (AppMediaHelper.isVideo(path)) {
      if (_controller != null && _isInitialized) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: FittedBox(
            fit: widget.fit,
            alignment: widget.alignment,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width > 0
                  ? _controller!.value.size.width
                  : 1920,
              height: _controller!.value.size.height > 0
                  ? _controller!.value.size.height
                  : 1080,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      } else {
        return widget.fallback ?? const SizedBox.shrink();
      }
    }

    // Görsel veya GIF
    final ImageProvider imageProvider = _cachedImageProvider ??
        (path.startsWith('http://') || path.startsWith('https://')
            ? NetworkImage(path)
            : (path.startsWith('assets/')
                ? AssetImage(path) as ImageProvider
                : FileImage(File(path))));

    return Image(
      image: imageProvider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      errorBuilder: (ctx, err, stack) {
        return widget.fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Arka planda GIF veya video varken camsı (frosted glass) efekt sunan kapsayıcı.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final bool isGlassActive;
  final Color? solidBackgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.isGlassActive = false,
    this.solidBackgroundColor,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.blurSigma = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);

    if (!isGlassActive) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: solidBackgroundColor ?? Colors.white.withValues(alpha: 0.04),
          borderRadius: br,
          border: border ?? Border.all(color: Colors.white12),
        ),
        child: child,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (solidBackgroundColor ?? Colors.black).withValues(alpha: 0.35),
              borderRadius: br,
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Görsel/GIF/Video üzerindeki yazıların kaybolmaması için arkasına blurlu yarı saydam katman koyar.
class BlurredTextChip extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? backdropColor;
  final double blurSigma;

  const BlurredTextChip({
    super.key,
    required this.child,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderRadius,
    this.backdropColor,
    this.blurSigma = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final br = borderRadius ?? BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backdropColor ?? Colors.black.withValues(alpha: 0.42),
            borderRadius: br,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Kullanıcının cihazdan görsel/GIF/video seçebilmesini veya URL/Dosya yolu girmesini sağlayan dialog.
Future<String?> showAppMediaPickerDialog(
  BuildContext context, {
  required String title,
  required String? currentPath,
}) async {
  final textController = TextEditingController(text: currentPath ?? '');

  return showDialog<String?>(
    context: context,
    builder: (dctx) {
      return StatefulBuilder(
        builder: (dctx, setStateDialog) {
          final cur = textController.text.trim();
          final bool hasValue = cur.isNotEmpty;

          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                const Icon(Icons.perm_media_outlined, color: Color(0xFF40E0D0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('media_picker_desc'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Önizleme kutusu
                  if (hasValue)
                    Container(
                      height: 110,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          LoopingMediaWidget(
                            mediaPath: cur,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            fallback: Center(
                              child: Text(
                                AppTranslations.getText('media_preview_failed'),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.white70, size: 20),
                              onPressed: () {
                                setStateDialog(() {
                                  textController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Cihazdan Seç Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40E0D0),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                        AppTranslations.getText('choose_from_device'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: [
                              ...AppMediaHelper.imageExtensions,
                              ...AppMediaHelper.videoExtensions,
                            ],
                          );
                          if (result != null && result.files.single.path != null) {
                            setStateDialog(() {
                              textController.text = result.files.single.path!;
                            });
                          }
                        } catch (e) {
                          debugPrint('File picker hatası: $e');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Veya dosya yolu / URL girme TextField
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (_) => setStateDialog(() {}),
                    decoration: InputDecoration(
                      labelText: AppTranslations.getText('media_path_or_url'),
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      hintText: 'C:/dosya.gif veya https://...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF40E0D0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (hasValue)
                TextButton(
                  onPressed: () => Navigator.pop(dctx, ''),
                  child: Text(
                    AppTranslations.getText('clear'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF40E0D0),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(dctx, textController.text.trim()),
                child: Text(AppTranslations.getText('apply')),
              ),
            ],
          );
        },
      );
    },
  );
}

