#import "AnnotationToolbarView.h"

@interface ColorSwatchButton : NSButton
@property (nonatomic, strong) NSColor *swatchColor;
@property (nonatomic, assign) BOOL isSwatchSelected;
@end

@implementation ColorSwatchButton

- (instancetype)initWithColor:(NSColor *)color {
    self = [super initWithFrame:NSMakeRect(0, 0, 24, 24)];
    if (self) {
        _swatchColor = color;
        _isSwatchSelected = NO;
        self.bezelStyle = NSBezelStyleRegularSquare;
        self.bordered = NO;
        self.title = @"";
        self.wantsLayer = YES;
        [self.widthAnchor constraintEqualToConstant:24].active = YES;
        [self.heightAnchor constraintEqualToConstant:24].active = YES;
    }
    return self;
}

- (void)setIsSwatchSelected:(BOOL)isSwatchSelected {
    if (_isSwatchSelected != isSwatchSelected) {
        _isSwatchSelected = isSwatchSelected;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    if (!ctx) return;
    
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    
    // Check luminance of the color
    CGFloat r = 0, g = 0, b = 0, a = 1.0;
    NSColor *rgb = [_swatchColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgb) {
        [rgb getRed:&r green:&g blue:&b alpha:&a];
    } else {
        r = 1.0; g = 1.0; b = 1.0;
    }
    CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    BOOL isLightColor = (luminance > 0.75);
    
    // 1. Draw outer selection ring if selected
    if (_isSwatchSelected) {
        CGRect ringRect = CGRectInset(NSRectToCGRect(self.bounds), 1.5, 1.5);
        if (isLightColor) {
            // For white or light yellow, use vivid Blue ring for high contrast
            CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0].CGColor);
        } else {
            // For darker colors, use crisp white ring
            CGContextSetStrokeColorWithColor(ctx, [NSColor whiteColor].CGColor);
        }
        CGContextSetLineWidth(ctx, 2.0);
        CGContextStrokeEllipseInRect(ctx, ringRect);
    }
    
    // 2. Inner Color Circle
    CGFloat circleSize = _isSwatchSelected ? 15.0 : 17.0;
    CGRect circleRect = CGRectMake((w - circleSize) / 2.0, (h - circleSize) / 2.0, circleSize, circleSize);
    
    // Subtle drop shadow so light and dark swatches stand out
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, -0.5), 1.5, [NSColor colorWithWhite:0.0 alpha:0.35].CGColor);
    CGContextSetFillColorWithColor(ctx, _swatchColor.CGColor);
    CGContextFillEllipseInRect(ctx, circleRect);
    CGContextRestoreGState(ctx);
    
    // 3. Crisp stroke on the color circle edge
    if (isLightColor) {
        // High-contrast clean dark-grey border (prevents blurry / washed-out look for white!)
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithWhite:0.15 alpha:0.6].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(circleRect, 0.5, 0.5));
    } else {
        // Subtle white border for dark colors
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithWhite:1.0 alpha:0.25].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(circleRect, 0.5, 0.5));
    }
}

@end

@interface AnnotationToolbarView ()

@property (nonatomic, strong) NSStackView *mainStack;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSButton *> *toolButtons;
@property (nonatomic, strong) NSMutableArray<ColorSwatchButton *> *colorButtons;
@property (nonatomic, strong) NSMutableArray<NSButton *> *widthButtons;
@property (nonatomic, strong) NSButton *undoButton;
@property (nonatomic, strong) NSButton *redoButton;

@end

@implementation AnnotationToolbarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.material = NSVisualEffectMaterialHUDWindow;
        self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        self.state = NSVisualEffectStateActive;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.18].CGColor;
        
        _toolButtons = [NSMutableDictionary dictionary];
        _colorButtons = [NSMutableArray array];
        _widthButtons = [NSMutableArray array];
        
        _selectedTool = AnnotationTypeNone;
        _selectedColor = [NSColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0]; // System Red
        _selectedStrokeWidth = 3.0;
        
        [self setupUI];
    }
    return self;
}

