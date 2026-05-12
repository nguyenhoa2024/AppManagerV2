#import <UIKit/UIKit.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ADKAppCellReuseID;

@interface ADKAppCell : UITableViewCell

- (void)configureWithApp:(ADKApp *)app
                  icon:(nullable UIImage *)icon
            sizeString:(nullable NSString *)sizeString
              selected:(BOOL)selected
        inSelectMode:(BOOL)selectMode;

@end

NS_ASSUME_NONNULL_END
