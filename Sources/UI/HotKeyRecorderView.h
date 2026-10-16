#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

@protocol HotKeyRecorderDelegate <NSObject>
- (void)hotKeyRecorderDidRecordKey:(UInt32)keyCode modifiers:(UInt32)carbonModifiers;
@end

@interface HotKeyRecorderView : NSView

@property (nonatomic, weak) id<HotKeyRecorderDelegate> delegate;
@property (nonatomic, assign) UInt32 currentKeyCode;
@property (nonatomic, assign) UInt32 currentModifiers;
@property (nonatomic, assign, readonly) BOOL isRecording;

- (void)setKeyCode:(UInt32)keyCode modifiers:(UInt32)modifiers;

@end

NS_ASSUME_NONNULL_END