- (NSButton *)createIconButtonWithSymbol:(NSString *)symbolName fallback:(NSString *)fallback tag:(NSInteger)tag tooltip:(NSString *)tip {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 28, 28)];
    btn.bezelStyle = NSBezelStyleRegularSquare;
    btn.bordered = NO;
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 6.0;
    btn.toolTip = tip;
    btn.tag = tag;
    
    NSImage *img = nil;
    if (@available(macOS 11.0, *)) {
        img = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:tip];
    }
    if (img) {
        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
        btn.image = [img imageWithSymbolConfiguration:config];
        btn.imageScaling = NSImageScaleProportionallyDown;
    } else {
        btn.title = fallback;
        btn.font = [NSFont boldSystemFontOfSize:14];
    }
    btn.contentTintColor = [NSColor whiteColor];
    
    [btn.widthAnchor constraintEqualToConstant:28].active = YES;
    [btn.heightAnchor constraintEqualToConstant:28].active = YES;
    return btn;
}

- (NSView *)createSeparator {
    NSBox *sep = [[NSBox alloc] init];
    sep.boxType = NSBoxSeparator;
    [sep.widthAnchor constraintEqualToConstant:1].active = YES;
    [sep.heightAnchor constraintEqualToConstant:20].active = YES;
    return sep;
}

