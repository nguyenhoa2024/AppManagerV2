#import "ADKAdbkPackager.h"
#import "ADKZipRunner.h"
#import "ADKFileSystem.h"
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>

static NSString *const ADKAdbkErrorDomain = @"ADKAdbkErrorDomain";

@implementation ADKAdbkPackager

#pragma mark - Helpers

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)msg
{
    return [NSError errorWithDomain:ADKAdbkErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: msg ?: @"adbk error" }];
}

+ (NSString *)newTimestampString
{
    // (long long)(CFAbsoluteTimeGetCurrent() * 100000) — matches the 14-digit
    // filename format used by the original Apps Manager.
    long long stamp = (long long)(CFAbsoluteTimeGetCurrent() * 100000.0);
    return [NSString stringWithFormat:@"%lld", stamp];
}

// Recursive copy that preserves directory structure. NSFileManager copyItemAtURL:
// fails if the destination exists; we walk and copy each file so we can stage
// onto a partially-created directory tree.
+ (BOOL)_copyTreeFromURL:(NSURL *)src
                   toURL:(NSURL *)dst
                   error:(NSError **)error
{
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:src.path isDirectory:&isDir]) return YES;
    if (!isDir) {
        [fm createDirectoryAtURL:dst.URLByDeletingLastPathComponent
              withIntermediateDirectories:YES attributes:nil error:NULL];
        if ([fm fileExistsAtPath:dst.path]) [fm removeItemAtURL:dst error:NULL];
        return [fm copyItemAtURL:src toURL:dst error:error];
    }
    [fm createDirectoryAtURL:dst withIntermediateDirectories:YES attributes:nil error:NULL];
    NSError *enumErr = nil;
    NSArray<NSURL *> *children = [fm contentsOfDirectoryAtURL:src
                                  includingPropertiesForKeys:nil
                                                     options:0
                                                       error:&enumErr];
    if (!children) { if (error) *error = enumErr; return NO; }
    for (NSURL *child in children) {
        NSURL *target = [dst URLByAppendingPathComponent:child.lastPathComponent];
        if (![self _copyTreeFromURL:child toURL:target error:error]) return NO;
    }
    return YES;
}

// Read /Library/Preferences/<bid>.plist out of the app's container, copy it to
// the staging root. The original Apps Manager places this duplicate at the zip
// root for fast metadata access without unpacking the whole container.
+ (void)_writeRootPreferencesPlistForApp:(ADKApp *)app
                               toStaging:(NSURL *)stagingDir
{
    if (!app.dataContainerURL) return;
    NSURL *prefs = [[[app.dataContainerURL
                      URLByAppendingPathComponent:@"Library"]
                      URLByAppendingPathComponent:@"Preferences"]
                      URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", app.bundleIdentifier]];
    if (![NSFileManager.defaultManager fileExistsAtPath:prefs.path]) return;
    NSURL *out = [stagingDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", app.bundleIdentifier]];
    [NSFileManager.defaultManager copyItemAtURL:prefs toURL:out error:NULL];
}

// Match the original's icon.png: 64×64 PNG extracted from the app bundle.
+ (void)_writeAppIconForApp:(ADKApp *)app toStaging:(NSURL *)stagingDir
{
    NSURL *bundleURL = app.bundleURL;
    if (!bundleURL) return;
    NSURL *sourceIcon = nil;

    if (app.primaryIconFileName.length) {
        NSArray<NSString *> *suffixes = @[ @"@3x", @"@2x", @"" ];
        for (NSString *suffix in suffixes) {
            NSString *candidate = [NSString stringWithFormat:@"%@%@.png", app.primaryIconFileName, suffix];
            NSURL *u = [bundleURL URLByAppendingPathComponent:candidate];
            if ([NSFileManager.defaultManager fileExistsAtPath:u.path]) { sourceIcon = u; break; }
        }
    }
    if (!sourceIcon) {
        NSArray<NSURL *> *bundleChildren = [NSFileManager.defaultManager
                                            contentsOfDirectoryAtURL:bundleURL
                                            includingPropertiesForKeys:nil
                                                               options:0 error:NULL];
        for (NSURL *u in bundleChildren) {
            NSString *name = u.lastPathComponent;
            if ([name hasPrefix:@"AppIcon60x60"] && [[name pathExtension] isEqualToString:@"png"]) {
                sourceIcon = u; break;
            }
        }
    }
    if (!sourceIcon) return;

    NSURL *out = [stagingDir URLByAppendingPathComponent:@"icon.png"];

    // Downsample to 64x64 max to match the original's 64×64 icon.png.
    NSDictionary *src = @{ (id)kCGImageSourceShouldCache: @NO };
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)sourceIcon, (__bridge CFDictionaryRef)src);
    if (!source) {
        [NSFileManager.defaultManager copyItemAtURL:sourceIcon toURL:out error:NULL];
        return;
    }
    NSDictionary *opts = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform:    @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize:           @64,
    };
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(source);
    if (!cg) {
        [NSFileManager.defaultManager copyItemAtURL:sourceIcon toURL:out error:NULL];
        return;
    }
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef dest = CGImageDestinationCreateWithData(data, (__bridge CFStringRef)@"public.png", 1, NULL);
    if (dest) {
        CGImageDestinationAddImage(dest, cg, NULL);
        CGImageDestinationFinalize(dest);
        CFRelease(dest);
        [(__bridge NSData *)data writeToURL:out atomically:YES];
    } else {
        [NSFileManager.defaultManager copyItemAtURL:sourceIcon toURL:out error:NULL];
    }
    CFRelease(data);
    CGImageRelease(cg);
}

