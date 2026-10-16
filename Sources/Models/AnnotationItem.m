#import "AnnotationItem.h"
#import <CoreImage/CoreImage.h>

@implementation AnnotationItem

- (instancetype)initWithType:(AnnotationType)type {
    self = [super init];
    if (self) {
        _type = type;
        _strokeColor = [NSColor redColor];
        _strokeWidth = 3.0;
        _penPoints = [NSMutableArray array];
        _badgeNumber = 1;
        _text = @"";
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    AnnotationItem *copy = [[[self class] allocWithZone:zone] initWithType:self.type];
    copy.startPoint = self.startPoint;
    copy.endPoint = self.endPoint;
    copy.strokeColor = self.strokeColor;
    copy.strokeWidth = self.strokeWidth;
    copy.text = [self.text copy];
    copy.badgeNumber = self.badgeNumber;
    copy.baseImageForMosaic = self.baseImageForMosaic;
    for (NSValue *val in self.penPoints) {
        [copy.penPoints addObject:val];
    }
    return copy;
}

- (CGRect)normalizedRect {
    CGFloat x = MIN(_startPoint.x, _endPoint.x);
    CGFloat y = MIN(_startPoint.y, _endPoint.y);
    CGFloat w = fabs(_endPoint.x - _startPoint.x);
    CGFloat h = fabs(_endPoint.y - _startPoint.y);
    return CGRectMake(x, y, MAX(w, 1.0), MAX(h, 1.0));
}

- (void)drawInContext:(CGContextRef)ctx selectionRect:(NSRect)selectionRect {
    if (!ctx) return;
    
    CGContextSaveGState(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, _strokeColor.CGColor);
    CGContextSetFillColorWithColor(ctx, _strokeColor.CGColor);
    CGContextSetLineWidth(ctx, _strokeWidth);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    switch (_type) {
        case AnnotationTypeRect: {
            CGRect r = [self normalizedRect];
            CGContextStrokeRectWithWidth(ctx, r, _strokeWidth);
            break;
        }
            
        case AnnotationTypeOval: {
            CGRect r = [self normalizedRect];
            CGContextStrokeEllipseInRect(ctx, r);
            break;
        }
            
        case AnnotationTypeLine: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, _startPoint.x, _startPoint.y);
            CGContextAddLineToPoint(ctx, _endPoint.x, _endPoint.y);
            CGContextStrokePath(ctx);
            break;
        }
            
        case AnnotationTypeArrow: {
            [self drawArrowInContext:ctx];
            break;
        }
            
        case AnnotationTypePen: {
            if (_penPoints.count > 1) {
                CGContextBeginPath(ctx);
                NSPoint first = [_penPoints.firstObject pointValue];
                CGContextMoveToPoint(ctx, first.x, first.y);
                for (NSUInteger i = 1; i < _penPoints.count; i++) {
                    NSPoint pt = [_penPoints[i] pointValue];
                    CGContextAddLineToPoint(ctx, pt.x, pt.y);
                }
                CGContextStrokePath(ctx);
            }
            break;
        }
            
        case AnnotationTypeStepBadge: {
            CGFloat radius = MAX(14.0, _strokeWidth * 4.0);
            CGPoint center = _startPoint;
            CGRect circleRect = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);
            
            // Outer subtle shadow
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 3.0, [NSColor colorWithWhite:0 alpha:0.4].CGColor);
            
            // Fill circle
            CGContextFillEllipseInRect(ctx, circleRect);
            
            // White border
            CGContextSetStrokeColorWithColor(ctx, [NSColor whiteColor].CGColor);
            CGContextSetLineWidth(ctx, 2.0);
            CGContextStrokeEllipseInRect(ctx, circleRect);
            
            // Clear shadow for text
            CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
            
            // Draw number text
            NSString *numStr = [NSString stringWithFormat:@"%ld", (long)_badgeNumber];
            NSDictionary *attrs = @{
                NSFontAttributeName: [NSFont boldSystemFontOfSize:radius * 1.1],
                NSForegroundColorAttributeName: [NSColor whiteColor]
            };
            NSSize strSize = [numStr sizeWithAttributes:attrs];
            NSPoint textOrigin = NSMakePoint(center.x - strSize.width / 2.0, center.y - strSize.height / 2.0);
            
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO]];
            [numStr drawAtPoint:textOrigin withAttributes:attrs];
            [NSGraphicsContext restoreGraphicsState];
            break;
        }
            
        case AnnotationTypeText: {
            if (_text.length > 0) {
                CGFloat fontSize = MAX(14.0, _strokeWidth * 4.5);
                NSDictionary *attrs = @{
                    NSFontAttributeName: [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium],
                    NSForegroundColorAttributeName: _strokeColor
                };
                
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO]];
                [_text drawAtPoint:_startPoint withAttributes:attrs];
                [NSGraphicsContext restoreGraphicsState];
            }
            break;
        }
            
        case AnnotationTypeMosaic: {
            CGRect r = [self normalizedRect];
            [self drawMosaicInRect:r context:ctx];
            break;
        }
            
        default:
            break;
    }
    
    CGContextRestoreGState(ctx);
}

