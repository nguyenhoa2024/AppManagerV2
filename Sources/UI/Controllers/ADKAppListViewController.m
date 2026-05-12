#import "ADKAppListViewController.h"
#import "ADKAppCell.h"
#import "ADKEmptyStateView.h"
#import "ADKAppRepository.h"
#import "ADKIconCache.h"
#import "ADKSelectionState.h"
#import "ADKBatchCoordinator.h"
#import "ADKByteFormatter.h"
#import "ADKApp.h"
#import "ADKBackupManager.h"
#import "ADKBackupListViewController.h"
#import "ADKOperationProgressViewController.h"
#import "ADKSettingsViewController.h"

@interface ADKAppListViewController ()
    <UITableViewDataSource, UITableViewDelegate,
     UISearchResultsUpdating, UISearchControllerDelegate,
     ADKBatchCoordinatorDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) ADKEmptyStateView *emptyView;

@property (nonatomic, strong) UIToolbar *bottomBar;
@property (nonatomic, strong) UIBarButtonItem *wipeButton;
@property (nonatomic, strong) UIBarButtonItem *backupButton;

@property (nonatomic, copy) NSArray<ADKApp *> *allApps;
@property (nonatomic, copy) NSArray<ADKApp *> *visibleApps;
@property (nonatomic, copy) NSString *searchText;

@property (nonatomic, assign) BOOL inSelectMode;
@property (nonatomic, strong) ADKBatchCoordinator *batch;
@property (nonatomic, weak) ADKOperationProgressViewController *currentProgressVC;
@end

@implementation ADKAppListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.title = @"Apps";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;

    [self _installNavBarItems];
    [self _installTableView];
    [self _installSearchController];
    [self _installBottomBar];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(_selectionDidChange)
                                               name:ADKSelectionStateDidChangeNotification
                                             object:nil];

    [self _loadInitialApps];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.emptyView.frame = self.tableView.bounds;
}

#pragma mark - Hierarchy

- (void)_installNavBarItems
{
    UIBarButtonItem *settings = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"gearshape"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(_openSettings)];
    self.navigationItem.leftBarButtonItem = settings;

    self.navigationItem.rightBarButtonItem = [self _selectModeBarItem];
}

- (UIBarButtonItem *)_selectModeBarItem
{
    NSString *title = self.inSelectMode ? @"Done" : @"Select";
    return [[UIBarButtonItem alloc] initWithTitle:title
                                            style:UIBarButtonItemStylePlain
                                           target:self
                                           action:@selector(_toggleSelectMode)];
}

- (void)_installTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:[ADKAppCell class] forCellReuseIdentifier:ADKAppCellReuseID];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(_pulledToRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    self.emptyView = [[ADKEmptyStateView alloc]
        initWithSymbol:@"square.stack.3d.up.slash"
                 title:@"No apps yet"
              subtitle:@"Pull to refresh, or check that AppDataKit has the entitlements to read installed apps."];
}

- (void)_installSearchController
{
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.delegate = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search apps";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)_installBottomBar
{
    self.bottomBar = [[UIToolbar alloc] init];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBar.hidden = YES;
    [self.view addSubview:self.bottomBar];

    UIBarButtonItem *wipe = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"trash"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(_tappedWipe)];
    wipe.tintColor = UIColor.systemRedColor;

    UIBarButtonItem *backup = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down.on.square"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(_tappedBackup)];

    UIBarButtonItem *flex = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    UIBarButtonItem *menu = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                 menu:[self _buildSelectionMenu]];

    self.wipeButton = wipe;
    self.backupButton = backup;
    self.bottomBar.items = @[wipe, flex, backup, flex, menu];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBar.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBar.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
    [self _refreshActionButtonState];
}

- (UIMenu *)_buildSelectionMenu
{
    __weak typeof(self) weakSelf = self;
    UIAction *selectAll = [UIAction actionWithTitle:@"Select All Visible"
                                              image:[UIImage systemImageNamed:@"checkmark.circle"]
                                         identifier:nil
                                            handler:^(UIAction *_) { [weakSelf _selectAllVisible]; }];
    UIAction *deselectAll = [UIAction actionWithTitle:@"Deselect All"
                                                image:[UIImage systemImageNamed:@"circle"]
                                           identifier:nil
                                              handler:^(UIAction *_) { [weakSelf _deselectAll]; }];
    return [UIMenu menuWithTitle:@"" children:@[selectAll, deselectAll]];
}

#pragma mark - Loading

- (void)_loadInitialApps
{
    __weak typeof(self) weakSelf = self;
    [[ADKAppRepository sharedRepository] loadAppsWithCompletion:^(NSArray<ADKApp *> *apps) {
        [weakSelf _applyApps:apps];
    }];
}

- (void)_pulledToRefresh
{
    [[ADKIconCache sharedCache] removeAllObjects];
    __weak typeof(self) weakSelf = self;
    [[ADKAppRepository sharedRepository] refreshAppsWithCompletion:^(NSArray<ADKApp *> *apps) {
        [weakSelf.refreshControl endRefreshing];
        [weakSelf _applyApps:apps];
    }];
}

