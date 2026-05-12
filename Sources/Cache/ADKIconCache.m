#import "ADKIconCache.h"
#import <ImageIO/ImageIO.h>

@interface ADKIconCache ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *cache;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pending;
@property (nonatomic, strong) dispatch_queue_t pendingQueue;
@end

@implementation ADKIconCache

+ (instancetype)sharedCache
{
    static ADKIconCache *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _cache = [[NSCache alloc] init];
        _cache.name = @"ADKIconCache";
        _cache.countLimit = 256; // ~256 decoded thumbs ≈ a few MB at 60×60@3x
        _ioQueue = dispatch_queue_create("ADKIconCache.io",
                                         dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0));
        _pending = [NSMutableDictionary dictionary];
        _pendingQueue = dispatch_queue_create("ADKIconCache.pending", DISPATCH_QUEUE_SERIAL);

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(_didReceiveMemoryWarning)
                                                   name:UIApplicationDidReceiveMemoryWarningNotification
                                                 object:nil];
    }
    return self;
}

- (void)_didReceiveMemoryWarning { [self.cache removeAllObjects]; }

- (UIImage *)cachedIconForApp:(ADKApp *)app
{
    if (!app.bundleIdentifier) return nil;
    return [self.cache objectForKey:app.bundleIdentifier];
}

- (void)removeAllObjects { [self.cache removeAllObjects]; }

- (void)iconForApp:(ADKApp *)app completion:(void (^)(UIImage *))completion
{
    NSParameterAssert(completion);
    NSString *key = app.bundleIdentifier;
    if (!key) { completion(nil); return; }

    UIImage *hit = [self.cache objectForKey:key];
    if (hit) { completion(hit); return; }

    // Coalesce duplicate in-flight loads.
    __block BOOL alreadyInFlight = NO;
    dispatch_sync(self.pendingQueue, ^{
        NSMutableArray *queue = self.pending[key];
        if (queue) {
            [queue addObject:[completion copy]];
            alreadyInFlight = YES;
        } else {
            self.pending[key] = [NSMutableArray arrayWithObject:[completion copy]];
        }
    });
    if (alreadyInFlight) return;

    dispatch_async(self.ioQueue, ^{
        UIImage *image = [self _loadIconForApp:app];
        if (image) [self.cache setObject:image forKey:key];

        __block NSArray *waiters = nil;
        dispatch_sync(self.pendingQueue, ^{
            waiters = [self.pending[key] copy];
            [self.pending removeObjectForKey:key];
        });

        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^cb)(UIImage *) in waiters) cb(image);
        });
    });
}

#pragma mark - Loading

// Read the largest matching icon variant from the .app bundle, downsample to a
// cell-friendly size. Avoids private SPI; works for any installed app whose
// bundle is readable.
- (UIImage *)_loadIconForApp:(ADKApp *)app
{
    NSString *base = app.primaryIconFileName;
    NSURL *bundleURL = app.bundleURL;
    if (!bundleURL) return nil;

    NSURL *iconURL = nil;

    if (base.length) {
        // Try @3x → @2x → 1x with common size suffixes.
        NSArray<NSString *> *suffixes = @[ @"@3x", @"@2x", @"" ];
        for (NSString *suffix in suffixes) {
            NSString *candidate = [NSString stringWithFormat:@"%@%@.png", base, suffix];
            NSURL *u = [bundleURL URLByAppendingPathComponent:candidate];
            if ([NSFileManager.defaultManager fileExistsAtPath:u.path]) { iconURL = u; break; }
        }
    }

    // Fallback: directory scan for AppIcon*.png (largest wins).
    if (!iconURL) {
        NSError *err = nil;
        NSArray<NSURL *> *children = [NSFileManager.defaultManager
                                       contentsOfDirectoryAtURL:bundleURL
                                       includingPropertiesForKeys:@[NSURLFileSizeKey]
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:&err];
        unsigned long long bestSize = 0;
        for (NSURL *u in children) {
            NSString *name = u.lastPathComponent;
            if (![name hasPrefix:@"AppIcon"]) continue;
            if (![[name pathExtension] isEqualToString:@"png"]) continue;
            NSNumber *sz = nil;
            [u getResourceValue:&sz forKey:NSURLFileSizeKey error:NULL];
            unsigned long long s = sz.unsignedLongLongValue;
            if (s > bestSize) { bestSize = s; iconURL = u; }
        }
    }

    if (!iconURL) return nil;
    return [self _downsampleImageAtURL:iconURL toMaxPixelSize:180];
}

// ImageIO downsampling avoids decoding the full bitmap into memory.
- (UIImage *)_downsampleImageAtURL:(NSURL *)url toMaxPixelSize:(CGFloat)maxPx
{
    NSDictionary *src = @{ (id)kCGImageSourceShouldCache: @NO };
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, (__bridge CFDictionaryRef)src);
    if (!source) return nil;

    NSDictionary *opts = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceShouldCacheImmediately:          @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform:    @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize:           @(maxPx)
    };
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(source);
    if (!cg) return nil;

    UIImage *image = [UIImage imageWithCGImage:cg scale:UIScreen.mainScreen.scale orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return image;
}

@end
