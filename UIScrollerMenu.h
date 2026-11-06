#import <UIKit/UIKit.h>

@interface UIScrollerMenuState : NSObject
@property(nonatomic) BOOL running;
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL canStart;
@property(nonatomic) NSInteger speed;
@property(nonatomic) NSInteger minutes;
@property(nonatomic) NSTimeInterval remainingSeconds;
@property(nonatomic, copy) NSString *statusText;
@property(nonatomic) BOOL diagnosticsAvailable;
@end

@interface UIScrollerMenuController : UIViewController
@property(nonatomic, copy) UIScrollerMenuState *(^readState)(void);
@property(nonatomic, copy) void (^setSpeed)(NSInteger speed);
@property(nonatomic, copy) void (^setMinutes)(NSInteger minutes);
@property(nonatomic, copy) void (^setEnabled)(BOOL enabled);
@property(nonatomic, copy) void (^startScrolling)(void);
@property(nonatomic, copy) void (^stopScrolling)(void);
@property(nonatomic, copy) NSString *(^diagnosticReport)(void);
@property(nonatomic, copy) NSString *appName;
@property(nonatomic, copy) NSString *versionText;
- (void)refreshState;
@end