- (void)setupUI {
    _mainStack = [[NSStackView alloc] initWithFrame:self.bounds];
    _mainStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    _mainStack.alignment = NSLayoutAttributeCenterY;
    _mainStack.spacing = 4.0;
    _mainStack.edgeInsets = NSEdgeInsetsMake(4, 8, 4, 8);
    _mainStack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:_mainStack];
    
    // Tools
    NSArray *toolsDef = @[
        @{@"type": @(AnnotationTypeRect), @"sym": @"rectangle", @"fb": @"□", @"tip": @"Hình chữ nhật (Rectangle)"},
        @{@"type": @(AnnotationTypeOval), @"sym": @"circle", @"fb": @"○", @"tip": @"Hình tròn (Circle)"},
        @{@"type": @(AnnotationTypeArrow), @"sym": @"arrow.up.right", @"fb": @"➔", @"tip": @"Mũi tên (Arrow)"},
        @{@"type": @(AnnotationTypeLine), @"sym": @"line.diagonal", @"fb": @"╱", @"tip": @"Đường thẳng (Line)"},
        @{@"type": @(AnnotationTypePen), @"sym": @"pencil.tip", @"fb": @"✎", @"tip": @"Bút vẽ tự do (Pen)"},
        @{@"type": @(AnnotationTypeText), @"sym": @"textformat", @"fb": @"T", @"tip": @"Chèn chữ (Text)"},
        @{@"type": @(AnnotationTypeMosaic), @"sym": @"square.grid.3x3.fill", @"fb": @"▦", @"tip": @"Làm mờ / Mosaic"},
        @{@"type": @(AnnotationTypeStepBadge), @"sym": @"number.circle", @"fb": @"①", @"tip": @"Đánh số bước (1, 2, 3...)"}
    ];
    
    for (NSDictionary *t in toolsDef) {
        AnnotationType atype = [t[@"type"] integerValue];
        NSButton *btn = [self createIconButtonWithSymbol:t[@"sym"] fallback:t[@"fb"] tag:atype tooltip:t[@"tip"]];
        btn.target = self;
        btn.action = @selector(toolButtonClicked:);
        _toolButtons[@(atype)] = btn;
        [_mainStack addArrangedSubview:btn];
    }
    
    [_mainStack addArrangedSubview:[self createSeparator]];
    
    // Colors
    NSArray<NSColor *> *palette = @[
        [NSColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0], // Red
        [NSColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0],  // Orange
        [NSColor colorWithRed:1.0 green:0.80 blue:0.0 alpha:1.0],  // Yellow
        [NSColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0],// Green
        [NSColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0],  // Blue
        [NSColor colorWithRed:0.69 green:0.32 blue:0.87 alpha:1.0],// Purple
        [NSColor colorWithWhite:1.0 alpha:1.0],                     // Pure White
        [NSColor colorWithWhite:0.12 alpha:1.0]                    // Black
    ];
    
    for (NSColor *c in palette) {
        ColorSwatchButton *cBtn = [[ColorSwatchButton alloc] initWithColor:c];
        cBtn.target = self;
        cBtn.action = @selector(colorButtonClicked:);
        [_colorButtons addObject:cBtn];
        [_mainStack addArrangedSubview:cBtn];
    }
    
    [_mainStack addArrangedSubview:[self createSeparator]];
    
    // Stroke Widths (Thin: 2, Med: 4, Thick: 6)
    NSArray *widths = @[@2.0, @4.0, @6.0];
    for (NSNumber *w in widths) {
        CGFloat val = [w doubleValue];
        NSButton *wBtn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 22, 22)];
        wBtn.bezelStyle = NSBezelStyleRegularSquare;
        wBtn.bordered = NO;
        wBtn.title = @"";
        wBtn.wantsLayer = YES;
        wBtn.layer.cornerRadius = 11.0;
        wBtn.tag = (NSInteger)val;
        wBtn.target = self;
        wBtn.action = @selector(widthButtonClicked:);
        
        // Inner circle indicator
        CALayer *dot = [CALayer layer];
        dot.backgroundColor = [NSColor whiteColor].CGColor;
        dot.cornerRadius = val / 2.0;
        dot.bounds = CGRectMake(0, 0, val, val);
        dot.position = CGPointMake(11, 11);
        [wBtn.layer addSublayer:dot];
        
        [wBtn.widthAnchor constraintEqualToConstant:22].active = YES;
        [wBtn.heightAnchor constraintEqualToConstant:22].active = YES;
        [_widthButtons addObject:wBtn];
        [_mainStack addArrangedSubview:wBtn];
    }
    
    [_mainStack addArrangedSubview:[self createSeparator]];
    
    // Undo / Redo
    _undoButton = [self createIconButtonWithSymbol:@"arrow.uturn.backward" fallback:@"↩" tag:101 tooltip:@"Hoàn tác (Undo - ⌘Z)"];
    _undoButton.target = self;
    _undoButton.action = @selector(undoClicked:);
    [_mainStack addArrangedSubview:_undoButton];
    
    _redoButton = [self createIconButtonWithSymbol:@"arrow.uturn.forward" fallback:@"↪" tag:102 tooltip:@"Làm lại (Redo - ⇧⌘Z)"];
    _redoButton.target = self;
    _redoButton.action = @selector(redoClicked:);
    [_mainStack addArrangedSubview:_redoButton];
    
    [_mainStack addArrangedSubview:[self createSeparator]];
    
    // Actions: Cancel, Save, Copy
    NSButton *cancelBtn = [self createIconButtonWithSymbol:@"xmark" fallback:@"✕" tag:201 tooltip:@"Huỷ chụp (Esc)"];
    cancelBtn.target = self;
    cancelBtn.action = @selector(cancelClicked:);
    [_mainStack addArrangedSubview:cancelBtn];
    
    NSButton *saveBtn = [self createIconButtonWithSymbol:@"square.and.arrow.down" fallback:@"💾" tag:202 tooltip:@"Lưu file ảnh (⌘S)"];
    saveBtn.target = self;
    saveBtn.action = @selector(saveClicked:);
    [_mainStack addArrangedSubview:saveBtn];
    
    NSButton *doneBtn = [self createIconButtonWithSymbol:@"checkmark" fallback:@"✓" tag:203 tooltip:@"Sao chép & Hoàn thành (Enter / ⌘C)"];
    doneBtn.target = self;
    doneBtn.action = @selector(doneClicked:);
    doneBtn.layer.backgroundColor = [NSColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:0.9].CGColor;
    doneBtn.contentTintColor = [NSColor whiteColor];
    [_mainStack addArrangedSubview:doneBtn];
    
    [self updateButtonStates];
}

