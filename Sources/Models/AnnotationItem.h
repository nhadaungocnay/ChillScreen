#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AnnotationType) {
    AnnotationTypeNone = 0,
    AnnotationTypeRect,
    AnnotationTypeOval,
    AnnotationTypeArrow,
    AnnotationTypeLine,
    AnnotationTypePen,
    AnnotationTypeText,
    AnnotationTypeMosaic,
    AnnotationTypeStepBadge
};

@interface AnnotationItem : NSObject <NSCopying>

@property (nonatomic, assign) AnnotationType type;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) CGPoint endPoint;
@property (nonatomic, strong) NSMutableArray<NSValue *> *penPoints; // array of NSPoint
@property (nonatomic, strong) NSColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, assign) NSInteger badgeNumber;
@property (nonatomic, strong) NSImage *baseImageForMosaic; // cropped section if mosaic

- (instancetype)initWithType:(AnnotationType)type;
- (void)drawInContext:(CGContextRef)ctx selectionRect:(NSRect)selectionRect;

@end

NS_ASSUME_NONNULL_END
