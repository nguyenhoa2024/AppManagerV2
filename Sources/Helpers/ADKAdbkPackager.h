#import <Foundation/Foundation.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

/// Creates and extracts `.adbk` archives matching the file format used by
/// TigiSoftware's Apps Manager:
///
///     <timestamp>.adbk = ZIP containing:
///       Binfo.plist                 (3 keys: id, displayName, date)
///       icon.png                    (64×64 thumbnail extracted from .app bundle)
///       <bundleID>.plist            (copy of <container>/Library/Preferences/<bid>.plist)
///       <bundleID>/                 (full data container)
///       ___groups___/               (app group containers — empty in v1)
///       __pasteboards__/            (pasteboard — empty in v1)
///
/// Not included (closed-source helper required):
///       __private_info              (encrypted keychain blob; needs kcaccess)
@interface ADKAdbkPackager : NSObject

/// 14-digit timestamp matching `(unsigned long long)(CFAbsoluteTimeGetCurrent() * 100000)`.
+ (NSString *)newTimestampString;

/// Creates `outURL` from `app`'s data container. Synchronous; call on a background queue.
+ (BOOL)createAdbkAtURL:(NSURL *)outURL
                forApp:(ADKApp *)app
                 error:(NSError **)error;

/// Reads `Binfo.plist` from `adbkURL`. Returns nil if missing/invalid.
/// Used by the restore picker to display backup metadata.
+ (nullable NSDictionary *)readBinfoFromAdbkAtURL:(NSURL *)adbkURL
                                            error:(NSError **)error;

/// Extracts `adbkURL` into `app`'s data container, replacing existing contents.
/// Synchronous; call on a background queue.
+ (BOOL)restoreAdbkAtURL:(NSURL *)adbkURL
                  toApp:(ADKApp *)app
                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
