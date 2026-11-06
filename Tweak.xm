#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIScrollerMenu.h"

@interface UIScrollView (UIScroller)
- (void)startUIScroller;
- (void)stopUIScroller;
- (void)autoScroll;
- (void)autoDisableScrolling;
- (void)updateUIScrollerGestures;
- (void)handleUIScrollerPan:(UIPanGestureRecognizer *)gesture;
- (void)handleTaps:(UITapGestureRecognizer *)gesture;
@end

NSTimer *timer = nil;
NSTimer *autoDisableTimer = nil;
static __weak UIScrollView *activeScrollView = nil;
static char stopGestureKey;
static char menuGestureKey;
static NSMutableArray<NSString *> *scrollEvents;
static __weak UIScrollView *lastSelectedScrollView;
static NSUInteger lastWaitFlags;
static NSUInteger diagnosticMoves;
static NSUInteger diagnosticReversals;
static CGFloat lastWrittenY;
static BOOL linuxDo103;
static BOOL readerScrollStateEnabled;
static BOOL readerDelegateHookInstalled;
static __weak UIScrollView *offsetWriteView;
static __weak UIScrollView *readerCallbackView;
static BOOL idleTimerOverridden;
static BOOL previousIdleTimerDisabled;
static __weak UIScrollerMenuController *currentMenu;
BOOL verticalDown = NO;
int scrollSpeedType = 0; // 0: Slow, 1: Normal, 2: Medium, 3: Fast
int autoDisableMinutes = 0; // 0: Disabled, >0: Minutes until auto-disable

static NSString *describeScrollView(UIScrollView *view) {
    if (!view) return @"none";
    UIEdgeInsets inset = view.adjustedContentInset;
    return [NSString stringWithFormat:@"%@ %p window=%d enabled=%d attached=%d y=%.2f content=%.2f height=%.2f inset=%.2f/%.2f tracking=%d dragging=%d decelerating=%d",
        NSStringFromClass(view.class), view, view.window != nil, view.scrollEnabled,
        objc_getAssociatedObject(view, &stopGestureKey) != nil, view.contentOffset.y,
        view.contentSize.height, view.bounds.size.height, inset.top, inset.bottom,
        view.tracking, view.dragging, view.decelerating];
}

static void recordScrollEvent(NSString *event, UIScrollView *view) {
    if (!scrollEvents) return;
    [scrollEvents addObject:[NSString stringWithFormat:@"%.2f %@ | %@",
        NSProcessInfo.processInfo.systemUptime, event, describeScrollView(view)]];
    if (scrollEvents.count > 32) [scrollEvents removeObjectAtIndex:0];
}

