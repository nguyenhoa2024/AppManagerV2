#import <Foundation/Foundation.h>
#import "ADKApp.h"
#import "ADKBackup.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ADKBatchOperation) {
    ADKBatchOperationWipe   = 0,
    ADKBatchOperationBackup = 1,
};

@class ADKBatchCoordinator;

@protocol ADKBatchCoordinatorDelegate <NSObject>
- (void)batchCoordinator:(ADKBatchCoordinator *)c
        didStartItemAtIndex:(NSUInteger)index
                       app:(ADKApp *)app
                totalItems:(NSUInteger)total;

- (void)batchCoordinator:(ADKBatchCoordinator *)c
       didFinishItemAtIndex:(NSUInteger)index
                       app:(ADKApp *)app
                    success:(BOOL)success
                      error:(nullable NSError *)error;

- (void)batchCoordinatorDidFinishAll:(ADKBatchCoordinator *)c
                            successes:(NSUInteger)successes
                              failures:(NSUInteger)failures;
@end

/// Sequentially runs an operation against a list of apps on a background queue.
/// Single-instance per ADKBatchCoordinator object — create one per batch.
@interface ADKBatchCoordinator : NSObject

@property (nonatomic, weak, nullable) id<ADKBatchCoordinatorDelegate> delegate;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) BOOL cancelled;

- (void)runOperation:(ADKBatchOperation)op
            withApps:(NSArray<ADKApp *> *)apps;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
