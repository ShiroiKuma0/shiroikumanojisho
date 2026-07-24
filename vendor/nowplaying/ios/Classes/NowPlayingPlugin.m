#import "NowPlayingPlugin.h"
#if __has_include(<NowPlaying/NowPlaying-Swift.h>)
#import <NowPlaying/NowPlaying-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "NowPlaying-Swift.h"
#endif

@implementation NowPlayingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftNowPlayingPlugin registerWithRegistrar:registrar];
}
@end
