#import "ADKRestoreManager.h"
#import "ADKFileSystem.h"
#import "ADKAdbkPackager.h"

static NSString *const ADKRestoreErrorDomain = @"ADKRestoreErrorDomain";

@implementation ADKRestoreManager

+ (instancetype)sharedManager
{
    static ADKRestoreManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (BOOL)restoreBackup:(ADKBackup *)backup forApp:(ADKApp *)app error:(NSError **)error
{
    if (!app.dataContainerURL) {
        if (error) *error = [NSError errorWithDomain:ADKRestoreErrorDomain code:1
                                            userInfo:@{NSLocalizedDescriptionKey:@"App has no data container"}];
        return NO;
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:backup.fileURL.path]) {
        if (error) *error = [NSError errorWithDomain:ADKRestoreErrorDomain code:2
                                            userInfo:@{NSLocalizedDescriptionKey:@"Backup file missing"}];
        return NO;
    }

    // The packager does its own wipe before extracting per-bundle children, so
    // skip the redundant wipe here.
    return [ADKAdbkPackager restoreAdbkAtURL:backup.fileURL toApp:app error:error];
}

@end
