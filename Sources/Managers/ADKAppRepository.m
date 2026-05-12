#import "ADKAppRepository.h"
#import "ADKLSWorkspace.h"
#import "ADKFileSystem.h"

NSNotificationName const ADKAppRepositoryDidLoadNotification = @"ADKAppRepositoryDidLoadNotification";

@interface ADKAppRepository ()
@property (nonatomic, copy) NSArray<ADKApp *> *apps;
@property (nonatomic, assign, getter=hasLoaded) BOOL hasLoaded;
@property (nonatomic, strong) dispatch_queue_t scanQueue;
@property (nonatomic, strong) dispatch_queue_t sizeQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingSize;
@property (nonatomic, strong) dispatch_queue_t pendingSizeLock;
@end

@implementation ADKAppRepository

+ (instancetype)sharedRepository
{
    static ADKAppRepository *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _scanQueue = dispatch_queue_create("ADKAppRepository.scan", DISPATCH_QUEUE_SERIAL);
        _sizeQueue = dispatch_queue_create("ADKAppRepository.size",
                                           dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0));
        _pendingSize = [NSMutableDictionary dictionary];
        _pendingSizeLock = dispatch_queue_create("ADKAppRepository.pendingSizeLock", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSArray<ADKApp *> *)cachedApps { return self.apps; }

- (void)loadAppsWithCompletion:(void (^)(NSArray<ADKApp *> *))completion
{
    if (self.hasLoaded) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(self.apps); });
        return;
    }
    [self refreshAppsWithCompletion:completion];
}

- (void)refreshAppsWithCompletion:(void (^)(NSArray<ADKApp *> *))completion
{
    dispatch_async(self.scanQueue, ^{
        NSArray<ADKApp *> *apps = [ADKLSWorkspace allInstalledAppsIncludingSystem:NO];
        self.apps = apps;
        self.hasLoaded = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:ADKAppRepositoryDidLoadNotification object:self];
            if (completion) completion(apps);
        });
    });
}

- (void)measureSizeForApp:(ADKApp *)app completion:(void (^)(unsigned long long))completion
{
    NSParameterAssert(completion);
    if (!app.dataContainerURL) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(0); });
        return;
    }
    if (app.cachedDataSizeValid) {
        unsigned long long v = app.cachedDataSize;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(v); });
        return;
    }

    NSString *key = app.bundleIdentifier;
    __block BOOL alreadyInFlight = NO;
    dispatch_sync(self.pendingSizeLock, ^{
        NSMutableArray *q = self.pendingSize[key];
        if (q) { [q addObject:[completion copy]]; alreadyInFlight = YES; }
        else   { self.pendingSize[key] = [NSMutableArray arrayWithObject:[completion copy]]; }
    });
    if (alreadyInFlight) return;

    dispatch_async(self.sizeQueue, ^{
        unsigned long long bytes = [ADKFileSystem recursiveSizeAtURL:app.dataContainerURL];
        app.cachedDataSize      = bytes;
        app.cachedDataSizeValid = YES;

        NSArray *waiters;
        dispatch_sync(self.pendingSizeLock, ^{
            waiters = [self.pendingSize[key] copy];
            [self.pendingSize removeObjectForKey:key];
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^cb)(unsigned long long) in waiters) cb(bytes);
        });
    });
}

- (void)invalidateSizeForApp:(ADKApp *)app
{
    app.cachedDataSize = 0;
    app.cachedDataSizeValid = NO;
}

@end
