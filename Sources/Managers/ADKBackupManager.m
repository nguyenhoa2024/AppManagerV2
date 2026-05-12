#import "ADKBackupManager.h"
#import "ADKFileSystem.h"
#import "ADKTarRunner.h"

static NSString *const ADKBackupErrorDomain = @"ADKBackupErrorDomain";
static NSString *const ADKBackupMaxBackupsKey = @"ADKBackupMaxBackupsPerApp";

@implementation ADKBackupManager

+ (instancetype)sharedManager
{
    static ADKBackupManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:ADKBackupMaxBackupsKey];
        _maxBackupsPerApp = stored ? stored.integerValue : 5;
    }
    return self;
}

- (void)setMaxBackupsPerApp:(NSInteger)v
{
    _maxBackupsPerApp = v;
    [NSUserDefaults.standardUserDefaults setInteger:v forKey:ADKBackupMaxBackupsKey];
}

- (NSArray<ADKBackup *> *)backupsForBundleID:(NSString *)bundleID
{
    NSURL *dir = [ADKFileSystem backupsDirectoryForBundleID:bundleID];
    NSArray<NSURL *> *children = [NSFileManager.defaultManager
                                   contentsOfDirectoryAtURL:dir
                                   includingPropertiesForKeys:@[NSURLFileSizeKey, NSURLContentModificationDateKey]
                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        error:NULL];
    NSMutableArray<ADKBackup *> *out = [NSMutableArray array];
    for (NSURL *u in children) {
        NSString *ext = u.pathExtension.lowercaseString;
        if (!([ext isEqualToString:@"gz"] || [ext isEqualToString:@"tgz"])) continue;
        NSNumber *size = nil; NSDate *date = nil;
        [u getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
        [u getResourceValue:&date forKey:NSURLContentModificationDateKey error:NULL];
        ADKBackup *b = [[ADKBackup alloc] initWithBundleIdentifier:bundleID
                                                            fileURL:u
                                                          createdAt:date ?: [NSDate distantPast]
                                                           fileSize:size.unsignedLongLongValue];
        [out addObject:b];
    }
    [out sortUsingComparator:^NSComparisonResult(ADKBackup *a, ADKBackup *b) {
        return [b.createdAt compare:a.createdAt];
    }];
    return out;
}

- (ADKBackup *)createBackupForApp:(ADKApp *)app error:(NSError **)error
{
    if (!app.dataContainerURL) {
        if (error) *error = [NSError errorWithDomain:ADKBackupErrorDomain code:1
                                            userInfo:@{NSLocalizedDescriptionKey:@"App has no data container"}];
        return nil;
    }

    NSURL *backupDir = [ADKFileSystem backupsDirectoryForBundleID:app.bundleIdentifier];

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *stamp = [fmt stringFromDate:[NSDate date]];

    NSString *fileName = [NSString stringWithFormat:@"%@_%@.tar.gz", app.bundleIdentifier, stamp];
    NSURL *out = [backupDir URLByAppendingPathComponent:fileName];

    NSError *tarErr = nil;
    if (![ADKTarRunner createArchiveAtURL:out
                  fromContentsOfDirectory:app.dataContainerURL
                                    error:&tarErr]) {
        if (error) *error = tarErr;
        return nil;
    }

    NSNumber *size = nil;
    [out getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];

    ADKBackup *b = [[ADKBackup alloc] initWithBundleIdentifier:app.bundleIdentifier
                                                       fileURL:out
                                                     createdAt:[NSDate date]
                                                      fileSize:size.unsignedLongLongValue];

    [self _enforceCapForBundleID:app.bundleIdentifier];
    return b;
}

- (BOOL)removeBackup:(ADKBackup *)backup error:(NSError **)error
{
    return [NSFileManager.defaultManager removeItemAtURL:backup.fileURL error:error];
}

- (void)_enforceCapForBundleID:(NSString *)bundleID
{
    if (self.maxBackupsPerApp <= 0) return;
    NSArray<ADKBackup *> *list = [self backupsForBundleID:bundleID];
    if ((NSInteger)list.count <= self.maxBackupsPerApp) return;
    for (NSInteger i = self.maxBackupsPerApp; i < (NSInteger)list.count; i++) {
        [self removeBackup:list[(NSUInteger)i] error:NULL];
    }
}

@end
