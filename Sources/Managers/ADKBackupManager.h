#import <Foundation/Foundation.h>
#import "ADKApp.h"
#import "ADKBackup.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADKBackupManager : NSObject

+ (instancetype)sharedManager;

/// Lists existing backups for `bundleID` sorted newest-first.
- (NSArray<ADKBackup *> *)backupsForBundleID:(NSString *)bundleID;

/// Synchronous; call from a background queue. On success returns the new ADKBackup.
- (nullable ADKBackup *)createBackupForApp:(ADKApp *)app
                                     error:(NSError **)error;

/// Removes a backup file. Used by the cap enforcement and manual delete UI.
- (BOOL)removeBackup:(ADKBackup *)backup error:(NSError **)error;

/// User-tunable. 0 means unlimited. Default 5.
@property (nonatomic, assign) NSInteger maxBackupsPerApp;

@end

NS_ASSUME_NONNULL_END
