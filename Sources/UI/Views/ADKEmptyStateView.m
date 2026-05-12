#import "ADKEmptyStateView.h"

@implementation ADKEmptyStateView

- (instancetype)initWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle
{
    if ((self = [super initWithFrame:CGRectZero])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;

        UIImageView *iv = [[UIImageView alloc] init];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:54 weight:UIImageSymbolWeightLight];
        iv.image = [UIImage systemImageNamed:symbol withConfiguration:cfg];
        iv.tintColor = UIColor.tertiaryLabelColor;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:iv];

        UILabel *t = [[UILabel alloc] init];
        t.translatesAutoresizingMaskIntoConstraints = NO;
        t.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        t.adjustsFontForContentSizeCategory = YES;
        t.textColor = UIColor.secondaryLabelColor;
        t.textAlignment = NSTextAlignmentCenter;
        t.numberOfLines = 0;
        t.text = title;
        [self addSubview:t];

        UILabel *s = [[UILabel alloc] init];
        s.translatesAutoresizingMaskIntoConstraints = NO;
        s.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        s.adjustsFontForContentSizeCategory = YES;
        s.textColor = UIColor.tertiaryLabelColor;
        s.textAlignment = NSTextAlignmentCenter;
        s.numberOfLines = 0;
        s.text = subtitle;
        [self addSubview:s];

        [NSLayoutConstraint activateConstraints:@[
            [iv.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [iv.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-40],
            [iv.widthAnchor constraintEqualToConstant:64],
            [iv.heightAnchor constraintEqualToConstant:64],

            [t.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:14],
            [t.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:32],
            [t.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],

            [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:6],
            [s.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:32],
            [s.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],
        ]];
    }
    return self;
}

@end
