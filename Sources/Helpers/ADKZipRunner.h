#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thin wrapper around /usr/bin/zip and /usr/bin/unzip.
@interface ADKZipRunner : NSObject

/// Creates `archiveURL` (.zip / .adbk) from the contents of `sourceDir`.
/// Uses `zip -r -X -q <archive> .` from inside `sourceDir`.
+ (BOOL)createArchiveAtURL:(NSURL *)archiveURL
   fromContentsOfDirectory:(NSURL *)sourceDir
                     error:(NSError **)error;

/// Extracts `archiveURL` into `destDir`. `destDir` must already exist.
+ (BOOL)extractArchiveAtURL:(NSURL *)archiveURL
              intoDirectory:(NSURL *)destDir
                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
