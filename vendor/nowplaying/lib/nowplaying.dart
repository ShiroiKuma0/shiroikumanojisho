/// A library that surfaces metadata for the track currently playing over the
/// device's audio, outside the control of the importing app.
///
/// Use a NotificationListenerService for Android; polls the current playing
/// information from the systemMusicPlayer for iOS

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';

bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isAndroid => !kIsWeb && Platform.isAndroid;

/// A container for the service. Connects with the underlying OS via a method
/// channel to pull out track data.
class NowPlaying with WidgetsBindingObserver {
  static const _channel = const MethodChannel('gomes.com.es/nowplaying');
  static const _refreshPeriod = const Duration(seconds: 1);

  StreamController<NowPlayingTrack>? _controller;
  Stream<NowPlayingTrack> get stream => _controller!.stream;

  static NowPlaying instance = NowPlaying._();
  NowPlaying._();

  Timer? _refreshTimer;

  late NowPlayingImageResolver _resolver;
  NowPlayingTrack track = NowPlayingTrack.notPlaying;
  bool _resolveImages = false;

  /// Starts the service.
  ///
  /// Initialises stream, sets up the app lifecycle observer, starts a polling
  /// timer on iOS, sets incoming method handler for Android
  Future<void> start({bool resolveImages = false, NowPlayingImageResolver? resolver}) async {
    // async, but should not be awaited
    this._resolveImages = resolver != null || resolveImages;
    this._resolver = resolver ?? DefaultNowPlayingImageResolver();

    this.track = NowPlayingTrack.notPlaying;

    _controller = StreamController<NowPlayingTrack>.broadcast();
    _controller!.add(NowPlayingTrack.notPlaying);

    await _bindToWidgetsBinding();
    if (isAndroid) _channel.setMethodCallHandler(_handler);
    if (isIOS) _refreshTimer = Timer.periodic(_refreshPeriod, _refresh);

    final info = await PackageInfo.fromPlatform();
    print('NowPlaying is part of ${info.packageName}');

    await _refresh();
  }

  /// Stops the service.
  ///
  /// Kills stream, timer and method call handler
  void stop() {
    _controller?.close();
    _controller = null;

    WidgetsBinding.instance!.removeObserver(this);
    if (isAndroid) _channel.setMethodCallHandler(null);
    if (isIOS) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _updateAndNotifyFor(NowPlayingTrack track) {
    if (_resolveImages) _resolveImageFor(track);
    _controller!.add(track);
    this.track = track;
  }

  void _resolveImageFor(NowPlayingTrack track) async {
    if (track.imageNeedsResolving) {
      await track._resolveImage();
      this.track = track.copy();
      _controller!.add(this.track);
    }
  }

  /// Returns true is the service has permission granted by the systme and user
  Future<bool> isEnabled() async {
    return isIOS || (await _channel.invokeMethod<bool>('isEnabled') ?? false);
  }

  /// Opens an OS settings page
  ///
  /// Returns true if:
  ///   - OS is iOS, or
  ///   - permission has already been given, or
  ///   - the settings screen has not been opened by this app before, or
  ///   - opening the screen this time is `force`d
  ///
  /// Returns false if:
  ///   - OS is Android, and
  ///   - permission has not been given by the user, and
  ///   - the settings screen has been opened by this app before
  Future<bool> requestPermissions({bool force = false}) async {
    if (isIOS) return true;

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/com.gomes.nowplaying');
    if (!force && await file.exists()) return false;

    file.create();
    await _channel.invokeMethod<bool>('requestPermissions');
    return true;
  }

  // Android
  Future<dynamic> _handler(MethodCall call) async {
    if (call.method == 'track') {
      final data = Map<String, Object?>.from(call.arguments[0] ?? {});
      _updateAndNotifyFor(NowPlayingTrack.fromJson(data));
    }
    return true;
  }
  // /Android

  // iOS
  Future<void> _refresh([_]) async {
    final data = await _channel.invokeMethod('track');
    final json = Map<String, Object?>.from(data);
    final track = NowPlayingTrack.fromJson(json);
    if (_shouldNotifyFor(track)) _updateAndNotifyFor(track);
  }

  bool _shouldNotifyFor(NowPlayingTrack newTrack) {
    if (newTrack.isStopped) return !this.track.isStopped;

    final positionDifferential = (newTrack.position - this.track.position).inMilliseconds;
    final timeDifferential = newTrack._createdAt.difference(this.track._createdAt).inMilliseconds;
    final positionUnexpected = positionDifferential < 0 || positionDifferential > timeDifferential + 250;

    if (newTrack.id != this.track.id || newTrack.state != this.track.state || positionUnexpected) {
      switch (newTrack.state) {
        case NowPlayingState.playing:
          return true;
        case NowPlayingState.paused:
          return this.track.isStopped || (this.track.isPlaying && newTrack.id == this.track.id);
        default:
          return false;
      }
    }

    return false;
  }
  // /iOS

  Future<bool> _bindToWidgetsBinding() async {
    if (WidgetsBinding.instance?.isRootWidgetAttached == true) {
      WidgetsBinding.instance!.addObserver(this);
      return true;
    } else {
      return Future.delayed(const Duration(milliseconds: 250), _bindToWidgetsBinding);
    }
  }

  /// Respond to changes in the app lifecycle state, on iOS
  ///
  /// Restart timer if resumed; else cancel it
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isIOS) _refreshTimer ??= Timer.periodic(_refreshPeriod, _refresh);
      _refresh();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      this.track = NowPlayingTrack.notPlaying;
    }
  }
}

