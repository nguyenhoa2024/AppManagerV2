#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADKFileSystem : NSObject

/// App-private documents directory; created on demand.
+ (NSURL *)documentsDirectory;

/// `~/Documents/Backups` — created on demand.
+ (NSURL *)backupsDirectory;

/// `~/Documents/Backups/<bundleID>/` — created on demand.
+ (NSURL *)backupsDirectoryForBundleID:(NSString *)bundleID;

/// Recursively measure a directory. Safe to call on background queue.
/// Returns 0 if the directory cannot be read.
+ (unsigned long long)recursiveSizeAtURL:(NSURL *)url;

/// Recursively delete every direct child of `url`. The container itself is preserved.
/// Returns YES if every child was removed (or there were none).
+ (BOOL)wipeContentsOfDirectoryAtURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
