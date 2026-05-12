#import "ADKRestoreManager.h"
#import "ADKFileSystem.h"
#import "ADKTarRunner.h"

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

    NSError *wipeErr = nil;
    if (![ADKFileSystem wipeContentsOfDirectoryAtURL:app.dataContainerURL error:&wipeErr]) {
        if (error) *error = wipeErr;
        return NO;
    }
    NSError *tarErr = nil;
    if (![ADKTarRunner extractArchiveAtURL:backup.fileURL
                             intoDirectory:app.dataContainerURL
                                     error:&tarErr]) {
        if (error) *error = tarErr;
        return NO;
    }
    return YES;
}

@end