#pragma mark - Public

+ (BOOL)createAdbkAtURL:(NSURL *)outURL
                forApp:(ADKApp *)app
                 error:(NSError **)error
{
    if (!app.dataContainerURL) {
        if (error) *error = [self errorWithCode:1 message:@"App has no data container"];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;

    NSString *stagingName = [NSString stringWithFormat:@"adbk_staging_%@", [NSUUID UUID].UUIDString];
    NSURL *staging = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:stagingName]
                                isDirectory:YES];
    [fm createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:NULL];

    @try {
        // 1) Binfo.plist
        NSDictionary *binfo = @{
            @"id":          app.bundleIdentifier ?: @"",
            @"displayName": app.displayName ?: app.bundleIdentifier ?: @"",
            @"date":        [NSDate date],
        };
        NSError *plistErr = nil;
        NSData *binfoData = [NSPropertyListSerialization dataWithPropertyList:binfo
                                                                       format:NSPropertyListXMLFormat_v1_0
                                                                      options:0
                                                                        error:&plistErr];
        if (!binfoData) {
            if (error) *error = plistErr ?: [self errorWithCode:2 message:@"Binfo.plist serialization failed"];
            return NO;
        }
        if (![binfoData writeToURL:[staging URLByAppendingPathComponent:@"Binfo.plist"] atomically:YES]) {
            if (error) *error = [self errorWithCode:3 message:@"Failed to write Binfo.plist"];
            return NO;
        }

        // 2) icon.png
        [self _writeAppIconForApp:app toStaging:staging];

        // 3) <bundleID>.plist (root-level prefs copy)
        [self _writeRootPreferencesPlistForApp:app toStaging:staging];

        // 4) <bundleID>/ (full data container)
        NSURL *containerCopy = [staging URLByAppendingPathComponent:app.bundleIdentifier isDirectory:YES];
        if (![self _copyTreeFromURL:app.dataContainerURL toURL:containerCopy error:error]) {
            return NO;
        }

        // 5) Empty scaffolds matching the original layout.
        [fm createDirectoryAtURL:[staging URLByAppendingPathComponent:@"___groups___" isDirectory:YES]
                    withIntermediateDirectories:YES attributes:nil error:NULL];
        [fm createDirectoryAtURL:[staging URLByAppendingPathComponent:@"__pasteboards__" isDirectory:YES]
                    withIntermediateDirectories:YES attributes:nil error:NULL];

        // 6) Zip it.
        if ([fm fileExistsAtPath:outURL.path]) [fm removeItemAtURL:outURL error:NULL];
        return [ADKZipRunner createArchiveAtURL:outURL fromContentsOfDirectory:staging error:error];
    }
    @finally {
        [fm removeItemAtURL:staging error:NULL];
    }
}

