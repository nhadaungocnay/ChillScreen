#import <Cocoa/Cocoa.h>
#import "../Models/AnnotationItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AnnotationToolbarDelegate <NSObject>
- (void)toolbarDidSelectTool:(AnnotationType)tool;
- (void)toolbarDidSelectColor:(NSColor *)color;
- (void)toolbarDidSelectStrokeWidth:(CGFloat)width;
- (void)toolbarDidClickUndo;
- (void)toolbarDidClickRedo;
- (void)toolbarDidClickCancel;
- (void)toolbarDidClickSave;
- (void)toolbarDidClickDone;
@end

@interface AnnotationToolbarView : NSVisualEffectView

@property (nonatomic, weak) id<AnnotationToolbarDelegate> delegate;
@property (nonatomic, assign) AnnotationType selectedTool;
@property (nonatomic, strong) NSColor *selectedColor;
@property (nonatomic, assign) CGFloat selectedStrokeWidth;
@property (nonatomic, assign) BOOL canUndo;
@property (nonatomic, assign) BOOL canRedo;

- (void)updateButtonStates;

@end

NS_ASSUME_NONNULL_END
