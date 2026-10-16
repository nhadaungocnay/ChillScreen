#import "CaptureOverlayView.h"
#import "../ScreenCaptureManager.h"
#import "../SettingsManager.h"

typedef NS_ENUM(NSInteger, DragHandle) {
    DragHandleNone = 0,
    DragHandleInside,
    DragHandleTopLeft,
    DragHandleTopCenter,
    DragHandleTopRight,
    DragHandleMiddleLeft,
    DragHandleMiddleRight,
    DragHandleBottomLeft,
    DragHandleBottomCenter,
    DragHandleBottomRight
};

typedef NS_ENUM(NSInteger, OverlayMode) {
    OverlayModeIdle = 0,
    OverlayModeSelecting,
    OverlayModeSelected,
    OverlayModeResizing,
    OverlayModeMoving,
    OverlayModeAnnotating
};

static const CGFloat kHandleSize = 8.0;

@interface CaptureOverlayView () {
    CGPoint _dragStartPoint;
    NSRect _initialSelectionRect;
    DragHandle _activeHandle;
    OverlayMode _mode;
    
    CGPoint _currentMouseLocation;
    BOOL _isMouseInside;
    
    NSInteger _nextBadgeNumber;
}

@property (nonatomic, strong) AnnotationToolbarView *toolbar;
@property (nonatomic, strong) NSMutableArray<AnnotationItem *> *annotations;
@property (nonatomic, strong) NSMutableArray<NSArray<AnnotationItem *> *> *undoStack;
@property (nonatomic, strong) NSMutableArray<NSArray<AnnotationItem *> *> *redoStack;
@property (nonatomic, strong, nullable) AnnotationItem *currentActiveAnnotation;
@property (nonatomic, strong, nullable) NSTextField *activeTextField;
@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation CaptureOverlayView

