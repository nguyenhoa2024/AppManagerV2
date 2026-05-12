#import "ADKBatchCoordinator.h"
#import "ADKBackupManager.h"
#import "ADKWipeManager.h"
#import "ADKAppRepository.h"

@interface ADKBatchCoordinator ()
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation ADKBatchCoordinator

- (instancetype)init
{
    if ((self = [super init])) {
        _queue = dispatch_queue_create("ADKBatchCoordinator", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)runOperation:(ADKBatchOperation)op withApps:(NSArray<ADKApp *> *)apps
{
    if (self.running) return;
    self.running = YES;
    self.cancelled = NO;

    NSUInteger total = apps.count;
    __block NSUInteger successes = 0;
    __block NSUInteger failures = 0;

    dispatch_async(self.queue, ^{
        for (NSUInteger i = 0; i < total; i++) {
            if (self.cancelled) break;
            ADKApp *app = apps[i];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate batchCoordinator:self
                            didStartItemAtIndex:i
                                            app:app
                                     totalItems:total];
            });

            BOOL ok = NO;
            NSError *err = nil;
            if (op == ADKBatchOperationWipe) {
                ok = [[ADKWipeManager sharedManager] wipeApp:app error:&err];
            } else {
                ADKBackup *b = [[ADKBackupManager sharedManager] createBackupForApp:app error:&err];
                ok = (b != nil);
            }

            if (ok) {
                [[ADKAppRepository sharedRepository] invalidateSizeForApp:app];
                successes++;
            } else {
                failures++;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate batchCoordinator:self
                           didFinishItemAtIndex:i
                                            app:app
                                        success:ok
                                          error:err];
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.running = NO;
            [self.delegate batchCoordinatorDidFinishAll:self
                                              successes:successes
                                                failures:failures];
        });
    });
}

- (void)cancel { self.cancelled = YES; }

@end
