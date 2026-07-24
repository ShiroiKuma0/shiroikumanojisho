import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nowplaying/nowplaying.dart';
import 'package:provider/provider.dart';

void main() {
  NowPlaying.instance.start(resolveImages: true);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    NowPlaying.instance.isEnabled().then((bool isEnabled) async {
      if (!isEnabled) {
        final shown = await NowPlaying.instance.requestPermissions();
        print('MANAGED TO SHOW PERMS PAGE: $shown');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<NowPlayingTrack>.value(
      initialData: null,
      value: NowPlaying.instance.stream,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('NowPlaying example app'),
          ),
          body: Center(
            child: Consumer<NowPlayingTrack>(
              builder: (context, track, _) {
                if (track == null) return Container();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (track.isStopped) Text('nothing playing'),
                    if (!track.isStopped) ...[
                      if (track.title != null) Text(track.title),
                      if (track.artist != null) Text(track.artist),
                      if (track.album != null) Text(track.album),
                      if (track.duration != null) Text(track.duration.toString().split('.').first.padLeft(8, '0')),
                      TrackProgressIndicator(track),
                      Text(track.state.toString()),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.all(8.0),
                            width: 200,
                            height: 200,
                            alignment: Alignment.center,
                            color: Colors.grey,
                            child: _imageFrom(track)
                          ),
                          Positioned(bottom: 0, right: 0, child: _iconFrom(track))
                        ],
                      ),
                    ]
                  ],
                );
              }
            )
          ),
        ),
      ),
    );
  }

  Widget _imageFrom(NowPlayingTrack track) {
    if (track.hasImage) return Image(key: Key(track.id), image: track.image, width: 200, height: 200, fit: BoxFit.contain);

    if (track.isResolvingImage) return Container(
      width: 50.0,
      height: 50.0,
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
    );

    return Text('NO\nARTWORK\nFOUND', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, color: Colors.white));
  }

  Widget _iconFrom(NowPlayingTrack track) {
    if (track.hasIcon) return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [const BoxShadow(blurRadius: 5, color: Colors.black)],
        shape: BoxShape.circle
      ),
      child: Image(
        image: track.icon,
        width: 25,
        height: 25,
        fit: BoxFit.contain,
        color: _fgColorFor(track),
        colorBlendMode: BlendMode.srcIn,
      ),
    );
    return Container();
  }

  Color _fgColorFor(NowPlayingTrack track) {
    switch (track.source) {
      case "com.apple.music": return Colors.blue;
      case "com.hughesmedia.big_finish": return Colors.red;
      case "com.spotify.music": return Colors.green;
      default: return Colors.purpleAccent;
    }
  }
}

class TrackProgressIndicator extends StatefulWidget {
  final NowPlayingTrack track;

  TrackProgressIndicator(this.track);

  @override
  _TrackProgressIndicatorState createState() => _TrackProgressIndicatorState();
}

class _TrackProgressIndicatorState extends State<TrackProgressIndicator> {
  Timer _timer;

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.track.progress;
    final countdown = widget.track.duration - progress + const Duration(seconds: 1);
    return Column(
      children: [
        Text(progress.toString().split('.').first.padLeft(8, '0')),
        Text(countdown.toString().split('.').first.padLeft(8, '0')),
      ],
    );
  }
}
