#import "HotKeyRecorderView.h"
#import "../SettingsManager.h"

@interface HotKeyRecorderView ()
@property (nonatomic, strong) NSTextField *label;
@end

@implementation HotKeyRecorderView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = 6.0;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [NSColor separatorColor].CGColor;
        self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
        
        _label = [[NSTextField alloc] initWithFrame:self.bounds];
        _label.bordered = NO;
        _label.editable = NO;
        _label.selectable = NO;
        _label.alignment = NSTextAlignmentCenter;
        _label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        _label.textColor = [NSColor labelColor];
        _label.backgroundColor = [NSColor clearColor];
        _label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:_label];
        
        _currentKeyCode = kVK_ANSI_A;
        _currentModifiers = (cmdKey | shiftKey);
        [self updateDisplay];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    _isRecording = YES;
    self.layer.borderColor = [NSColor systemBlueColor].CGColor;
    self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.1].CGColor;
    _label.stringValue = @"Bấm tổ hợp phím...";
    _label.textColor = [NSColor systemBlueColor];
    return YES;
}

- (BOOL)resignFirstResponder {
    _isRecording = NO;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    _label.textColor = [NSColor labelColor];
    [self updateDisplay];
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    if (!_isRecording) {
        [self.window makeFirstResponder:self];
    }
}

- (void)keyDown:(NSEvent *)event {
    if (!_isRecording) {
        [super keyDown:event];
        return;
    }
    
    // If Esc is pressed, cancel recording
    if (event.keyCode == 53) {
        [self.window makeFirstResponder:nil];
        return;
    }
    
    NSEventModifierFlags cocoaFlags = event.modifierFlags;
    UInt32 carbonMods = 0;
    if (cocoaFlags & NSEventModifierFlagCommand) carbonMods |= cmdKey;
    if (cocoaFlags & NSEventModifierFlagShift) carbonMods |= shiftKey;
    if (cocoaFlags & NSEventModifierFlagOption) carbonMods |= optionKey;
    if (cocoaFlags & NSEventModifierFlagControl) carbonMods |= controlKey;
    
    // Require at least one modifier key or function key
    if (carbonMods == 0 && event.keyCode < 0x60) {
        NSBeep();
        return;
    }
    
    _currentKeyCode = event.keyCode;
    _currentModifiers = carbonMods;
    
    [self.window makeFirstResponder:nil];
    
    if ([self.delegate respondsToSelector:@selector(hotKeyRecorderDidRecordKey:modifiers:)]) {
        [self.delegate hotKeyRecorderDidRecordKey:_currentKeyCode modifiers:_currentModifiers];
    }
}

- (void)setKeyCode:(UInt32)keyCode modifiers:(UInt32)modifiers {
    _currentKeyCode = keyCode;
    _currentModifiers = modifiers;
    [self updateDisplay];
}

- (void)updateDisplay {
    NSString *modStr = [SettingsManager stringForCarbonModifiers:_currentModifiers];
    NSString *keyStr = [SettingsManager stringForKeyCode:_currentKeyCode];
    _label.stringValue = [NSString stringWithFormat:@"%@ %@", modStr, keyStr];
}

@end
