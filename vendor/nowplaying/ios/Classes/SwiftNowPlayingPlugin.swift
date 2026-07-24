import Flutter
import UIKit
import MediaPlayer

public class SwiftNowPlayingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gomes.com.es/nowplaying", binaryMessenger: registrar.messenger())
    let instance = SwiftNowPlayingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  var trackData: [String: Any?] = [:]
  let imageSize: CGSize = CGSize(width: 400, height: 400)

    enum ImageError: Error {
        case notPresent(artwork: MPMediaItemArtwork)
    }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "track":
          let musicPlayer = MPMusicPlayerController.systemMusicPlayer
          if let nowPlayingItem = musicPlayer.nowPlayingItem {
            let id = "\(nowPlayingItem.title ?? ""):\(nowPlayingItem.artist ?? ""):\(nowPlayingItem.albumTitle ?? "")"
            if trackData["id"] == nil || (trackData["id"] as! String) != id {
              trackData["id"] = id
              trackData["album"] = nowPlayingItem.albumTitle
              trackData["title"] = nowPlayingItem.title
              trackData["artist"] = nowPlayingItem.artist
              trackData["genre"] = nowPlayingItem.genre
              trackData["duration"] = Int(nowPlayingItem.playbackDuration * 1000)
              trackData["image"] = nowPlayingItem.artwork?.image(at: imageSize)?.pngData()
              trackData["source"] = "com.apple.music"
            }

            trackData["position"] = Int(musicPlayer.currentPlaybackTime * 1000)

            switch musicPlayer.playbackState {
              case MPMusicPlaybackState.playing, MPMusicPlaybackState.seekingForward, MPMusicPlaybackState.seekingBackward:
                trackData["state"] = 0
              case MPMusicPlaybackState.paused, MPMusicPlaybackState.interrupted:
                trackData["state"] = 1
              case MPMusicPlaybackState.stopped:
                trackData["state"] = 2
              default:
                trackData["state"] = 2
            }
          } else {
            trackData = [:]
          }

          result(trackData)
          break;
      default:
          result(FlutterMethodNotImplemented)
    }
  }
}