- (void)_applyApps:(NSArray<ADKApp *> *)apps
{
    self.allApps = apps;
    [self _recomputeVisibleApps];
}

- (void)_recomputeVisibleApps
{
    NSString *q = self.searchText.lowercaseString;
    if (q.length == 0) {
        self.visibleApps = self.allApps;
    } else {
        NSMutableArray<ADKApp *> *out = [NSMutableArray array];
        for (ADKApp *a in self.allApps) {
            if ([a.displayName.lowercaseString containsString:q] ||
                [a.bundleIdentifier.lowercaseString containsString:q]) {
                [out addObject:a];
            }
        }
        self.visibleApps = out;
    }
    [self.tableView reloadData];
    self.tableView.backgroundView = (self.visibleApps.count == 0) ? self.emptyView : nil;
    [self _refreshActionButtonState];
}

#pragma mark - Select mode

- (void)_toggleSelectMode
{
    self.inSelectMode = !self.inSelectMode;
    self.bottomBar.hidden = !self.inSelectMode;
    self.tableView.contentInset = self.inSelectMode
        ? UIEdgeInsetsMake(0, 0, self.bottomBar.intrinsicContentSize.height + 12, 0)
        : UIEdgeInsetsZero;
    self.navigationItem.rightBarButtonItem = [self _selectModeBarItem];
    [self.tableView reloadData];
    [self _refreshActionButtonState];
}

- (void)_selectAllVisible
{
    NSMutableArray<NSString *> *ids = [NSMutableArray arrayWithCapacity:self.visibleApps.count];
    for (ADKApp *a in self.visibleApps) {
        if (a.dataContainerURL) [ids addObject:a.bundleIdentifier];
    }
    [[ADKSelectionState sharedState] selectAll:ids];
    [self.tableView reloadData];
}

- (void)_deselectAll
{
    [[ADKSelectionState sharedState] deselectAll];
    [self.tableView reloadData];
}

- (void)_selectionDidChange
{
    [self _refreshActionButtonState];
}

- (NSArray<ADKApp *> *)_selectedApps
{
    NSSet<NSString *> *sel = [ADKSelectionState sharedState].selectedBundleIDs;
    if (!sel.count) return @[];
    NSMutableArray<ADKApp *> *out = [NSMutableArray array];
    for (ADKApp *a in self.allApps) {
        if ([sel containsObject:a.bundleIdentifier]) [out addObject:a];
    }
    return out;
}

- (void)_refreshActionButtonState
{
    NSUInteger n = [ADKSelectionState sharedState].selectedBundleIDs.count;
    BOOL enabled = (n > 0) && !self.batch.running;
    self.wipeButton.enabled   = enabled;
    self.backupButton.enabled = enabled;
}

#pragma mark - Bottom-bar actions

- (void)_tappedWipe
{
    NSArray<ADKApp *> *apps = [self _selectedApps];
    if (!apps.count) return;
    NSString *msg = [NSString stringWithFormat:
        @"Wipe app data for %lu app%@? This cannot be undone unless you have a backup.",
        (unsigned long)apps.count, apps.count == 1 ? @"" : @"s"];
    [self _confirmAction:@"Wipe App Data"
                 message:msg
            destructive:YES
              confirmTitle:@"Wipe"
                 confirmed:^{ [self _runBatch:ADKBatchOperationWipe apps:apps]; }];
}

- (void)_tappedBackup
{
    NSArray<ADKApp *> *apps = [self _selectedApps];
    if (!apps.count) return;
    NSString *msg = [NSString stringWithFormat:@"Create a backup for %lu app%@?",
                     (unsigned long)apps.count, apps.count == 1 ? @"" : @"s"];
    [self _confirmAction:@"Backup App Data"
                 message:msg
            destructive:NO
              confirmTitle:@"Backup"
                 confirmed:^{ [self _runBatch:ADKBatchOperationBackup apps:apps]; }];
}