enum _NowPlayingImageResolutionState { unresolved, resolving, resolved }

/// A container for metadata around a single track state
///
/// Artist, album, track, duration, genre, source, progress
class NowPlayingTrack {
  static final NowPlayingTrack notPlaying = NowPlayingTrack();

  static final _essentialRegExp = RegExp(r'\(.*\)|\[.*\]');

  static final _images = _LruMap<String, ImageProvider?>(size: 3);
  static final _resolutionStates =
      _LruMap<String, _NowPlayingImageResolutionState?>(size: 3);
  static final _icons = _LruMap<String?, ImageProvider>();

  final String? id;
  final String? title;
  final String? album;
  final String? artist;
  final String? source;
  final Duration duration;
  final Duration position;
  final DateTime _createdAt;
  final NowPlayingState state;

  /// How long the track been has been playing, as a `Duration`
  ///
  /// If the track is playing: how much had been played at the time the state
  /// was recorded, plus elapsed time since then
  ///
  /// If the track is not playing: how much had been played at the time the state
  /// was recorded
  Duration get progress {
    if (state == NowPlayingState.playing) return position + DateTime.now().difference(_createdAt);
    return position;
  }

  String? get essentialAlbum => _essential(album);
  String? get essentialTitle => _essential(title);
  String? _essential(String? text) {
    if (text == null) return null;
    final String essentialText = text.replaceAll(_essentialRegExp, '').trim();
    return essentialText.isEmpty ? text : essentialText;
  }


  /// An image representing the app playing the track
  ImageProvider? get icon {
    if (isIOS) return const AssetImage('assets/apple_music.png', package: 'nowplaying');
    return _icons[this.source];
  }

  bool get hasIcon => isIOS || _icons.containsKey(this.source);
  bool get hasImage => image != null;

  /// true if the image is being resolved, else false
  bool get isResolvingImage =>
      _resolutionState == _NowPlayingImageResolutionState.resolving;

  /// true of the image is empty and a resolution hasn't been attempted, else false
  bool get imageNeedsResolving =>
      _resolutionState == _NowPlayingImageResolutionState.unresolved;

  String get _imageId => '$artist:$album';

  /// The image for the track, probably album art
  ///
  /// A bit of sophistry here: images are stored per album rather than per
  /// track, for efficiency, and shared.
  ImageProvider? get image => _images[_imageId];
  set image(ImageProvider? image) => _images[_imageId] = image;

  _NowPlayingImageResolutionState? get _resolutionState => _resolutionStates[_imageId];
  set _resolutionState(_NowPlayingImageResolutionState? state) => _resolutionStates[_imageId] = state;

  NowPlayingTrack({
    this.id,
    this.title,
    this.album,
    this.artist,
    this.duration = Duration.zero,
    this.state = NowPlayingState.stopped,
    this.source,
    this.position = Duration.zero,
    DateTime? createdAt,
  })  : this._createdAt = createdAt ?? DateTime.now();

  /// Creates a track from json
  ///
  /// Returns the static `notPlaying` instance if player is stopped
  ///
  /// Creates image and icon art if not already present/resolved
  factory NowPlayingTrack.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return notPlaying;

    final state = NowPlayingState.values[json['state']];
    if (state == NowPlayingState.stopped) return notPlaying;

    final String imageId = '${json['artist']}:${json['album']}';

    if (!_images.containsKey(imageId)) {
      final Uint8List? imageData = json['image'];
      if (imageData is Uint8List) {
        _images[imageId] = MemoryImage(imageData);
      } else {
        final String? imageUri = json['imageUri'];
        if (imageUri is String) _images[imageId] = NetworkImage(imageUri);
      }
    }

    _resolutionStates[imageId] ??= _NowPlayingImageResolutionState.unresolved;

    final Uint8List? iconData = json['sourceIcon'];
    if (iconData is Uint8List) _icons[json['source']] ??= MemoryImage(iconData);

    final String id = json['id'].toString();
    return NowPlayingTrack(
      id: id,
      title: json['title'],
      album: json['album'],
      artist: json['artist'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
      position: Duration(milliseconds: json['position'] ?? 0),
      state: state,
      source: json['source']
    );
  }

