#import <Cocoa/Cocoa.h>
#import "../Models/AnnotationItem.h"
#import "AnnotationToolbarView.h"

NS_ASSUME_NONNULL_BEGIN

@class CaptureOverlayView;

@protocol CaptureOverlayDelegate <NSObject>
- (void)captureOverlayDidCancel:(CaptureOverlayView *)overlay;
- (void)captureOverlay:(CaptureOverlayView *)overlay didFinishWithImage:(NSImage *)image shouldSaveToFile:(BOOL)save;
@end

@interface CaptureOverlayView : NSView <AnnotationToolbarDelegate, NSTextFieldDelegate>

@property (nonatomic, weak) id<CaptureOverlayDelegate> delegate;
@property (nonatomic, strong) NSImage *backgroundImage;
@property (nonatomic, assign) NSRect selectionRect;
@property (nonatomic, assign) CGFloat screenScale;

- (instancetype)initWithFrame:(NSRect)frame backgroundImage:(NSImage *)bgImage screenScale:(CGFloat)scale;
- (void)closeCapture;

@end

NS_ASSUME_NONNULL_END