- (void)_confirmAction:(NSString *)title
               message:(NSString *)msg
           destructive:(BOOL)destructive
            confirmTitle:(NSString *)confirmTitle
             confirmed:(void (^)(void))confirmed
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:confirmTitle
                                              style:destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_) { if (confirmed) confirmed(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)_runBatch:(ADKBatchOperation)op apps:(NSArray<ADKApp *> *)apps
{
    self.batch = [[ADKBatchCoordinator alloc] init];
    self.batch.delegate = self;

    ADKOperationProgressViewController *progress =
        [[ADKOperationProgressViewController alloc] initWithTitle:op == ADKBatchOperationWipe ? @"Wiping…" : @"Backing up…"
                                                       totalItems:apps.count
                                                        onCancel:^{ [self.batch cancel]; }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:progress];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.modalInPresentation = YES;
    self.currentProgressVC = progress;
    [self presentViewController:nav animated:YES completion:^{
        [self.batch runOperation:op withApps:apps];
    }];
    [self _refreshActionButtonState];
}

#pragma mark - ADKBatchCoordinatorDelegate

- (void)batchCoordinator:(ADKBatchCoordinator *)c
     didStartItemAtIndex:(NSUInteger)index
                     app:(ADKApp *)app
              totalItems:(NSUInteger)total
{
    [self.currentProgressVC startedItemAtIndex:index app:app totalItems:total];
}

- (void)batchCoordinator:(ADKBatchCoordinator *)c
    didFinishItemAtIndex:(NSUInteger)index
                     app:(ADKApp *)app
                 success:(BOOL)success
                   error:(NSError *)error
{
    [self.currentProgressVC finishedItemAtIndex:index app:app success:success error:error];
    NSUInteger row = [self.visibleApps indexOfObject:app];
    if (row != NSNotFound) {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)batchCoordinatorDidFinishAll:(ADKBatchCoordinator *)c
                            successes:(NSUInteger)successes
                              failures:(NSUInteger)failures
{
    [self.currentProgressVC finishedAllWithSuccesses:successes failures:failures];
    [self _refreshActionButtonState];
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s
{
    return (NSInteger)self.visibleApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    ADKAppCell *cell = [t dequeueReusableCellWithIdentifier:ADKAppCellReuseID forIndexPath:ip];
    ADKApp *app = self.visibleApps[(NSUInteger)ip.row];

    UIImage *cachedIcon = [[ADKIconCache sharedCache] cachedIconForApp:app];
    NSString *sizeStr = app.cachedDataSizeValid
        ? [ADKByteFormatter stringFromBytes:app.cachedDataSize]
        : @"…";

    BOOL selected = [[ADKSelectionState sharedState] isSelected:app.bundleIdentifier];
    [cell configureWithApp:app
                      icon:cachedIcon
                sizeString:sizeStr
                  selected:selected
              inSelectMode:self.inSelectMode];

    if (!cachedIcon) {
        [[ADKIconCache sharedCache] iconForApp:app completion:^(UIImage *icon) {
            ADKAppCell *visible = (ADKAppCell *)[t cellForRowAtIndexPath:ip];
            if (visible && [visible isKindOfClass:[ADKAppCell class]]) {
                BOOL stillSelected = [[ADKSelectionState sharedState] isSelected:app.bundleIdentifier];
                NSString *fresh = app.cachedDataSizeValid
                    ? [ADKByteFormatter stringFromBytes:app.cachedDataSize]
                    : @"…";
                [visible configureWithApp:app icon:icon sizeString:fresh selected:stillSelected inSelectMode:self.inSelectMode];
            }
        }];
    }

    if (!app.cachedDataSizeValid) {
        [[ADKAppRepository sharedRepository] measureSizeForApp:app completion:^(unsigned long long bytes) {
            ADKAppCell *visible = (ADKAppCell *)[t cellForRowAtIndexPath:ip];
            if (visible && [visible isKindOfClass:[ADKAppCell class]]) {
                UIImage *icon2 = [[ADKIconCache sharedCache] cachedIconForApp:app];
                BOOL stillSelected = [[ADKSelectionState sharedState] isSelected:app.bundleIdentifier];
                [visible configureWithApp:app
                                     icon:icon2
                               sizeString:[ADKByteFormatter stringFromBytes:bytes]
                                 selected:stillSelected
                             inSelectMode:self.inSelectMode];
            }
        }];
    }

    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    ADKApp *app = self.visibleApps[(NSUInteger)ip.row];

    if (self.inSelectMode) {
        if (app.dataContainerURL) {
            [[ADKSelectionState sharedState] toggle:app.bundleIdentifier];
            [t reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }
        return;
    }

    // Tap outside select mode → present per-app actions.
    [self _presentSingleAppActions:app];
}

- (void)_presentSingleAppActions:(ADKApp *)app
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:app.displayName
                                                                   message:app.bundleIdentifier
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self _runBatch:ADKBatchOperationBackup apps:@[app]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Wipe Data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
        [self _tappedWipeSingleApp:app];
    }]];
    NSArray *backups = [[ADKBackupManager sharedManager] backupsForBundleID:app.bundleIdentifier];
    UIAlertAction *restore = [UIAlertAction actionWithTitle:@"Restore from Backup…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        ADKBackupListViewController *vc = [[ADKBackupListViewController alloc] initWithApp:app];
        [self.navigationController pushViewController:vc animated:YES];
    }];
    restore.enabled = backups.count > 0;
    [sheet addAction:restore];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 0, 0);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)_tappedWipeSingleApp:(ADKApp *)app
{
    [self _confirmAction:@"Wipe App Data"
                 message:[NSString stringWithFormat:@"Wipe data for %@? This cannot be undone.", app.displayName]
            destructive:YES
              confirmTitle:@"Wipe"
                 confirmed:^{ [self _runBatch:ADKBatchOperationWipe apps:@[app]]; }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    self.searchText = searchController.searchBar.text;
    [self _recomputeVisibleApps];
}

#pragma mark - Settings

- (void)_openSettings
{
    ADKSettingsViewController *vc = [[ADKSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
