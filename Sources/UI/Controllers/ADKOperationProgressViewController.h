#import <UIKit/UIKit.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADKOperationProgressViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title
                    totalItems:(NSUInteger)total
                      onCancel:(void (^_Nullable)(void))onCancel NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)c NS_UNAVAILABLE;

- (void)startedItemAtIndex:(NSUInteger)i app:(ADKApp *)app totalItems:(NSUInteger)total;
- (void)finishedItemAtIndex:(NSUInteger)i app:(ADKApp *)app success:(BOOL)success error:(nullable NSError *)error;
- (void)finishedAllWithSuccesses:(NSUInteger)succ failures:(NSUInteger)fail;

@end

NS_ASSUME_NONNULL_END
