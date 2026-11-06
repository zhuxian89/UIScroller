#import "UIScrollerMenu.h"
#import <math.h>

@implementation UIScrollerMenuState
@end

@interface UIScrollerMenuController ()
@property(nonatomic, strong) UIScrollView *contentScrollView;
@property(nonatomic, strong) UIStackView *contentStack;
@property(nonatomic, strong) UIStackView *mainStack;
@property(nonatomic, strong) UIStackView *moreStack;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIView *statusDot;
@property(nonatomic, strong) UILabel *speedValueLabel;
@property(nonatomic, strong) UILabel *speedHintLabel;
@property(nonatomic, strong) UISegmentedControl *speedControl;
@property(nonatomic, strong) NSArray<UIButton *> *presetButtons;
@property(nonatomic, strong) UIStackView *presetRow;
@property(nonatomic, strong) UIStackView *timerHeading;
@property(nonatomic, strong) UIStackView *customRow;
@property(nonatomic, strong) UIStackView *footer;
@property(nonatomic, strong) UILabel *durationLabel;
@property(nonatomic, strong) UILabel *unitLabel;
@property(nonatomic, strong) UILabel *gestureLabel;
@property(nonatomic, strong) UIButton *customButton;
@property(nonatomic, strong) UIStackView *customEditor;
@property(nonatomic, strong) UIStackView *timerSection;
@property(nonatomic, strong) UITextField *customInput;
@property(nonatomic, strong) UILabel *inputError;
@property(nonatomic, strong) UIButton *primaryButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UISwitch *enabledSwitch;
@property(nonatomic, strong) UIButton *diagnosticsButton;
@property(nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation UIScrollerMenuController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.modalPresentationStyle = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIModalPresentationFormSheet : UIModalPresentationPageSheet;
        self.preferredContentSize = CGSizeMake(440, 540);
    }
    return self;
}

- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIStackView *)stack:(NSArray<UIView *> *)views axis:(UILayoutConstraintAxis)axis spacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = axis;
    stack.spacing = spacing;
    return stack;
}

- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action identifier:(NSString *)identifier filled:(BOOL)filled {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = filled ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = title;
    if (!filled) configuration.baseForegroundColor = UIColor.systemBlueColor;
    configuration.image = symbol ? [UIImage systemImageNamed:symbol] : nil;
    configuration.imagePadding = 8;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    configuration.background.cornerRadius = 12;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(10, 12, 10, 12);
    configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        return result;
    };
    button.configuration = configuration;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.accessibilityIdentifier = [@"uiscroller." stringByAppendingString:identifier];
    NSLayoutConstraint *minimumHeight = [button.heightAnchor constraintGreaterThanOrEqualToConstant:44];
    minimumHeight.priority = UILayoutPriorityRequired - 1;
    minimumHeight.active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIStackView *)heading:(NSString *)title trailing:(UIView *)trailing {
    UILabel *label = [self label:title style:UIFontTextStyleSubheadline color:UIColor.labelColor];
    UIFontDescriptor *descriptor = [label.font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    label.font = [UIFont fontWithDescriptor:descriptor size:0];
    UIStackView *row = [self stack:@[label, trailing] axis:UILayoutConstraintAxisHorizontal spacing:8];
    row.alignment = UIStackViewAlignmentCenter;
    [trailing setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [trailing setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.accessibilityIdentifier = @"uiscroller.menu";
    self.view.backgroundColor = UIColor.clearColor;
    UIVisualEffectView *material = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    material.translatesAutoresizingMaskIntoConstraints = NO;
    material.userInteractionEnabled = NO;
    [self.view addSubview:material];
    [NSLayoutConstraint activateConstraints:@[
        [material.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [material.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [material.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [material.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.view.tintColor = UIColor.systemBlueColor;
    self.view.accessibilityViewIsModal = YES;

    UISheetPresentationController *sheet = self.sheetPresentationController;
    sheet.prefersGrabberVisible = YES;
    sheet.preferredCornerRadius = 27;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    if (@available(iOS 16.0, *)) {
        sheet.detents = @[
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"uiscroller.compact" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                CGFloat contentHeight = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledValueForValue:500];
                return MIN(contentHeight, context.maximumDetentValue);
            }],
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.selectedDetentIdentifier = @"uiscroller.compact";
    } else {
        // iOS 15 has no custom heights; keep the primary controls easy to reach.
        sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }

    self.contentScrollView = [[UIScrollView alloc] init];
    self.contentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentScrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.contentScrollView.alwaysBounceVertical = NO;
    self.contentScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.contentScrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentScrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [self.contentScrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.contentScrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.contentScrollView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]
    ]];

    self.titleLabel = [self label:@"自动滚动" style:UIFontTextStyleTitle2 color:UIColor.labelColor];
    self.titleLabel.font = [UIFont fontWithDescriptor:[self.titleLabel.font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:0];
    self.titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.backButton = [self button:nil symbol:@"chevron.left" action:@selector(showMain) identifier:@"back" filled:NO];
    self.backButton.accessibilityLabel = @"返回滚动设置";
    self.backButton.hidden = YES;
    NSLayoutConstraint *backWidth = [self.backButton.widthAnchor constraintEqualToConstant:44];
    backWidth.priority = UILayoutPriorityRequired - 1;
    backWidth.active = YES;
    UIButton *close = [self button:nil symbol:@"xmark.circle.fill" action:@selector(closeMenu) identifier:@"close" filled:NO];
    close.tintColor = UIColor.secondaryLabelColor;
    close.accessibilityLabel = @"关闭控制面板";
    UIButtonConfiguration *closeConfiguration = close.configuration;
    closeConfiguration.baseForegroundColor = UIColor.secondaryLabelColor;
    closeConfiguration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
    close.configuration = closeConfiguration;
    [close.widthAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *header = [self stack:@[self.backButton, self.titleLabel, close] axis:UILayoutConstraintAxisHorizontal spacing:6];
    header.alignment = UIStackViewAlignmentCenter;

    self.mainStack = [self buildMain];
    self.moreStack = [self buildMore];
    self.contentStack = [self stack:@[header, self.mainStack] axis:UILayoutConstraintAxisVertical spacing:4];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentScrollView addSubview:self.contentStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.topAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.leadingAnchor constant:22],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.trailingAnchor constant:-22],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.bottomAnchor constant:-14],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.contentScrollView.frameLayoutGuide.widthAnchor constant:-44]
    ]];
    [self updateContentSizeLayout];
    [self refreshState];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.isViewLoaded && ![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self updateContentSizeLayout];
    }
}

