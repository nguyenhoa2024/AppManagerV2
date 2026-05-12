#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thin wrapper around posix_spawn(/usr/bin/tar). TrollStore apps run with
/// `platform-application` so spawning system binaries works without a helper.
@interface ADKTarRunner : NSObject

/// Creates `archiveURL` (.tar.gz) from the contents of `sourceDir`.
/// Returns YES on success. On failure, error contains tar's exit code and stderr.
+ (BOOL)createArchiveAtURL:(NSURL *)archiveURL
       fromContentsOfDirectory:(NSURL *)sourceDir
                         error:(NSError **)error;

/// Extracts `archiveURL` (.tar.gz) into `destDir`. `destDir` must already exist.
+ (BOOL)extractArchiveAtURL:(NSURL *)archiveURL
                  intoDirectory:(NSURL *)destDir
                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