static void stopScrolling(NSString *reason, UIScrollView *source) {
    if (timer || autoDisableTimer) {
        recordScrollEvent([NSString stringWithFormat:@"STOP %@ source=%@ %p", reason,
            NSStringFromClass(source.class), source], activeScrollView);
    }
    UIScrollView *view = activeScrollView;
    if (view) {
        [view.panGestureRecognizer removeTarget:view action:@selector(handleUIScrollerPan:)];
        UITapGestureRecognizer *tap = objc_getAssociatedObject(view, &stopGestureKey);
        if (tap) {
            [view removeGestureRecognizer:tap];
            objc_setAssociatedObject(view, &stopGestureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    [timer invalidate];
    timer = nil;
    [autoDisableTimer invalidate];
    autoDisableTimer = nil;
    activeScrollView = nil;
    readerScrollStateEnabled = NO;
    if (idleTimerOverridden) {
        UIApplication.sharedApplication.idleTimerDisabled = previousIdleTimerDisabled;
        idleTimerOverridden = NO;
    }
}

static void rescheduleAutoDisableTimer(void) {
    [autoDisableTimer invalidate];
    autoDisableTimer = nil;
    if (timer.valid && autoDisableMinutes > 0) {
        autoDisableTimer = [NSTimer timerWithTimeInterval:autoDisableMinutes * 60 repeats:NO block:^(NSTimer *disableTimer) {
            UIScrollView *scrollView = activeScrollView;
            if (scrollView) [scrollView autoDisableScrolling];
            else stopScrolling(@"active view released", nil);
        }];
        [NSRunLoop.mainRunLoop addTimer:autoDisableTimer forMode:NSRunLoopCommonModes];
    }
}

static void appendVisibleScrollViews(UIView *view, UIWindow *window, NSMutableArray<NSString *> *lines) {
    if (view.hidden || view.alpha == 0 || view == currentMenu.viewIfLoaded) return;
    if ([view isKindOfClass:UIScrollView.class] && CGRectIntersectsRect([view convertRect:view.bounds toView:window], window.bounds)) {
        [lines addObject:describeScrollView((UIScrollView *)view)];
    }
    for (UIView *child in view.subviews) appendVisibleScrollViews(child, window, lines);
}

static UIViewController *topViewControllerInWindow(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    while (controller) {
        UIViewController *next = controller.presentedViewController;
        if (!next && [controller isKindOfClass:UINavigationController.class]) {
            next = ((UINavigationController *)controller).visibleViewController;
        } else if (!next && [controller isKindOfClass:UITabBarController.class]) {
            next = ((UITabBarController *)controller).selectedViewController;
        }
        if (!next) break;
        controller = next;
    }
    return controller;
}

static BOOL menuIsPresented(void) {
    return currentMenu.presentingViewController != nil || currentMenu.isBeingPresented;
}

// The recognizer belongs to the host window, so exclude our sheet's interactions.
@interface UIScrollerMenuGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@end
@implementation UIScrollerMenuGestureDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    return !menuIsPresented();
}
@end
static UIScrollerMenuGestureDelegate *menuGestureDelegate;

static NSString *scrollDiagnosticReport(UIWindow *window) {
    NSMutableArray<NSString *> *views = [NSMutableArray array];
    if (window) appendVisibleScrollViews(window, window, views);
    return [NSString stringWithFormat:@"UIScroller 1.0.7 beta1 (iOS 15 compatibility)\niOS %@\nApp %@ %@ (%@)\ntimer=%d countdown=%d readerAdapter=%d\nactive: %@\nlast target: %@\n\nRecent events (no post content):\n%@\n\nVisible scroll views:\n%@",
        UIDevice.currentDevice.systemVersion, NSBundle.mainBundle.bundleIdentifier,
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"],
        timer.valid, autoDisableTimer.valid, readerScrollStateEnabled, describeScrollView(activeScrollView),
        describeScrollView(lastSelectedScrollView), [scrollEvents componentsJoinedByString:@"\n"],
        [views componentsJoinedByString:@"\n"]];
}

static void openMenuInWindow(UIScrollView *scrollView, UIWindow *window) {
    if (menuIsPresented()) return;
    UIViewController *presenter = topViewControllerInWindow(window);
    if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;

    __weak UIScrollView *target = scrollView;
    __weak UIWindow *sourceWindow = window;
    __block BOOL wasRunning = timer.valid;
    lastSelectedScrollView = scrollView;
    recordScrollEvent(@"MENU target", scrollView);
    UIScrollerMenuController *menu = [UIScrollerMenuController new];
    currentMenu = menu;
    menu.versionText = @"1.0.7 beta1";
    menu.appName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?:
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
    menu.readState = ^UIScrollerMenuState *{
        UIScrollerMenuState *state = [UIScrollerMenuState new];
        UIScrollView *view = target;
        UIEdgeInsets inset = view.adjustedContentInset;
        state.running = timer.valid;
        state.enabled = ![NSUserDefaults.standardUserDefaults boolForKey:@"uiscroller_disabled"];
        state.canStart = sourceWindow && view.window == sourceWindow && view.scrollEnabled &&
            view.contentSize.height + inset.top + inset.bottom - view.bounds.size.height > 1.0;
        state.speed = scrollSpeedType;
        state.minutes = autoDisableMinutes;
        state.remainingSeconds = autoDisableTimer.valid ? MAX(0, autoDisableTimer.fireDate.timeIntervalSinceNow) : -1;
        state.diagnosticsAvailable = scrollEvents != nil;
        if (state.running) {
            state.statusText = @"正在滚动";
            wasRunning = YES;
        } else if (!state.enabled) {
            state.statusText = @"此 App 已禁用";
        } else if (!state.canStart) {
            state.statusText = @"请在可滚动的正文或列表上双指长按";
        } else {
            state.statusText = wasRunning ? @"已停止" : @"尚未开始";
        }
        return state;
    };
    menu.setSpeed = ^(NSInteger speed) {
        scrollSpeedType = (int)speed;
        [NSUserDefaults.standardUserDefaults setInteger:speed forKey:@"uiscroller_speed"];
    };
    menu.setMinutes = ^(NSInteger minutes) {
        if (autoDisableMinutes == minutes) return;
        autoDisableMinutes = (int)minutes;
        [NSUserDefaults.standardUserDefaults setInteger:minutes forKey:@"uiscroller_minutes"];
        rescheduleAutoDisableTimer();
    };
    menu.setEnabled = ^(BOOL enabled) {
        [NSUserDefaults.standardUserDefaults setBool:!enabled forKey:@"uiscroller_disabled"];
        if (!enabled) stopScrolling(@"disabled from menu", activeScrollView);
    };
    menu.startScrolling = ^{
        UIScrollView *view = target;
        if (!sourceWindow || view.window != sourceWindow) {
            recordScrollEvent(@"REJECT menu target left its window", view);
            return;
        }
        verticalDown = YES;
        [view startUIScroller];
    };
    menu.stopScrolling = ^{
        stopScrolling(@"menu stop", activeScrollView);
    };
    menu.diagnosticReport = ^NSString *{
        return scrollDiagnosticReport(sourceWindow);
    };
    [presenter presentViewController:menu animated:YES completion:nil];
}

void openSimpleMenu(UIScrollView *scrollView) {
    openMenuInWindow(scrollView, scrollView.window);
}

void openSimpleMenuAtPoint(UIWindow *window, CGPoint point) {
    if (menuIsPresented()) return;
    UIScrollView *target = nil;
    for (UIView *view = [window hitTest:point withEvent:nil]; view; view = view.superview) {
        if (![view isKindOfClass:UIScrollView.class]) continue;
        UIScrollView *candidate = (UIScrollView *)view;
        UIEdgeInsets inset = candidate.adjustedContentInset;
        // Ignore the sub-point rounding overflow of single-line text views.
        if (candidate.scrollEnabled && candidate.contentSize.height + inset.top + inset.bottom - candidate.bounds.size.height > 1.0) {
            target = candidate;
            break;
        }
    }
    openMenuInWindow(target, window);
}

%hook UIWindow

    - (void)becomeKeyWindow {
        %orig;
        if (!objc_getAssociatedObject(self, &menuGestureKey)) {
            UILongPressGestureRecognizer *menuGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuLongPress:)];
            menuGestureRecognizer.numberOfTouchesRequired = 2;
            if (!menuGestureDelegate) menuGestureDelegate = [UIScrollerMenuGestureDelegate new];
            menuGestureRecognizer.delegate = menuGestureDelegate;
            [self addGestureRecognizer:menuGestureRecognizer];
            objc_setAssociatedObject(self, &menuGestureKey, menuGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    %new
    - (void)handleMenuLongPress:(UILongPressGestureRecognizer *)gesture {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            openSimpleMenuAtPoint(self, [gesture locationInView:self]);
        }
    }

%end

%group LinuxDoReader

%hook UIScrollerReaderCoordinator

    - (void)scrollViewDidScroll:(UIScrollView *)scrollView {
        if (scrollView != offsetWriteView || scrollView != activeScrollView) {
            %orig;
            return;
        }
        // Only the host's synchronous callback sees the temporary scroll state.
        // UIKit's offset setter and later asynchronous updates see native state.
        UIScrollView *previousCallbackView = readerCallbackView;
        readerCallbackView = scrollView;
        @try {
            %orig;
        } @finally {
            readerCallbackView = previousCallbackView;
        }
    }

%end

%end

%hook UIScrollView

    - (BOOL)isDecelerating {
        BOOL nativeState = %orig;
        return nativeState || (self == readerCallbackView && self == activeScrollView);
    }

    - (void)didMoveToWindow {
        %orig;
        if (!self.window) [self stopUIScroller];
    }

    %new
    - (void)updateUIScrollerGestures {
        // A manual drag only stops autoscroll; starting is an explicit menu action.
        [self.panGestureRecognizer removeTarget:self action:@selector(handleUIScrollerPan:)];
        if (!self.window) {
            if (activeScrollView == self) stopScrolling(@"left window", self);
            return;
        }
        [self.panGestureRecognizer addTarget:self action:@selector(handleUIScrollerPan:)];

        if (!objc_getAssociatedObject(self, &stopGestureKey)) {
            UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaps:)];
            singleTapGestureRecognizer.cancelsTouchesInView = NO;
            [self addGestureRecognizer:singleTapGestureRecognizer];
            objc_setAssociatedObject(self, &stopGestureKey, singleTapGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if ([self isKindOfClass:UICollectionView.class]) recordScrollEvent(@"ATTACH collection", self);
    }

    %new
    - (void)handleUIScrollerPan:(UIPanGestureRecognizer *)gesture {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            stopScrolling(@"manual drag", self);
        }
    }

    %new
    - (void)handleTaps:(UITapGestureRecognizer *)gesture {
        // A tap on an embedded scroll view should also stop the active parent.
        stopScrolling(@"tap", self);
    }

    %new
    - (void)startUIScroller {
        if (!self.window || !self.scrollEnabled || [[NSUserDefaults standardUserDefaults] boolForKey:@"uiscroller_disabled"]) {
            recordScrollEvent(@"REJECT offscreen, scroll disabled or app disabled", self);
            return;
        }
        UIEdgeInsets inset = self.adjustedContentInset;
        if (self.contentSize.height + inset.top + inset.bottom - self.bounds.size.height <= 1.0) {
            recordScrollEvent(@"REJECT no meaningful vertical scroll range", self);
            return;
        }
        BOOL useReaderState = linuxDo103 && strcmp(class_getName(self.class), "_TtCV8LINUX_DO16ReadingPostsList8ListView") == 0;
        if (useReaderState) {
            id<UIScrollViewDelegate> delegate = self.delegate;
            if (!delegate || strcmp(class_getName(delegate.class), "_TtCV8LINUX_DO16ReadingPostsList11Coordinator") != 0 || ![delegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
                recordScrollEvent(@"REJECT unrecognized LINUX DO scroll delegate", self);
                UIAlertController *error = [UIAlertController alertControllerWithTitle:@"UIScroller"
                    message:@"当前正文控件暂不支持自动滚动，请复制滚动诊断。" preferredStyle:UIAlertControllerStyleAlert];
                [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [topViewControllerInWindow(self.window) presentViewController:error animated:YES completion:nil];
                return;
            }
            if (!readerDelegateHookInstalled) {
                %init(LinuxDoReader, UIScrollerReaderCoordinator = delegate.class);
                readerDelegateHookInstalled = YES;
            }
        }
        stopScrolling(@"new scroll session", self);
        activeScrollView = self;
        readerScrollStateEnabled = useReaderState;
        // Keep the screen awake only for this session; preserve the host's setting.
        previousIdleTimerDisabled = UIApplication.sharedApplication.idleTimerDisabled;
        idleTimerOverridden = YES;
        UIApplication.sharedApplication.idleTimerDisabled = YES;
        if (useReaderState) recordScrollEvent(@"LINUX DO UIKit scroll-state adapter ready", self);
        [self updateUIScrollerGestures];
        lastWaitFlags = NSUIntegerMax;
        diagnosticMoves = 0;
        diagnosticReversals = 0;
        recordScrollEvent(verticalDown ? @"START down" : @"START up", self);
        // Read the weak active view so a timer cannot keep a dismissed page alive.
        timer = [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *scrollTimer) {
            UIScrollView *scrollView = activeScrollView;
            if (scrollView) [scrollView autoScroll];
            else stopScrolling(@"active view released", nil);
        }];

        rescheduleAutoDisableTimer();
    }

    %new
    - (void)stopUIScroller {
        // Unrelated views leaving the window must not cancel the active page.
        if (activeScrollView == self) stopScrolling(@"stop requested", self);
    }

    %new
    - (void)autoScroll {

        if (activeScrollView != self) return;
        if (!self.window || !self.scrollEnabled) {
            stopScrolling(@"offscreen or scroll disabled", self);
            return;
        }
        // Let UIKit finish the user's drag and native deceleration first.
        NSUInteger waitFlags = (self.tracking ? 1 : 0) | (self.dragging ? 2 : 0) | (self.decelerating ? 4 : 0);
        if (waitFlags != lastWaitFlags) {
            recordScrollEvent(waitFlags ? @"TICK waiting for native touch/momentum" : @"TICK ready", self);
            lastWaitFlags = waitFlags;
        }
        if (waitFlags) return;

        // Variables
        float scrollSpeed = 1.0; // Default scrolling speed
        CGPoint offset = self.contentOffset;
        if (scrollEvents && diagnosticMoves > 0 && diagnosticReversals < 3 && (verticalDown ? offset.y < lastWrittenY : offset.y > lastWrittenY)) {
            recordScrollEvent([NSString stringWithFormat:@"OFFSET moved back since actual write %.2f", lastWrittenY], self);
            diagnosticReversals++;
        }

        // Adjust based on user's prefs
        if (scrollSpeedType == 0) scrollSpeed = 0.5; // Slow
        else if (scrollSpeedType == 1) scrollSpeed = 1.0; // Normal
        else if (scrollSpeedType == 2) scrollSpeed = 1.5; // Medium
        else if (scrollSpeedType == 3) scrollSpeed = 2.0; // Fast

        UIEdgeInsets inset = self.adjustedContentInset;
        CGFloat minY = -inset.top;
        CGFloat maxY = MAX(minY, self.contentSize.height + inset.bottom - self.bounds.size.height);
        if (maxY <= minY || (verticalDown ? offset.y >= maxY : offset.y <= minY)) {
            stopScrolling(@"no range or reached edge", self);
            return;
        }

        offset.y = MIN(maxY, MAX(minY, offset.y + (verticalDown ? scrollSpeed : -scrollSpeed)));
        if (readerScrollStateEnabled) {
            UIScrollView *previousWriteView = offsetWriteView;
            offsetWriteView = self;
            @try {
                [self setContentOffset:offset animated:NO];
            } @finally {
                offsetWriteView = previousWriteView;
            }
        } else {
            [self setContentOffset:offset animated:NO];
        }
        // UIKit may quantize to physical pixels; compare subsequent ticks with
        // this observed position, not the unrounded request.
        lastWrittenY = self.contentOffset.y;
        if (scrollEvents && diagnosticMoves < 2) recordScrollEvent([NSString stringWithFormat:@"WRITE requested y=%.2f", offset.y], self);
        diagnosticMoves++;
        if (verticalDown ? offset.y >= maxY : offset.y <= minY) stopScrolling(@"reached edge after move", self);
    }

    %new
    - (void)autoDisableScrolling {
        if (activeScrollView != self) return;
        stopScrolling(@"countdown expired", self);
        [currentMenu refreshState];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"定时结束，已停止滚动");
    }

%end

// Collection views need their own departure hook for prompt session cleanup.
%hook UICollectionView

    - (void)didMoveToWindow {
        %orig;
        if (!self.window) [self stopUIScroller];
    }

%end

%ctor {
    // Only run on user installed apps
    NSString *executablePath = NSProcessInfo.processInfo.arguments[0];
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"org.linuxdo.community"]) {
        scrollEvents = [NSMutableArray array];
        linuxDo103 = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqualToString:@"1.0.3"] &&
            [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] isEqualToString:@"6"];
    }
    if ([executablePath containsString:@"/var/containers/Bundle/Application"]) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        scrollSpeedType = (int)MIN(3, MAX(0, [defaults integerForKey:@"uiscroller_speed"]));
        autoDisableMinutes = (int)MIN(180, MAX(0, [defaults integerForKey:@"uiscroller_minutes"]));
        %init;
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
            object:nil queue:nil usingBlock:^(NSNotification *notification) {
                stopScrolling(@"app entered background", activeScrollView);
            }];
    }
}
