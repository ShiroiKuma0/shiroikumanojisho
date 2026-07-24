#import "AsyncZipPlugin.h"
#include "zip.h"

@implementation AsyncZipPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // Dummy calls to Zip functions used by the plugin. The function calls will
    // never be executed because registrar is never NULL. This construct ensures
    // that the linker includes the required functions of the Zip library.
    if (!registrar) {
        zip_close(NULL);
        zip_entries_total(NULL);
        zip_entry_close(NULL);
        zip_entry_crc32(NULL);
        zip_entry_fread(NULL, NULL);
        zip_entry_fwrite(NULL, NULL);
        zip_entry_isdir(NULL);
        zip_entry_name(NULL);
        zip_entry_noallocread(NULL, NULL, 0);
        zip_entry_open(NULL, NULL);
        zip_entry_openbyindex(NULL, 0);
        zip_entry_read(NULL, NULL, NULL);
        zip_entry_size(NULL);
        zip_entry_write(NULL, NULL, 0);
        zip_open("", 0, 'r');
    }
}

@end
