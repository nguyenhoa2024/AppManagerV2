#import <UIKit/UIKit.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADKBackupListViewController : UITableViewController
- (instancetype)initWithApp:(ADKApp *)app NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStyle:(UITableViewStyle)style NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)c NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