- (void)drawArrowInContext:(CGContextRef)ctx {
    CGFloat dx = _endPoint.x - _startPoint.x;
    CGFloat dy = _endPoint.y - _startPoint.y;
    CGFloat length = sqrt(dx * dx + dy * dy);
    if (length < 2.0) return;
    
    CGFloat angle = atan2(dy, dx);
    CGFloat arrowHeadLength = MAX(16.0, _strokeWidth * 3.5);
    CGFloat arrowHeadAngle = M_PI / 6.0; // 30 degrees
    
    // Draw shaft
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, _startPoint.x, _startPoint.y);
    CGContextAddLineToPoint(ctx, _endPoint.x, _endPoint.y);
    CGContextStrokePath(ctx);
    
    // Draw arrowhead polygon
    CGPoint p1 = CGPointMake(_endPoint.x - arrowHeadLength * cos(angle - arrowHeadAngle),
                             _endPoint.y - arrowHeadLength * sin(angle - arrowHeadAngle));
    CGPoint p2 = CGPointMake(_endPoint.x - arrowHeadLength * cos(angle + arrowHeadAngle),
                             _endPoint.y - arrowHeadLength * sin(angle + arrowHeadAngle));
    
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, _endPoint.x, _endPoint.y);
    CGContextAddLineToPoint(ctx, p1.x, p1.y);
    CGContextAddLineToPoint(ctx, p2.x, p2.y);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
}

- (void)drawMosaicInRect:(CGRect)rect context:(CGContextRef)ctx {
    // If base image is available, draw pixelated blocks
    CGFloat blockSize = MAX(8.0, _strokeWidth * 2.5);
    
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, rect);
    
    // Create mosaic pattern
    for (CGFloat x = rect.origin.x; x < CGRectGetMaxX(rect); x += blockSize) {
        for (CGFloat y = rect.origin.y; y < CGRectGetMaxY(rect); y += blockSize) {
            CGRect block = CGRectMake(x, y, blockSize, blockSize);
            // Alternate subtle tint to give pixelated censor look
            int hash = ((int)(x / blockSize) * 17) ^ ((int)(y / blockSize) * 31);
            CGFloat shade = 0.45 + (hash % 10) * 0.03;
            CGContextSetFillColorWithColor(ctx, [NSColor colorWithWhite:shade alpha:0.85].CGColor);
            CGContextFillRect(ctx, block);
            
            CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithWhite:shade * 0.9 alpha:0.5].CGColor);
            CGContextSetLineWidth(ctx, 0.5);
            CGContextStrokeRect(ctx, block);
        }
    }
    
    CGContextRestoreGState(ctx);
}

@end
