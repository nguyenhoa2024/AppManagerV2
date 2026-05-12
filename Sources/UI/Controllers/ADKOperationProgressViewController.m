#import "ADKOperationProgressViewController.h"

@interface ADKOperationProgressViewController ()
@property (nonatomic, copy) NSString *displayedTitle;
@property (nonatomic, assign) NSUInteger total;
@property (nonatomic, copy) void (^onCancel)(void);

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *currentAppLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIBarButtonItem *cancelButton;
@property (nonatomic, strong) UIBarButtonItem *doneButton;
@property (nonatomic, assign) BOOL finished;
@end

@implementation ADKOperationProgressViewController

- (instancetype)initWithTitle:(NSString *)title
                    totalItems:(NSUInteger)total
                      onCancel:(void (^)(void))onCancel
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _displayedTitle = [title copy];
        _total = total;
        _onCancel = [onCancel copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.displayedTitle;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                     target:self
                                                                     action:@selector(_tappedCancel)];
    self.doneButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                     target:self
                                                                     action:@selector(_tappedDone)];
    self.navigationItem.rightBarButtonItem = self.cancelButton;

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressView];

    self.currentAppLabel = [[UILabel alloc] init];
    self.currentAppLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentAppLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.currentAppLabel.textColor = UIColor.labelColor;
    self.currentAppLabel.numberOfLines = 2;
    [self.view addSubview:self.currentAppLabel];

    self.progressLabel = [[UILabel alloc] init];
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.progressLabel.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:self.progressLabel];

    self.logView = [[UITextView alloc] init];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.logView.layer.cornerRadius = 10;
    self.logView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [self.view addSubview:self.logView];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.progressView.topAnchor      constraintEqualToAnchor:g.topAnchor constant:16],
        [self.progressView.leadingAnchor  constraintEqualToAnchor:g.leadingAnchor  constant:20],
        [self.progressView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],

        [self.currentAppLabel.topAnchor      constraintEqualToAnchor:self.progressView.bottomAnchor constant:14],
        [self.currentAppLabel.leadingAnchor  constraintEqualToAnchor:g.leadingAnchor  constant:20],
        [self.currentAppLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],

        [self.progressLabel.topAnchor      constraintEqualToAnchor:self.currentAppLabel.bottomAnchor constant:4],
        [self.progressLabel.leadingAnchor  constraintEqualToAnchor:g.leadingAnchor  constant:20],
        [self.progressLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],

        [self.logView.topAnchor      constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:14],
        [self.logView.leadingAnchor  constraintEqualToAnchor:g.leadingAnchor  constant:16],
        [self.logView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [self.logView.bottomAnchor   constraintEqualToAnchor:g.bottomAnchor   constant:-16],
    ]];
}

- (void)_appendLog:(NSString *)line
{
    NSString *prev = self.logView.text ?: @"";
    self.logView.text = prev.length ? [prev stringByAppendingFormat:@"\n%@", line] : line;
    NSRange r = NSMakeRange(self.logView.text.length, 0);
    [self.logView scrollRangeToVisible:r];
}

- (void)startedItemAtIndex:(NSUInteger)i app:(ADKApp *)app totalItems:(NSUInteger)total
{
    self.total = total;
    self.currentAppLabel.text = app.displayName;
    self.progressLabel.text = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)(i + 1), (unsigned long)total];
    self.progressView.progress = (float)i / MAX((float)total, 1.0);
}

- (void)finishedItemAtIndex:(NSUInteger)i app:(ADKApp *)app success:(BOOL)success error:(NSError *)error
{
    NSString *marker = success ? @"✓" : @"✗";
    NSString *line = success
        ? [NSString stringWithFormat:@"%@ %@", marker, app.displayName]
        : [NSString stringWithFormat:@"%@ %@ — %@", marker, app.displayName, error.localizedDescription ?: @"failed"];
    [self _appendLog:line];

    self.progressView.progress = (float)(i + 1) / MAX((float)self.total, 1.0);
}

- (void)finishedAllWithSuccesses:(NSUInteger)succ failures:(NSUInteger)fail
{
    self.finished = YES;
    self.navigationItem.rightBarButtonItem = self.doneButton;
    self.currentAppLabel.text = (fail == 0) ? @"Completed" : @"Completed with errors";
    self.progressLabel.text = [NSString stringWithFormat:@"%lu succeeded, %lu failed", (unsigned long)succ, (unsigned long)fail];
    self.progressView.progress = 1.0;
}

- (void)_tappedCancel
{
    if (self.onCancel) self.onCancel();
    self.cancelButton.enabled = NO;
    self.title = [self.displayedTitle stringByAppendingString:@" — cancelling…"];
}

- (void)_tappedDone
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