- (UIStackView *)buildMain {
    self.statusDot = [[UIView alloc] init];
    self.statusDot.layer.cornerRadius = 3;
    [self.statusDot.widthAnchor constraintEqualToConstant:6].active = YES;
    [self.statusDot.heightAnchor constraintEqualToConstant:6].active = YES;
    self.statusLabel = [self label:nil style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    self.statusLabel.accessibilityIdentifier = @"uiscroller.status";
    UIStackView *status = [self stack:@[self.statusDot, self.statusLabel] axis:UILayoutConstraintAxisHorizontal spacing:7];
    status.alignment = UIStackViewAlignmentCenter;

    self.speedValueLabel = [self label:nil style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    UIStackView *speedHeading = [self heading:@"滚动速度" trailing:self.speedValueLabel];
    self.speedControl = [[UISegmentedControl alloc] initWithItems:@[@"慢速", @"标准", @"较快", @"快速"]];
    self.speedControl.accessibilityIdentifier = @"uiscroller.speed";
    self.speedControl.accessibilityLabel = @"滚动速度";
    [self.speedControl.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [self.speedControl addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    self.speedHintLabel = [self label:nil style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    UIStackView *speedSection = [self stack:@[speedHeading, self.speedControl, self.speedHintLabel] axis:UILayoutConstraintAxisVertical spacing:10];

    self.customButton = [self button:@"自定义" symbol:@"chevron.right" action:@selector(toggleCustom) identifier:@"custom" filled:NO];
    UIButtonConfiguration *customConfiguration = self.customButton.configuration;
    customConfiguration.imagePlacement = NSDirectionalRectEdgeTrailing;
    customConfiguration.imagePadding = 3;
    customConfiguration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    customConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(6, 4, 6, 0);
    self.customButton.configuration = customConfiguration;
    self.customButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    self.customButton.accessibilityHint = @"输入 1 到 180 分钟";
    self.timerHeading = [self heading:@"定时停止" trailing:self.customButton];
    NSMutableArray<UIButton *> *presets = [NSMutableArray array];
    for (NSNumber *number in @[@0, @5, @15, @30]) {
        NSInteger minutes = number.integerValue;
        UIButton *button = [self button:minutes ? [NSString stringWithFormat:@"%ld 分钟", (long)minutes] : @"关闭" symbol:nil action:@selector(presetChanged:) identifier:[NSString stringWithFormat:@"preset.%ld", (long)minutes] filled:NO];
        button.tag = minutes;
        UIButtonConfiguration *configuration = button.configuration;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(10, 2, 10, 2);
        configuration.background.cornerRadius = 10;
        button.configuration = configuration;
        [presets addObject:button];
    }
    self.presetButtons = presets;
    self.presetRow = [self stack:presets axis:UILayoutConstraintAxisHorizontal spacing:8];
    self.presetRow.distribution = UIStackViewDistributionFillEqually;

    self.durationLabel = [self label:@"时长" style:UIFontTextStyleSubheadline color:UIColor.secondaryLabelColor];
    self.customInput = [[UITextField alloc] init];
    self.customInput.keyboardType = UIKeyboardTypeNumberPad;
    self.customInput.borderStyle = UITextBorderStyleRoundedRect;
    self.customInput.textAlignment = NSTextAlignmentCenter;
    self.customInput.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.customInput.adjustsFontForContentSizeCategory = YES;
    self.customInput.accessibilityIdentifier = @"uiscroller.customInput";
    self.customInput.accessibilityLabel = @"定时时长，分钟";
    self.customInput.placeholder = @"1–180";
    [self.customInput.widthAnchor constraintGreaterThanOrEqualToConstant:72].active = YES;
    [self.customInput.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    self.unitLabel = [self label:@"分钟" style:UIFontTextStyleSubheadline color:UIColor.secondaryLabelColor];
    UIButton *apply = [self button:@"应用" symbol:nil action:@selector(applyCustom) identifier:@"customApply" filled:YES];
    self.customRow = [self stack:@[self.durationLabel, self.customInput, self.unitLabel, apply] axis:UILayoutConstraintAxisHorizontal spacing:8];
    self.customRow.alignment = UIStackViewAlignmentCenter;
    [self.durationLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.unitLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [apply setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    self.inputError = [self label:@"请输入 1–180 之间的整数。" style:UIFontTextStyleCaption1 color:UIColor.systemRedColor];
    self.inputError.hidden = YES;
    self.customEditor = [self stack:@[self.customRow, self.inputError] axis:UILayoutConstraintAxisVertical spacing:8];
    self.timerSection = [self stack:@[self.timerHeading, self.presetRow] axis:UILayoutConstraintAxisVertical spacing:8];

    UIImageView *sun = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sun.max"]];
    sun.tintColor = UIColor.secondaryLabelColor;
    sun.contentMode = UIViewContentModeScaleAspectFit;
    [sun.widthAnchor constraintEqualToConstant:17].active = YES;
    [sun.heightAnchor constraintEqualToConstant:17].active = YES;
    UILabel *awake = [self label:@"滚动时保持屏幕常亮" style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    UIStackView *awakeRow = [self stack:@[sun, awake] axis:UILayoutConstraintAxisHorizontal spacing:7];
    awakeRow.alignment = UIStackViewAlignmentCenter;
    self.primaryButton = [self button:@"开始滚动" symbol:@"play.fill" action:@selector(primaryAction) identifier:@"primary" filled:YES];
    [self.primaryButton.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    UIButton *more = [self button:@"更多设置" symbol:@"ellipsis" action:@selector(showMore) identifier:@"more" filled:NO];
    UIButtonConfiguration *moreConfiguration = more.configuration;
    moreConfiguration.baseForegroundColor = UIColor.secondaryLabelColor;
    moreConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(6, 0, 6, 4);
    more.configuration = moreConfiguration;
    self.gestureLabel = [self label:@"轻点或拖动正文可停止" style:UIFontTextStyleCaption2 color:UIColor.secondaryLabelColor];
    self.gestureLabel.textAlignment = NSTextAlignmentRight;
    self.footer = [self stack:@[more, self.gestureLabel] axis:UILayoutConstraintAxisHorizontal spacing:8];
    self.footer.alignment = UIStackViewAlignmentCenter;
    UIStackView *stack = [self stack:@[status, speedSection, self.timerSection, awakeRow, self.primaryButton, self.footer] axis:UILayoutConstraintAxisVertical spacing:18];
    [stack setCustomSpacing:23 afterView:status];
    [stack setCustomSpacing:12 afterView:awakeRow];
    [stack setCustomSpacing:2 afterView:self.primaryButton];
    return stack;
}

- (UIStackView *)buildMore {
    UILabel *context = [self label:[NSString stringWithFormat:@"仅对 %@ 生效", self.appName] style:UIFontTextStyleSubheadline color:UIColor.secondaryLabelColor];
    UILabel *enabledLabel = [self label:@"在此 App 启用" style:UIFontTextStyleBody color:UIColor.labelColor];
    UILabel *enabledHint = [self label:@"允许在此 App 中自动滚动" style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    UIStackView *enabledLabels = [self stack:@[enabledLabel, enabledHint] axis:UILayoutConstraintAxisVertical spacing:4];
    self.enabledSwitch = [[UISwitch alloc] init];
    self.enabledSwitch.accessibilityIdentifier = @"uiscroller.enabled";
    self.enabledSwitch.accessibilityLabel = @"在此 App 启用自动滚动";
    [self.enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    UIStackView *enabledRow = [self stack:@[enabledLabels, self.enabledSwitch] axis:UILayoutConstraintAxisHorizontal spacing:12];
    enabledRow.alignment = UIStackViewAlignmentCenter;
    enabledRow.layoutMarginsRelativeArrangement = YES;
    enabledRow.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(15, 15, 15, 15);

    self.diagnosticsButton = [self button:@"复制诊断信息" symbol:@"doc.on.doc" action:@selector(copyDiagnostics) identifier:@"diagnostics" filled:NO];
    self.diagnosticsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    UIButtonConfiguration *diagnosticsConfiguration = self.diagnosticsButton.configuration;
    diagnosticsConfiguration.subtitle = @"不包含正文或账号信息";
    diagnosticsConfiguration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    diagnosticsConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(14, 15, 14, 15);
    self.diagnosticsButton.configuration = diagnosticsConfiguration;
    UIStackView *settings = [self stack:@[enabledRow, self.diagnosticsButton] axis:UILayoutConstraintAxisVertical spacing:0];
    settings.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    settings.layer.cornerRadius = 13;
    settings.clipsToBounds = YES;
    UILabel *explanation = [self label:@"关闭后将停止当前滚动。你仍可用双指长按打开面板，随时重新开启。" style:UIFontTextStyleFootnote color:UIColor.secondaryLabelColor];
    UILabel *name = [self label:@"UIScroller" style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    UILabel *version = [self label:self.versionText style:UIFontTextStyleCaption1 color:UIColor.secondaryLabelColor];
    version.textAlignment = NSTextAlignmentRight;
    UIStackView *versionRow = [self stack:@[name, version] axis:UILayoutConstraintAxisHorizontal spacing:8];
    UIButton *back = [self button:@"返回滚动设置" symbol:nil action:@selector(showMain) identifier:@"done" filled:YES];
    [back.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    UIStackView *stack = [self stack:@[context, settings, explanation, versionRow, back] axis:UILayoutConstraintAxisVertical spacing:22];
    return stack;
}

- (void)updateContentSizeLayout {
    BOOL accessibilitySize = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    UILayoutConstraintAxis axis = accessibilitySize ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.presetRow.axis = axis;
    self.timerHeading.axis = axis;
    self.timerHeading.alignment = accessibilitySize ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    self.customRow.axis = axis;
    self.customRow.alignment = accessibilitySize ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    self.durationLabel.text = accessibilitySize ? @"时长（分钟）" : @"时长";
    self.unitLabel.hidden = accessibilitySize;
    self.footer.axis = axis;
    self.footer.alignment = accessibilitySize ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    self.gestureLabel.textAlignment = accessibilitySize ? NSTextAlignmentLeft : NSTextAlignmentRight;
    if (@available(iOS 16.0, *)) {
        [self.sheetPresentationController invalidateDetents];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshState];
    [self.refreshTimer invalidate];
    __weak UIScrollerMenuController *weakSelf = self;
    self.refreshTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshState];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.refreshTimer forMode:NSRunLoopCommonModes];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)dealloc {
    [_refreshTimer invalidate];
}

- (void)refreshState {
    if (!self.isViewLoaded) return;
    UIScrollerMenuState *state = self.readState();
    NSString *status = state.statusText;
    if (state.running) {
        if (state.remainingSeconds >= 0) {
            NSInteger seconds = (NSInteger)ceil(MAX(0, state.remainingSeconds));
            status = [NSString stringWithFormat:@"%@ · %02ld:%02ld 后停止", status, (long)(seconds / 60), (long)(seconds % 60)];
        } else {
            status = [status stringByAppendingString:@" · 未设置定时"];
        }
    } else if (state.enabled && state.canStart) {
        status = [NSString stringWithFormat:@"%@ · %@", self.appName, status];
    }
    self.statusLabel.text = status;
    self.statusLabel.textColor = state.running ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
    self.statusDot.backgroundColor = self.statusLabel.textColor;
    NSArray<NSString *> *speedNames = @[@"慢速", @"标准", @"较快", @"快速"];
    NSArray<NSString *> *speedHints = @[@"给每一句话多一点时间", @"适合日常阅读", @"略过熟悉的内容", @"快速浏览长篇内容"];
    self.speedControl.selectedSegmentIndex = state.speed;
    UIFont *speedFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:15] maximumPointSize:24];
    [self.speedControl setTitleTextAttributes:@{NSFontAttributeName:speedFont} forState:UIControlStateNormal];
    self.speedValueLabel.text = speedNames[state.speed];
    self.speedHintLabel.text = speedHints[state.speed];
    for (UIButton *button in self.presetButtons) {
        BOOL selected = button.tag == state.minutes;
        UIButtonConfiguration *configuration = button.configuration;
        configuration.baseForegroundColor = selected ? UIColor.systemBlueColor : UIColor.labelColor;
        configuration.background.backgroundColor = selected ? [UIColor.systemBlueColor colorWithAlphaComponent:0.10] : UIColor.tertiarySystemFillColor;
        configuration.background.strokeColor = selected ? UIColor.systemBlueColor : UIColor.clearColor;
        configuration.background.strokeWidth = selected ? 1.5 : 0;
        button.configuration = configuration;
        button.accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    }
    BOOL custom = ![@[@0, @5, @15, @30] containsObject:@(state.minutes)];
    UIButtonConfiguration *customConfiguration = self.customButton.configuration;
    customConfiguration.title = custom ? [NSString stringWithFormat:@"%ld 分钟", (long)state.minutes] : @"自定义";
    self.customButton.configuration = customConfiguration;
    self.enabledSwitch.on = state.enabled;
    self.diagnosticsButton.hidden = !state.diagnosticsAvailable;
    UIButtonConfiguration *primary = self.primaryButton.configuration;
    primary.title = state.running ? @"停止滚动" : !state.enabled ? @"此 App 已禁用" : @"开始滚动";
    primary.image = [UIImage systemImageNamed:state.running ? @"stop.fill" : @"play.fill"];
    self.primaryButton.configuration = primary;
    self.primaryButton.enabled = state.running || (state.enabled && state.canStart);
}

- (void)speedChanged:(UISegmentedControl *)sender {
    self.setSpeed(sender.selectedSegmentIndex);
    [self refreshState];
}

- (void)presetChanged:(UIButton *)sender {
    self.setMinutes(sender.tag);
    [self hideCustomEditor];
    [self.view endEditing:YES];
    [self refreshState];
}

- (void)hideCustomEditor {
    [self.timerSection removeArrangedSubview:self.customEditor];
    [self.customEditor removeFromSuperview];
}

- (void)toggleCustom {
    self.inputError.hidden = YES;
    if (!self.customEditor.superview) {
        [self.timerSection addArrangedSubview:self.customEditor];
        NSInteger minutes = self.readState().minutes;
        self.customInput.text = [NSString stringWithFormat:@"%ld", (long)(minutes ? minutes : 15)];
        [self.sheetPresentationController animateChanges:^{
            self.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        }];
        [self.customInput becomeFirstResponder];
        [self.view layoutIfNeeded];
        [self.contentScrollView scrollRectToVisible:[self.customEditor convertRect:self.customEditor.bounds toView:self.contentScrollView] animated:YES];
    } else {
        [self hideCustomEditor];
        [self.view endEditing:YES];
    }
}

- (void)applyCustom {
    NSString *text = [self.customInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *nonDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    NSInteger minutes = text.integerValue;
    if (text.length == 0 || text.length > 3 || [text rangeOfCharacterFromSet:nonDigits].location != NSNotFound || minutes < 1 || minutes > 180) {
        self.inputError.hidden = NO;
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.inputError.text);
        return;
    }
    self.setMinutes(minutes);
    [self hideCustomEditor];
    self.inputError.hidden = YES;
    [self.view endEditing:YES];
    [self refreshState];
}

- (void)primaryAction {
    UIScrollerMenuState *state = self.readState();
    if (state.running) {
        self.stopScrolling();
        [self refreshState];
    } else if (state.enabled && state.canStart) {
        void (^start)(void) = self.startScrolling;
        [self dismissViewControllerAnimated:YES completion:start];
    }
}

- (void)closeMenu {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMore {
    [self.view endEditing:YES];
    [self.contentStack removeArrangedSubview:self.mainStack];
    [self.mainStack removeFromSuperview];
    [self.contentStack addArrangedSubview:self.moreStack];
    self.backButton.hidden = NO;
    self.titleLabel.text = @"更多设置";
    [self.contentScrollView setContentOffset:CGPointZero animated:NO];
    [self refreshState];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)showMain {
    [self.contentStack removeArrangedSubview:self.moreStack];
    [self.moreStack removeFromSuperview];
    [self.contentStack addArrangedSubview:self.mainStack];
    self.backButton.hidden = YES;
    self.titleLabel.text = @"自动滚动";
    [self.contentScrollView setContentOffset:CGPointZero animated:NO];
    [self refreshState];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)enabledChanged:(UISwitch *)sender {
    self.setEnabled(sender.on);
    [self refreshState];
}

- (void)copyDiagnostics {
    UIPasteboard.generalPasteboard.string = self.diagnosticReport();
    UIButtonConfiguration *configuration = self.diagnosticsButton.configuration;
    configuration.title = @"已复制诊断信息";
    configuration.image = [UIImage systemImageNamed:@"checkmark"];
    self.diagnosticsButton.configuration = configuration;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"已复制诊断信息");
}

@end
