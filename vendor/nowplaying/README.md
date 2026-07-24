# NowPlaying

A Flutter plugin for iOS and Android which surfaces metadata around the currently playing
audio track on the device.

On Android `nowplaying` makes use of the `NotifiationListenerService`, and shows any
track revealing its play state via a notification.

On iOS `nowplaying` is restricted to access to music or media played via the Apple Music/iTunes app.

## Installation

Add `nowplaying` as a dependency in your `pubspec.yaml` file:

```
dependencies:
    nowplaying: ^2.0.6
```

### iOS

Add the following usage to your `ios/Runner/Info.plist`:

```
<key>NSAppleMusicUsageDescription</key>
<string>We need this to show you what's currently playing</string>
```

### Android

To enable the notification listener service, add the following block to your `android/app/src/main/AndroidManifest.xml`, just before the closing `</application>` tag:

```
<service android:name="com.gomes.nowplaying.NowPlayingListenerService"
    android:label="NowPlayingListenerService"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

## Usage

### Initialisation

Initialise the `nowplaying` service by starting it's instance:

```dart
NowPlaying.instance.start();
```

This can be done anywhere, including prior to the `runApp` command.

### Permissions

iOS automatically has the required permissions to access now-playing data, via the usage key added during the installation phase.

Android users must give explicit permission for the service to access the notification stream from which now-playing data is extracted.

Test for whether permissions have been given or not via the instance's `isEnabled` method:

```dart
final bool isEnabled = await NowPlaying.instance.isEnabled();
// isEnabled() always returns true on iOS
if (!isEnabled) {
    ...
}
```

The Android settings page for this permission is a little hard to find, so NowPlaying includes a convenience method to open it:

```dart
NowPlaying.instance.requestPermissions();
```

To avoid annoying a user by e.g. showing the permissions page on every app restart, navigation to this page should be limited: as such, the unparameterised `requestPermissions` function will only open the settings page once for any given install of the app. It returns a boolean: `true` the first time, when the page has been successfully shown; also `true` if permission has already been granted (in which case the settings page is not shown); or `false` if this is a second or later call to the method, with navigation to the settings page prohibited. (Note that `requestPermissions()` always returns `true` on iOS).

```dart
final bool hasShownPermissions = await NowPlaying.instance.requestPermissions();
```

If you really need to show the permissions page a second time, probably after gently explaining to the user why, you can `force` it open:

```dart
if (!hasShownPermissions) {
    final bool pleasePleasePlease = await Navigator.of(context).pushNamed('ExplainAgainReallyNicelyPage');
    if (pleasePleasePlease) NowPlaying.instance.requestPermissions(force: true);
}
```

(although this still won't show the settings page if permission is already enabled.)

### Accessing current now-playing metadata

Now-playing metadata is deliverd into the parent app via a `stream` of `NowPlayingTrack` objects, exposed as `NowPlaying.instance.stream`. This can be consumed however you'd usually consume a stream, e.g.:

```dart
StreamProvider.value(
    value: NowPlaying.instance.stream,
    child: MaterialApp(
        home: Scaffold(
            body: Consumer<NowPlayingTrack>(
                builder: (context, track, _) {
                    return Container(
                        ...
                    );
                }
            )
        )
    )
)
```

The `NowPlayingTrack` objects contain the following fields:

```dart
String title;
String artist;
String album;
String genre;
Duration duration;
Duration progress; // check note below
NowPlayingState state;
ImageProvider image;
ImageProvider icon;
String source;
```

where `NowPlayingState` is defined as:

```dart
enum NowPlayingState {
  playing, paused, stopped
}
```

...which is hopefully self-explanatory.

### `icon` and `source` fields

The `source` of a track is the package name of the app playing the current track: `com.spotify.music`, for example. On iOS this is always `com.apple.music`.

The `icon` image provider, if not null, supplies a small, transparent PNG containing a monochrome logo for the originating app. While monochrome, this PNG is not necessarily black: so for consistency, it's probably worth adding `color: Colors.somethingNice` and `colorBlendMode: BlendMode.srcIn` or similar to any `Image` widget.

### The `progress` field

As is probably obvious, `progress` is a duration describing how far through the track the player has progressed, in milliseconds: how much of a track has been played, in other words.

Note that no new track is emitted on the stream as a track progresses: stream updates only happen when the track changes state (playing to paused; vice versa; new track starts; and so on). However, the `progress` field of a track will give you an instantaneous 'correct' value every time it's polled, so to see progress updating in real time create a stateful widge to expose it:

```dart
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
    return Text(widget.track.progress.toString().split('.').first.padLeft(8, '0'));
  }
}
```

### Album art and associated images

Usually - and almost always, on Android - a track will contain an appropriate `ImageProvider` in its `image` field, containing album art or similar.

On iOS, however, there is a bug or badly documented policy that means album art is only made available if the track being played is in your local library: any tracks streamed from e.g. Apple music playlists are image-free.

`NowPlaying` can attempt to resolve missing images for you. However, this is a relatively heavy process in terms of memory and processing, so is turned off by default. To enable missing image resolution, set the `resolveImages` parameter to `true` when starting the instance:

```dart
NowPlaying.instance.start(resolveImages: true);
```

The default image resolution process:

- will only attempt to find an image if none already exists
- makes http calls against the [MusicBrainz api](https://musicbrainz.org/doc/MusicBrainz_API) and subsequently the [Cover Art Archive api](https://coverartarchive.org/)

### Overriding the image resolver

You may decide that you want to resolve missing images in a different way, or even override images that have already been found from the metadata. In this case, supply a new image resolver when starting the instance:

```dart
NowPlaying.instance.start(resolver: MyImageResolver());

...

class MyImageResolver implements NowPlayingImageResolver {
    @override
    Future<ImageProvider> resolve(NowPlayingTrack track) async {
        ...
    }
}
```

### SemVer use

- patch:
  - bugfix, tweak or typo
- minor:
  - non-breaking change
- major:
  - breaking change

### Credits

Thanks to Fábio A. M. Pereira for his [Notification Listener Service Example](https://github.com/Chagall/notification-listener-service-example), which provided inspiration (and in some cases, let's be honest, actual code) for the Android implementation.