- (void)updateButtonStates {
    // Tool selection highlight
    for (NSNumber *key in _toolButtons) {
        NSButton *btn = _toolButtons[key];
        BOOL isSel = (btn.tag == _selectedTool);
        btn.layer.backgroundColor = isSel ? [NSColor colorWithWhite:1.0 alpha:0.25].CGColor : [NSColor clearColor].CGColor;
    }
    
    // Color selection highlight
    for (ColorSwatchButton *cBtn in _colorButtons) {
        BOOL isSel = NO;
        if (cBtn.swatchColor == _selectedColor) {
            isSel = YES;
        } else {
            NSColor *c1 = [cBtn.swatchColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            NSColor *c2 = [_selectedColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            if (c1 && c2) {
                CGFloat diff = fabs(c1.redComponent - c2.redComponent) +
                               fabs(c1.greenComponent - c2.greenComponent) +
                               fabs(c1.blueComponent - c2.blueComponent);
                isSel = (diff < 0.05);
            }
        }
        cBtn.isSwatchSelected = isSel;
    }
    
    // Width selection highlight
    for (NSButton *wBtn in _widthButtons) {
        BOOL isSel = (wBtn.tag == (NSInteger)_selectedStrokeWidth);
        wBtn.layer.backgroundColor = isSel ? [NSColor colorWithWhite:1.0 alpha:0.3].CGColor : [NSColor clearColor].CGColor;
    }
    
    _undoButton.enabled = _canUndo;
    _undoButton.alphaValue = _canUndo ? 1.0 : 0.4;
    _redoButton.enabled = _canRedo;
    _redoButton.alphaValue = _canRedo ? 1.0 : 0.4;
}

- (void)toolButtonClicked:(NSButton *)sender {
    AnnotationType clickedType = (AnnotationType)sender.tag;
    if (_selectedTool == clickedType) {
        _selectedTool = AnnotationTypeNone; // toggle off
    } else {
        _selectedTool = clickedType;
    }
    [self updateButtonStates];
    if ([self.delegate respondsToSelector:@selector(toolbarDidSelectTool:)]) {
        [self.delegate toolbarDidSelectTool:_selectedTool];
    }
}

- (void)colorButtonClicked:(ColorSwatchButton *)sender {
    _selectedColor = sender.swatchColor;
    [self updateButtonStates];
    if ([self.delegate respondsToSelector:@selector(toolbarDidSelectColor:)]) {
        [self.delegate toolbarDidSelectColor:_selectedColor];
    }
}

- (void)widthButtonClicked:(NSButton *)sender {
    _selectedStrokeWidth = (CGFloat)sender.tag;
    [self updateButtonStates];
    if ([self.delegate respondsToSelector:@selector(toolbarDidSelectStrokeWidth:)]) {
        [self.delegate toolbarDidSelectStrokeWidth:_selectedStrokeWidth];
    }
}

- (void)undoClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(toolbarDidClickUndo)]) {
        [self.delegate toolbarDidClickUndo];
    }
}

- (void)redoClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(toolbarDidClickRedo)]) {
        [self.delegate toolbarDidClickRedo];
    }
}

- (void)cancelClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(toolbarDidClickCancel)]) {
        [self.delegate toolbarDidClickCancel];
    }
}

- (void)saveClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(toolbarDidClickSave)]) {
        [self.delegate toolbarDidClickSave];
    }
}

- (void)doneClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(toolbarDidClickDone)]) {
        [self.delegate toolbarDidClickDone];
    }
}

@end