  /// Creates a copy of a track, largely so that the stream knows it's mutated
  NowPlayingTrack copy() => NowPlayingTrack(
    id: this.id,
    title: this.title,
    album: this.album,
    artist: this.artist,
    duration: this.duration,
    position: this.position,
    state: this.state,
    source: this.source,
    createdAt: this._createdAt
  );

  bool get isPlaying => this.state == NowPlayingState.playing;
  bool get isPaused => this.state == NowPlayingState.paused;
  bool get isStopped => this.state == NowPlayingState.stopped;

  String toString() => isStopped
      ? 'NowPlaying: -silence-'
      : 'NowPlaying:'
          '\n title: $title'
          '\n artist: $artist'
          '\n album: $album'
          '\n duration: ${duration.inMilliseconds}ms'
          '\n position: ${position.inMilliseconds}ms'
          '\n has image: $hasImage'
          '\n state: $state';

  Future<void> _resolveImage() async {
    if (this.imageNeedsResolving) {
      _resolutionState = _NowPlayingImageResolutionState.resolving;
      final ImageProvider? image = await NowPlaying.instance._resolver.resolve(this);
      if (image != null) this.image = image;
      _resolutionState = _NowPlayingImageResolutionState.resolved;
    }
  }
}

/// The current playing state of a track
enum NowPlayingState { playing, paused, stopped }

/// Resolve (probably) missing images for a track by returning an
/// appropriate `ImageProvider` for it
abstract class NowPlayingImageResolver {
  /// Returns an `ImageProvider` for a given `NowPlayingTrack`
  ///
  /// If an image cannot be resolved, or does not need to be for
  /// some reason (e.g. we're happy with the image that has already
  /// been found in the system metadata) `resolve` should return `null`
  Future<ImageProvider?> resolve(NowPlayingTrack track);
}

class DefaultNowPlayingImageResolver implements NowPlayingImageResolver {
  static final RegExp _rationaliseRegExp = RegExp(r' - single|the |and |& |\(.*\)');

  Future<ImageProvider?> resolve(NowPlayingTrack track) async {
    if (track.hasImage) return null;
    return _getAlbumCover(track);
  }

  Future<ImageProvider?> _getAlbumCover(NowPlayingTrack track) async {
    final String query = Uri.encodeQueryComponent(
      [
        if (track.artist != null) 'artist:(${_rationalise(track.artist!)})',
        if (track.album != null) 'release:(${_rationalise(track.album!)})',
      ].join(' AND ')
    );
    if (query.isEmpty) return null;

    print('NowPlaying - image resolution query: $query');

    final json = await _getJson('https://musicbrainz.org/ws/2/release?primarytype=album&limit=100&query=$query');
    if (json == null) return null;

    for (Map<String, dynamic> release in json['releases']) {
      if (release['score'] < 100) break;
      final albumArt = await _getAlbumArt(release['id']);
      if (albumArt != null) return albumArt;
    }

    return null;
  }

  Future<ImageProvider?> _getAlbumArt(String? mbid) async {
    print('NowPlaying - trying to find cover for $mbid');
    final json = await _getJson('https://coverartarchive.org/release/$mbid');
    if (json == null) return null;

    String? image;
    String? thumb;

    for (Map<String, dynamic> image in json['images']) {
      if (image['front'] == true) {
        final thumbs = Map<String, String>.from(image['thumbnails']);
        thumb ??= thumbs['large'];
        image = image['image'];
        if (thumb != null) break;
      }
    }

    if (image == null && thumb == null) return null;
    return NetworkImage(thumb ?? image!);
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    final info = await PackageInfo.fromPlatform();
    final client = HttpClient();
    final req = await client.openUrl('GET', Uri.parse(url));
    req.headers.add('Accept', 'application/json');
    req.headers.add('User-Agent', 'NowPlaying Flutter 1.0.2 in ${info.packageName} ( nicsford+NowPlayingFlutter@gmail.com )');
    final resp = await req.close();
    if (resp.statusCode != 200) return null;

    final completer = Completer<Map<String, dynamic>>();
    final body = StringBuffer();
    resp.transform(utf8.decoder).listen(body.write, onDone: () {
      final json = jsonDecode(body.toString());
      completer.complete(json);
    });
    return completer.future;
  }

  String _rationalise(String text) {
    final lowerText = text.toLowerCase().trim();
    if (lowerText == 'the the') return lowerText; // the Matt Johnson exemption
    return lowerText.replaceAll(_rationaliseRegExp, '').trim();
  }
}

class _LruMap<K, V> {
  final int size;
  final List<K> _keys = [];
  final Map<K, V> _map = {};

  _LruMap({this.size = 5}) : assert(size > 0);

  operator [](K key) => _map[key];

  void operator []=(K key, V value) {
    _map[key] = value;
    _keys.remove(key);
    _keys.insert(0, key);
    if (_keys.length > size) {
      final K removedKey = _keys.removeLast();
      _map.remove(removedKey);
    }
  }

  void remove(K key) {
    _keys.remove(key);
    _map.remove(key);
  }

  bool containsKey(K key) => _map.containsKey(key);
}