- (instancetype)initWithFrame:(NSRect)frame backgroundImage:(NSImage *)bgImage screenScale:(CGFloat)scale {
    self = [super initWithFrame:frame];
    if (self) {
        _backgroundImage = bgImage;
        _screenScale = scale > 0 ? scale : 2.0;
        _selectionRect = NSZeroRect;
        _mode = OverlayModeIdle;
        _nextBadgeNumber = 1;
        
        _annotations = [NSMutableArray array];
        _undoStack = [NSMutableArray array];
        _redoStack = [NSMutableArray array];
        
        self.wantsLayer = YES;
        
        [self setupToolbar];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    NSTrackingAreaOptions options = NSTrackingActiveAlways | NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)setupToolbar {
    _toolbar = [[AnnotationToolbarView alloc] initWithFrame:NSMakeRect(0, 0, 750, 44)];
    _toolbar.delegate = self;
    _toolbar.hidden = YES;
    [self addSubview:_toolbar];
}

- (void)saveStateForUndo {
    NSMutableArray *snapshot = [NSMutableArray arrayWithCapacity:_annotations.count];
    for (AnnotationItem *item in _annotations) {
        [snapshot addObject:[item copy]];
    }
    [_undoStack addObject:snapshot];
    [_redoStack removeAllObjects];
    [self updateToolbarState];
}

- (void)updateToolbarState {
    _toolbar.canUndo = (_undoStack.count > 0 || _annotations.count > 0);
    _toolbar.canRedo = (_redoStack.count > 0);
    [_toolbar updateButtonStates];
}

#pragma mark - Geometry & Handles

- (NSRect)normalizedRectFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2 {
    CGFloat x = MIN(p1.x, p2.x);
    CGFloat y = MIN(p1.y, p2.y);
    CGFloat w = fabs(p2.x - p1.x);
    CGFloat h = fabs(p2.y - p1.y);
    return NSIntersectionRect(NSMakeRect(x, y, w, h), self.bounds);
}

- (NSRect)rectForHandle:(DragHandle)handle {
    if (NSIsEmptyRect(_selectionRect)) return NSZeroRect;
    
    CGFloat hs = kHandleSize;
    CGFloat half = hs / 2.0;
    CGFloat minX = NSMinX(_selectionRect);
    CGFloat midX = NSMidX(_selectionRect);
    CGFloat maxX = NSMaxX(_selectionRect);
    CGFloat minY = NSMinY(_selectionRect);
    CGFloat midY = NSMidY(_selectionRect);
    CGFloat maxY = NSMaxY(_selectionRect);
    
    switch (handle) {
        case DragHandleTopLeft: return NSMakeRect(minX - half, maxY - half, hs, hs);
        case DragHandleTopCenter: return NSMakeRect(midX - half, maxY - half, hs, hs);
        case DragHandleTopRight: return NSMakeRect(maxX - half, maxY - half, hs, hs);
        case DragHandleMiddleLeft: return NSMakeRect(minX - half, midY - half, hs, hs);
        case DragHandleMiddleRight: return NSMakeRect(maxX - half, midY - half, hs, hs);
        case DragHandleBottomLeft: return NSMakeRect(minX - half, minY - half, hs, hs);
        case DragHandleBottomCenter: return NSMakeRect(midX - half, minY - half, hs, hs);
        case DragHandleBottomRight: return NSMakeRect(maxX - half, minY - half, hs, hs);
        default: return NSZeroRect;
    }
}

- (DragHandle)handleAtPoint:(CGPoint)pt {
    if (NSIsEmptyRect(_selectionRect)) return DragHandleNone;
    
    for (NSInteger h = DragHandleTopLeft; h <= DragHandleBottomRight; h++) {
        NSRect hr = [self rectForHandle:(DragHandle)h];
        if (NSPointInRect(pt, NSInsetRect(hr, -4, -4))) {
            return (DragHandle)h;
        }
    }
    
    if (NSPointInRect(pt, _selectionRect)) {
        return DragHandleInside;
    }
    
    return DragHandleNone;
}

- (void)updateCursorForPoint:(CGPoint)pt {
    if (_mode == OverlayModeIdle || _mode == OverlayModeSelecting) {
        [[NSCursor crosshairCursor] set];
        return;
    }
    
    if (_toolbar.selectedTool != AnnotationTypeNone && NSPointInRect(pt, _selectionRect)) {
        [[NSCursor crosshairCursor] set];
        return;
    }
    
    DragHandle handle = [self handleAtPoint:pt];
    switch (handle) {
        case DragHandleTopLeft:
        case DragHandleBottomRight:
            [[NSCursor crosshairCursor] set];
            break;
        case DragHandleTopRight:
        case DragHandleBottomLeft:
            [[NSCursor crosshairCursor] set];
            break;
        case DragHandleTopCenter:
        case DragHandleBottomCenter:
            [[NSCursor resizeUpDownCursor] set];
            break;
        case DragHandleMiddleLeft:
        case DragHandleMiddleRight:
            [[NSCursor resizeLeftRightCursor] set];
            break;
        case DragHandleInside:
            [[NSCursor openHandCursor] set];
            break;
        default:
            [[NSCursor arrowCursor] set];
            break;
    }
}

- (void)layoutToolbar {
    if (NSIsEmptyRect(_selectionRect)) {
        _toolbar.hidden = YES;
        return;
    }
    
    _toolbar.hidden = NO;
    NSSize tbSize = _toolbar.frame.size;
    
    CGFloat x = NSMidX(_selectionRect) - tbSize.width / 2.0;
    x = MAX(10, MIN(x, self.bounds.size.width - tbSize.width - 10));
    
    CGFloat y = NSMinY(_selectionRect) - tbSize.height - 10;
    // If too close to bottom, show above selection
    if (y < 10) {
        y = NSMaxY(_selectionRect) + 10;
    }
    // If still off screen, clamp
    y = MAX(10, MIN(y, self.bounds.size.height - tbSize.height - 10));
    
    _toolbar.frame = NSMakeRect(x, y, tbSize.width, tbSize.height);
}

#pragma mark - Mouse Events

- (void)mouseEntered:(NSEvent *)event {
    _isMouseInside = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    _isMouseInside = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event {
    _currentMouseLocation = [self convertPoint:event.locationInWindow fromView:nil];
    [self updateCursorForPoint:_currentMouseLocation];
    if ([SettingsManager sharedManager].showMagnifier && _mode == OverlayModeIdle) {
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)event {
    [self commitActiveText];
    
    CGPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    _dragStartPoint = pt;
    _initialSelectionRect = _selectionRect;
    
    // Check if clicked inside toolbar
    if (!_toolbar.hidden && NSPointInRect(pt, _toolbar.frame)) {
        [super mouseDown:event];
        return;
    }
    
    // If no selection exists yet, start selecting
    if (NSIsEmptyRect(_selectionRect)) {
        _mode = OverlayModeSelecting;
        _selectionRect = NSMakeRect(pt.x, pt.y, 0, 0);
        _toolbar.hidden = YES;
        [self setNeedsDisplay:YES];
        return;
    }
    
    // Check if an annotation tool is active and clicked inside selection
    if (_toolbar.selectedTool != AnnotationTypeNone && NSPointInRect(pt, _selectionRect)) {
        _mode = OverlayModeAnnotating;
        [self startAnnotationAtPoint:pt];
        return;
    }
    
    // Handle resizing or moving
    DragHandle handle = [self handleAtPoint:pt];
    _activeHandle = handle;
    
    if (handle == DragHandleInside) {
        _mode = OverlayModeMoving;
        [[NSCursor closedHandCursor] set];
    } else if (handle != DragHandleNone) {
        _mode = OverlayModeResizing;
    } else {
        // Clicked outside existing selection: start a fresh selection
        _mode = OverlayModeSelecting;
        _selectionRect = NSMakeRect(pt.x, pt.y, 0, 0);
        _toolbar.hidden = YES;
    }
    
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    CGPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    _currentMouseLocation = pt;
    
    if (_mode == OverlayModeSelecting) {
        _selectionRect = [self normalizedRectFromPoint:_dragStartPoint toPoint:pt];
        [self setNeedsDisplay:YES];
    } else if (_mode == OverlayModeMoving) {
        CGFloat dx = pt.x - _dragStartPoint.x;
        CGFloat dy = pt.y - _dragStartPoint.y;
        NSRect r = NSOffsetRect(_initialSelectionRect, dx, dy);
        
        // Clamp to screen bounds
        if (NSMinX(r) < 0) r.origin.x = 0;
        if (NSMinY(r) < 0) r.origin.y = 0;
        if (NSMaxX(r) > self.bounds.size.width) r.origin.x = self.bounds.size.width - r.size.width;
        if (NSMaxY(r) > self.bounds.size.height) r.origin.y = self.bounds.size.height - r.size.height;
        
        _selectionRect = r;
        [self layoutToolbar];
        [self setNeedsDisplay:YES];
    } else if (_mode == OverlayModeResizing) {
        [self handleResizeWithPoint:pt];
        [self layoutToolbar];
        [self setNeedsDisplay:YES];
    } else if (_mode == OverlayModeAnnotating && _currentActiveAnnotation) {
        [self updateActiveAnnotationWithPoint:pt];
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseUp:(NSEvent *)event {
    CGPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    
    if (_mode == OverlayModeSelecting) {
        if (_selectionRect.size.width < 10 || _selectionRect.size.height < 10) {
            _selectionRect = NSZeroRect;
            _mode = OverlayModeIdle;
        } else {
            _mode = OverlayModeSelected;
            [self layoutToolbar];
        }
    } else if (_mode == OverlayModeMoving || _mode == OverlayModeResizing) {
        _mode = OverlayModeSelected;
        [self layoutToolbar];
    } else if (_mode == OverlayModeAnnotating && _currentActiveAnnotation) {
        [self finishActiveAnnotationWithPoint:pt];
        _mode = OverlayModeSelected;
    }
    
    _activeHandle = DragHandleNone;
    [self updateCursorForPoint:pt];
    [self setNeedsDisplay:YES];
}

- (void)handleResizeWithPoint:(CGPoint)pt {
    NSRect r = _initialSelectionRect;
    CGFloat minW = 20.0;
    CGFloat minH = 20.0;
    
    switch (_activeHandle) {
        case DragHandleTopLeft: {
            CGFloat newMaxX = NSMaxX(r);
            CGFloat newMinX = MIN(pt.x, newMaxX - minW);
            CGFloat newMinY = NSMinY(r);
            CGFloat newMaxY = MAX(pt.y, newMinY + minH);
            _selectionRect = NSMakeRect(newMinX, newMinY, newMaxX - newMinX, newMaxY - newMinY);
            break;
        }
        case DragHandleTopCenter: {
            CGFloat newMinY = NSMinY(r);
            CGFloat newMaxY = MAX(pt.y, newMinY + minH);
            _selectionRect = NSMakeRect(r.origin.x, newMinY, r.size.width, newMaxY - newMinY);
            break;
        }
        case DragHandleTopRight: {
            CGFloat newMinX = NSMinX(r);
            CGFloat newMaxX = MAX(pt.x, newMinX + minW);
            CGFloat newMinY = NSMinY(r);
            CGFloat newMaxY = MAX(pt.y, newMinY + minH);
            _selectionRect = NSMakeRect(newMinX, newMinY, newMaxX - newMinX, newMaxY - newMinY);
            break;
        }
        case DragHandleMiddleLeft: {
            CGFloat newMaxX = NSMaxX(r);
            CGFloat newMinX = MIN(pt.x, newMaxX - minW);
            _selectionRect = NSMakeRect(newMinX, r.origin.y, newMaxX - newMinX, r.size.height);
            break;
        }
        case DragHandleMiddleRight: {
            CGFloat newMinX = NSMinX(r);
            CGFloat newMaxX = MAX(pt.x, newMinX + minW);
            _selectionRect = NSMakeRect(newMinX, r.origin.y, newMaxX - newMinX, r.size.height);
            break;
        }
        case DragHandleBottomLeft: {
            CGFloat newMaxX = NSMaxX(r);
            CGFloat newMinX = MIN(pt.x, newMaxX - minW);
            CGFloat newMaxY = NSMaxY(r);
            CGFloat newMinY = MIN(pt.y, newMaxY - minH);
            _selectionRect = NSMakeRect(newMinX, newMinY, newMaxX - newMinX, newMaxY - newMinY);
            break;
        }
        case DragHandleBottomCenter: {
            CGFloat newMaxY = NSMaxY(r);
            CGFloat newMinY = MIN(pt.y, newMaxY - minH);
            _selectionRect = NSMakeRect(r.origin.x, newMinY, r.size.width, newMaxY - newMinY);
            break;
        }
        case DragHandleBottomRight: {
            CGFloat newMinX = NSMinX(r);
            CGFloat newMaxX = MAX(pt.x, newMinX + minW);
            CGFloat newMaxY = NSMaxY(r);
            CGFloat newMinY = MIN(pt.y, newMaxY - minH);
            _selectionRect = NSMakeRect(newMinX, newMinY, newMaxX - newMinX, newMaxY - newMinY);
            break;
        }
        default:
            break;
    }
    _selectionRect = NSIntersectionRect(_selectionRect, self.bounds);
}

#pragma mark - Annotation Creation

- (void)startAnnotationAtPoint:(CGPoint)pt {
    [self saveStateForUndo];
    
    AnnotationType type = _toolbar.selectedTool;
    AnnotationItem *item = [[AnnotationItem alloc] initWithType:type];
    item.startPoint = pt;
    item.endPoint = pt;
    item.strokeColor = _toolbar.selectedColor;
    item.strokeWidth = _toolbar.selectedStrokeWidth;
    
    if (type == AnnotationTypeStepBadge) {
        item.badgeNumber = _nextBadgeNumber++;
        [_annotations addObject:item];
        _currentActiveAnnotation = nil;
        [self updateToolbarState];
        [self setNeedsDisplay:YES];
        return;
    }
    
    if (type == AnnotationTypeText) {
        [self beginInlineTextAtPoint:pt];
        _currentActiveAnnotation = nil;
        return;
    }
    
    if (type == AnnotationTypePen) {
        [item.penPoints addObject:[NSValue valueWithPoint:pt]];
    }
    
    _currentActiveAnnotation = item;
}

- (void)updateActiveAnnotationWithPoint:(CGPoint)pt {
    // Clamp inside selection
    CGFloat x = MAX(NSMinX(_selectionRect), MIN(pt.x, NSMaxX(_selectionRect)));
    CGFloat y = MAX(NSMinY(_selectionRect), MIN(pt.y, NSMaxY(_selectionRect)));
    CGPoint clamped = CGPointMake(x, y);
    
    _currentActiveAnnotation.endPoint = clamped;
    if (_currentActiveAnnotation.type == AnnotationTypePen) {
        [_currentActiveAnnotation.penPoints addObject:[NSValue valueWithPoint:clamped]];
    }
}

- (void)finishActiveAnnotationWithPoint:(CGPoint)pt {
    [self updateActiveAnnotationWithPoint:pt];
    [_annotations addObject:_currentActiveAnnotation];
    _currentActiveAnnotation = nil;
    [self updateToolbarState];
}

- (void)beginInlineTextAtPoint:(CGPoint)pt {
    CGFloat fontSize = MAX(16.0, _toolbar.selectedStrokeWidth * 4.5);
    _activeTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y - 28, 200, 32)];
    _activeTextField.font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium];
    _activeTextField.textColor = _toolbar.selectedColor;
    _activeTextField.backgroundColor = [NSColor clearColor];
    _activeTextField.bordered = YES;
    _activeTextField.focusRingType = NSFocusRingTypeNone;
    _activeTextField.delegate = self;
    _activeTextField.placeholderString = @"Nhập chữ...";
    [self addSubview:_activeTextField];
    [self.window makeFirstResponder:_activeTextField];
}

- (void)commitActiveText {
    if (_activeTextField) {
        NSString *str = _activeTextField.stringValue;
        if (str.length > 0) {
            AnnotationItem *item = [[AnnotationItem alloc] initWithType:AnnotationTypeText];
            item.startPoint = _activeTextField.frame.origin;
            item.text = str;
            item.strokeColor = _activeTextField.textColor ?: _toolbar.selectedColor;
            item.strokeWidth = _toolbar.selectedStrokeWidth;
            [_annotations addObject:item];
            [self updateToolbarState];
        }
        [_activeTextField removeFromSuperview];
        _activeTextField = nil;
        [self.window makeFirstResponder:self];
        [self setNeedsDisplay:YES];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self commitActiveText];
}

#pragma mark - Keyboard Shortcuts

- (void)keyDown:(NSEvent *)event {
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    
    // Esc: Cancel
    if (event.keyCode == 53) {
        [self toolbarDidClickCancel];
        return;
    }
    
    // Return / Enter: Done & Copy
    if (event.keyCode == 36 || event.keyCode == 76) {
        [self toolbarDidClickDone];
        return;
    }
    
    // Cmd + C: Copy
    if ((flags == NSEventModifierFlagCommand) && [event.charactersIgnoringModifiers isEqualToString:@"c"]) {
        [self toolbarDidClickDone];
        return;
    }
    
    // Cmd + S: Save
    if ((flags == NSEventModifierFlagCommand) && [event.charactersIgnoringModifiers isEqualToString:@"s"]) {
        [self toolbarDidClickSave];
        return;
    }
    
    // Cmd + Z: Undo
    if ((flags == NSEventModifierFlagCommand) && [event.charactersIgnoringModifiers isEqualToString:@"z"]) {
        [self toolbarDidClickUndo];
        return;
    }
    
    // Cmd + Shift + Z: Redo
    if ((flags == (NSEventModifierFlagCommand | NSEventModifierFlagShift)) && [event.charactersIgnoringModifiers isEqualToString:@"z"]) {
        [self toolbarDidClickRedo];
        return;
    }
    
    [super keyDown:event];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    if (!ctx) return;
    
    // 1. Draw full screen frozen background
    if (_backgroundImage) {
        [_backgroundImage drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    }
    
    // 2. Dim outside selection
    CGContextSaveGState(ctx);
    if (!NSIsEmptyRect(_selectionRect)) {
        // Clear selection area
        CGContextSetFillColorWithColor(ctx, [NSColor colorWithWhite:0 alpha:0.45].CGColor);
        
        // Create mask with selection hole
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, self.bounds);
        CGPathAddRect(path, NULL, _selectionRect);
        CGContextAddPath(ctx, path);
        CGContextEOFillPath(ctx);
        CGPathRelease(path);
        
        // 3. Draw annotations clipped inside selection rect
        CGContextClipToRect(ctx, _selectionRect);
        for (AnnotationItem *item in _annotations) {
            [item drawInContext:ctx selectionRect:_selectionRect];
        }
        if (_currentActiveAnnotation) {
            [_currentActiveAnnotation drawInContext:ctx selectionRect:_selectionRect];
        }
        CGContextRestoreGState(ctx);
        
        // 4. Draw selection border & handles
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextStrokeRect(ctx, _selectionRect);
        
        [self drawHandlesInContext:ctx];
        [self drawDimensionBadgeInContext:ctx];
    } else {
        // No selection: subtle overall dim
        CGContextSetFillColorWithColor(ctx, [NSColor colorWithWhite:0 alpha:0.25].CGColor);
        CGContextFillRect(ctx, self.bounds);
        
        // Draw Magnifier Loupe if cursor is moving
        if ([SettingsManager sharedManager].showMagnifier && _isMouseInside && _mode == OverlayModeIdle) {
            [self drawMagnifierLoupeInContext:ctx atPoint:_currentMouseLocation];
        }
    }
}

- (void)drawHandlesInContext:(CGContextRef)ctx {
    for (NSInteger h = DragHandleTopLeft; h <= DragHandleBottomRight; h++) {
        NSRect hr = [self rectForHandle:(DragHandle)h];
        
        CGContextSetFillColorWithColor(ctx, [NSColor whiteColor].CGColor);
        CGContextFillRect(ctx, hr);
        
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        CGContextStrokeRect(ctx, hr);
    }
}

- (void)drawDimensionBadgeInContext:(CGContextRef)ctx {
    NSString *dimStr = [NSString stringWithFormat:@"%d × %d", (int)_selectionRect.size.width, (int)_selectionRect.size.height];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSSize strSize = [dimStr sizeWithAttributes:attrs];
    NSRect badgeRect = NSMakeRect(NSMinX(_selectionRect), NSMaxY(_selectionRect) + 6, strSize.width + 12, 20);
    
    // If top boundary exceeded, put it inside
    if (NSMaxY(badgeRect) > self.bounds.size.height - 4) {
        badgeRect.origin.y = NSMaxY(_selectionRect) - 24;
    }
    
    CGContextSaveGState(ctx);
    CGContextSetFillColorWithColor(ctx, [NSColor colorWithWhite:0 alpha:0.75].CGColor);
    
    NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:4 yRadius:4];
    [bp fill];
    
    [dimStr drawAtPoint:NSMakePoint(badgeRect.origin.x + 6, badgeRect.origin.y + 3) withAttributes:attrs];
    CGContextRestoreGState(ctx);
}

- (void)drawMagnifierLoupeInContext:(CGContextRef)ctx atPoint:(CGPoint)pt {
    CGFloat loupeRadius = 55.0;
    CGFloat loupeDiameter = loupeRadius * 2.0;
    
    // Position loupe offset from cursor
    CGFloat lx = pt.x + 20;
    CGFloat ly = pt.y - loupeDiameter - 10;
    if (lx + loupeDiameter > self.bounds.size.width) lx = pt.x - loupeDiameter - 20;
    if (ly < 10) ly = pt.y + 20;
    
    CGRect loupeRect = CGRectMake(lx, ly, loupeDiameter, loupeDiameter);
    
    CGContextSaveGState(ctx);
    
    // Circular clip
    CGContextAddEllipseInRect(ctx, loupeRect);
    CGContextClip(ctx);
    
    // Draw 4x magnified image
    CGFloat zoom = 4.0;
    CGFloat srcW = loupeDiameter / zoom;
    CGFloat srcH = loupeDiameter / zoom;
    NSRect srcRect = NSMakeRect(pt.x - srcW / 2.0, pt.y - srcH / 2.0, srcW, srcH);
    
    if (_backgroundImage) {
        [_backgroundImage drawInRect:loupeRect fromRect:srcRect operation:NSCompositingOperationCopy fraction:1.0];
    }
    
    // Crosshair in center of loupe
    CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    
    CGPoint center = CGPointMake(CGRectGetMidX(loupeRect), CGRectGetMidY(loupeRect));
    CGContextMoveToPoint(ctx, center.x - 10, center.y);
    CGContextAddLineToPoint(ctx, center.x + 10, center.y);
    CGContextMoveToPoint(ctx, center.x, center.y - 10);
    CGContextAddLineToPoint(ctx, center.x, center.y + 10);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
    
    // Loupe white border & shadow
    CGContextSaveGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, [NSColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.5);
    CGContextStrokeEllipseInRect(ctx, loupeRect);
    CGContextRestoreGState(ctx);
}

#pragma mark - Final Render & Export

- (NSImage *)renderComposedImage {
    if (NSIsEmptyRect(_selectionRect)) return nil;
    
    // Crop base image
    NSImage *cropped = [[ScreenCaptureManager sharedManager] cropImage:_backgroundImage
                                                                toRect:_selectionRect
                                                           screenScale:_screenScale];
    if (!cropped) return nil;
    
    // Draw annotations on top of the cropped image
    NSImage *finalImg = [NSImage imageWithSize:_selectionRect.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [cropped drawInRect:dstRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        
        CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
        // Translate context origin so (0,0) matches selectionRect.origin
        CGContextTranslateCTM(ctx, -self->_selectionRect.origin.x, -self->_selectionRect.origin.y);
        
        for (AnnotationItem *item in self->_annotations) {
            [item drawInContext:ctx selectionRect:self->_selectionRect];
        }
        return YES;
    }];
    
    return finalImg;
}

#pragma mark - AnnotationToolbarDelegate

- (void)toolbarDidSelectTool:(AnnotationType)tool {
    [self commitActiveText];
    [self setNeedsDisplay:YES];
}

- (void)toolbarDidSelectColor:(NSColor *)color {
    // color updated
}

- (void)toolbarDidSelectStrokeWidth:(CGFloat)width {
    // width updated
}

- (void)toolbarDidClickUndo {
    [self commitActiveText];
    if (_annotations.count > 0) {
        [_redoStack addObject:[_annotations copy]];
        if (_undoStack.count > 0) {
            _annotations = [[_undoStack lastObject] mutableCopy];
            [_undoStack removeLastObject];
        } else {
            [_annotations removeAllObjects];
        }
        [self updateToolbarState];
        [self setNeedsDisplay:YES];
    }
}

- (void)toolbarDidClickRedo {
    [self commitActiveText];
    if (_redoStack.count > 0) {
        [_undoStack addObject:[_annotations copy]];
        _annotations = [[_redoStack lastObject] mutableCopy];
        [_redoStack removeLastObject];
        [self updateToolbarState];
        [self setNeedsDisplay:YES];
    }
}

- (void)toolbarDidClickCancel {
    [self closeCapture];
    if ([self.delegate respondsToSelector:@selector(captureOverlayDidCancel:)]) {
        [self.delegate captureOverlayDidCancel:self];
    }
}

- (void)toolbarDidClickSave {
    [self commitActiveText];
    NSImage *finalImage = [self renderComposedImage];
    [self closeCapture];
    if ([self.delegate respondsToSelector:@selector(captureOverlay:didFinishWithImage:shouldSaveToFile:)]) {
        [self.delegate captureOverlay:self didFinishWithImage:finalImage shouldSaveToFile:YES];
    }
}

- (void)toolbarDidClickDone {
    [self commitActiveText];
    NSImage *finalImage = [self renderComposedImage];
    [self closeCapture];
    if ([self.delegate respondsToSelector:@selector(captureOverlay:didFinishWithImage:shouldSaveToFile:)]) {
        [self.delegate captureOverlay:self didFinishWithImage:finalImage shouldSaveToFile:NO];
    }
}

- (void)closeCapture {
    [self.window orderOut:nil];
}

@end