+ (NSDictionary *)readBinfoFromAdbkAtURL:(NSURL *)adbkURL error:(NSError **)error
{
    // Quick read: extract just Binfo.plist to a temp dir.
    NSString *stagingName = [NSString stringWithFormat:@"adbk_peek_%@", [NSUUID UUID].UUIDString];
    NSURL *staging = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:stagingName]
                                isDirectory:YES];
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:NULL];

    NSDictionary *result = nil;
    @try {
        if (![ADKZipRunner extractArchiveAtURL:adbkURL intoDirectory:staging error:error]) {
            return nil;
        }
        NSURL *binfo = [staging URLByAppendingPathComponent:@"Binfo.plist"];
        result = [NSDictionary dictionaryWithContentsOfURL:binfo];
        if (!result && error) {
            *error = [self errorWithCode:4 message:@"Binfo.plist not found or invalid in .adbk"];
        }
    }
    @finally {
        [fm removeItemAtURL:staging error:NULL];
    }
    return result;
}

+ (BOOL)restoreAdbkAtURL:(NSURL *)adbkURL toApp:(ADKApp *)app error:(NSError **)error
{
    if (!app.dataContainerURL) {
        if (error) *error = [self errorWithCode:1 message:@"App has no data container"];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;

    NSString *stagingName = [NSString stringWithFormat:@"adbk_restore_%@", [NSUUID UUID].UUIDString];
    NSURL *staging = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:stagingName]
                                isDirectory:YES];
    [fm createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:NULL];

    @try {
        // 1) Unzip to staging.
        if (![ADKZipRunner extractArchiveAtURL:adbkURL intoDirectory:staging error:error]) {
            return NO;
        }

        // 2) Locate the per-bundle dir. The original uses <bundleID>/ at the zip root.
        NSURL *source = [staging URLByAppendingPathComponent:app.bundleIdentifier isDirectory:YES];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:source.path isDirectory:&isDir] || !isDir) {
            // Fall back: maybe the .adbk was created by AppDataKit's tar.gz era —
            // contents are at the root. Use the staging dir itself.
            source = staging;
        }

        // 3) Wipe existing container, then copy children.
        NSError *wipeErr = nil;
        if (![ADKFileSystem wipeContentsOfDirectoryAtURL:app.dataContainerURL error:&wipeErr]) {
            if (error) *error = wipeErr;
            return NO;
        }

        NSError *enumErr = nil;
        NSArray<NSURL *> *children = [fm contentsOfDirectoryAtURL:source
                                      includingPropertiesForKeys:nil
                                                         options:0
                                                           error:&enumErr];
        if (!children) { if (error) *error = enumErr; return NO; }

        for (NSURL *child in children) {
            // Skip metadata files that should never overwrite the destination's existing one.
            NSString *name = child.lastPathComponent;
            if ([name isEqualToString:@".com.apple.mobile_container_manager.metadata.plist"]) continue;

            NSURL *target = [app.dataContainerURL URLByAppendingPathComponent:name];
            if ([fm fileExistsAtPath:target.path]) [fm removeItemAtURL:target error:NULL];
            NSError *cpErr = nil;
            if (![fm copyItemAtURL:child toURL:target error:&cpErr]) {
                if (error) *error = cpErr;
                return NO;
            }
        }
        return YES;
    }
    @finally {
        [fm removeItemAtURL:staging error:NULL];
    }
}

@end
