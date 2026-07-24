#import "MecabDartPlugin.h"
#if __has_include(<mecab_dart/mecab_dart-Swift.h>)
#import <mecab_dart/mecab_dart-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mecab_dart-Swift.h"
#endif

@implementation MecabDartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMecabDartPlugin registerWithRegistrar:registrar];
}
@end
