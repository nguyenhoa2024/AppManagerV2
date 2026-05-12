#import "ADKAppCell.h"

NSString *const ADKAppCellReuseID = @"ADKAppCell";

@interface ADKAppCell ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) NSLayoutConstraint *checkWidth;
@property (nonatomic, strong) NSLayoutConstraint *sizeTrailing;
@end

@implementation ADKAppCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        [self _buildHierarchy];
    }
    return self;
}

- (void)_buildHierarchy
{
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryType  = UITableViewCellAccessoryNone;
    self.contentView.backgroundColor = UIColor.clearColor;

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.clipsToBounds = YES;
    _iconView.layer.cornerRadius = 10.0;
    _iconView.layer.cornerCurve = kCACornerCurveContinuous;
    _iconView.backgroundColor = [UIColor.systemGray5Color colorWithAlphaComponent:0.5];
    [self.contentView addSubview:_iconView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _nameLabel.adjustsFontForContentSizeCategory = YES;
    _nameLabel.textColor = UIColor.labelColor;
    [self.contentView addSubview:_nameLabel];

    _bundleLabel = [[UILabel alloc] init];
    _bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bundleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _bundleLabel.adjustsFontForContentSizeCategory = YES;
    _bundleLabel.textColor = UIColor.secondaryLabelColor;
    _bundleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.contentView addSubview:_bundleLabel];

    _sizeLabel = [[UILabel alloc] init];
    _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sizeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
    _sizeLabel.textColor = UIColor.secondaryLabelColor;
    _sizeLabel.textAlignment = NSTextAlignmentRight;
    [_sizeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_sizeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_sizeLabel];

    _checkView = [[UIImageView alloc] init];
    _checkView.translatesAutoresizingMaskIntoConstraints = NO;
    _checkView.contentMode = UIViewContentModeScaleAspectFit;
    _checkView.tintColor = UIColor.systemBlueColor;
    [self.contentView addSubview:_checkView];

    UILayoutGuide *g = self.contentView.layoutMarginsGuide;
    _checkWidth = [_checkView.widthAnchor constraintEqualToConstant:0];
    _sizeTrailing = [_sizeLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        [_iconView.widthAnchor  constraintEqualToConstant:44],
        [_iconView.heightAnchor constraintEqualToConstant:44],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [_nameLabel.topAnchor     constraintEqualToAnchor:_iconView.topAnchor constant:2],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],

        [_bundleLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_bundleLabel.topAnchor     constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
        [_bundleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],
        [_bundleLabel.bottomAnchor  constraintLessThanOrEqualToAnchor:_iconView.bottomAnchor],

        [_sizeLabel.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        _sizeTrailing,

        [_checkView.leadingAnchor constraintEqualToAnchor:_sizeLabel.trailingAnchor constant:8],
        [_checkView.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        _checkWidth,
        [_checkView.heightAnchor constraintEqualToConstant:22],
        [_checkView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
    ]];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.iconView.image = nil;
    self.nameLabel.text = nil;
    self.bundleLabel.text = nil;
    self.sizeLabel.text = nil;
    self.checkView.image = nil;
}

- (void)configureWithApp:(ADKApp *)app
                  icon:(UIImage *)icon
            sizeString:(NSString *)sizeString
              selected:(BOOL)selected
        inSelectMode:(BOOL)selectMode
{
    self.nameLabel.text   = app.displayName;
    self.bundleLabel.text = app.bundleIdentifier;
    self.sizeLabel.text   = sizeString ?: @"…";
    self.iconView.image   = icon;

    if (selectMode) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
        UIImage *img;
        if (selected) {
            img = [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:cfg];
            self.checkView.tintColor = UIColor.systemBlueColor;
        } else {
            img = [UIImage systemImageNamed:@"circle" withConfiguration:cfg];
            self.checkView.tintColor = UIColor.tertiaryLabelColor;
        }
        self.checkView.image = img;
        self.checkWidth.constant = 22;
        self.sizeTrailing.constant = -30;
    } else {
        self.checkView.image = nil;
        self.checkWidth.constant = 0;
        self.sizeTrailing.constant = 0;
    }
}

@end
