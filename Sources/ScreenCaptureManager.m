#import "ScreenCaptureManager.h"
#import "SettingsManager.h"

@interface ScreenCaptureManager ()
@property (nonatomic, strong, nullable) NSSound *shutterSound;
@end

@implementation ScreenCaptureManager

+ (instancetype)sharedManager {
    static ScreenCaptureManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[ScreenCaptureManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *soundPath = @"/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif";
        if ([[NSFileManager defaultManager] fileExistsAtPath:soundPath]) {
            _shutterSound = [[NSSound alloc] initWithContentsOfFile:soundPath byReference:YES];
        }
    }
    return self;
}

- (nullable NSImage *)captureScreenForDisplay:(nullable NSScreen *)screen {
    if (!screen) {
        screen = [NSScreen mainScreen];
    }
    
    // Create temporary file
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"chill_cap_%f.png", [NSDate timeIntervalSinceReferenceDate]]];
    
    // Find screen index
    NSArray<NSScreen *> *screens = [NSScreen screens];
    NSUInteger screenIndex = [screens indexOfObject:screen];
    if (screenIndex == NSNotFound) screenIndex = 0;
    
    // Using /usr/sbin/screencapture CLI (fast, native resolution, full multi-display support)
    // -x: no sound (we control sound)
    // -D <display_id>: capture specific display (1-based index)
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
    task.arguments = @[@"-x", @"-D", [NSString stringWithFormat:@"%lu", (unsigned long)(screenIndex + 1)], tempPath];
    
    NSError *error = nil;
    [task launchAndReturnError:&error];
    if (error) {
        NSLog(@"[ChillScreen] screencapture launch error: %@", error);
        return nil;
    }
    [task waitUntilExit];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        // Fallback without -D if multi-monitor index was out of range
        NSTask *fbTask = [[NSTask alloc] init];
        fbTask.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
        fbTask.arguments = @[@"-x", tempPath];
        [fbTask launchAndReturnError:nil];
        [fbTask waitUntilExit];
    }
    
    NSImage *capturedImage = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        capturedImage = [[NSImage alloc] initWithContentsOfFile:tempPath];
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
    }
    
    return capturedImage;
}

- (nullable NSImage *)cropImage:(NSImage *)image toRect:(NSRect)rect screenScale:(CGFloat)scale {
    if (!image || rect.size.width <= 0 || rect.size.height <= 0) return nil;
    
    // rect is in Cocoa view points (origin at bottom-left)
    // Scale up to pixel dimensions
    CGRect pixelRect = CGRectMake(rect.origin.x * scale,
                                  rect.origin.y * scale,
                                  rect.size.width * scale,
                                  rect.size.height * scale);
    
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cgImage) return nil;
    
    size_t imgHeight = CGImageGetHeight(cgImage);
    size_t imgWidth = CGImageGetWidth(cgImage);
    
    // Convert Cocoa coordinates (y from bottom) to CGImage coordinates (y from top)
    CGRect cgCropRect = CGRectMake(pixelRect.origin.x,
                                   (CGFloat)imgHeight - (pixelRect.origin.y + pixelRect.size.height),
                                   pixelRect.size.width,
                                   pixelRect.size.height);
    
    // Bounds check
    cgCropRect = CGRectIntersection(cgCropRect, CGRectMake(0, 0, (CGFloat)imgWidth, (CGFloat)imgHeight));
    if (CGRectIsEmpty(cgCropRect)) return nil;
    
    CGImageRef croppedCG = CGImageCreateWithImageInRect(cgImage, cgCropRect);
    if (!croppedCG) return nil;
    
    NSImage *result = [[NSImage alloc] initWithCGImage:croppedCG size:rect.size];
    CGImageRelease(croppedCG);
    return result;
}

- (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path format:(NSString *)format {
    if (!image || !path) return NO;
    
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cgImage) return NO;
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    [rep setSize:image.size];
    
    NSData *data = nil;
    if ([format.uppercaseString isEqualToString:@"JPG"] || [format.uppercaseString isEqualToString:@"JPEG"]) {
        data = [rep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{NSImageCompressionFactor: @0.95}];
    } else {
        data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }
    
    if (!data) return NO;
    
    BOOL success = [data writeToFile:path atomically:YES];
    if (success) {
        if ([SettingsManager sharedManager].playSound) {
            [self playShutterSound];
        }
        [self showNotificationWithTitle:@"ChillScreen"
                                message:[NSString stringWithFormat:@"Đã lưu ảnh vào %@", path.lastPathComponent]];
    }
    return success;
}

- (void)copyImageToClipboard:(NSImage *)image {
    if (!image) return;
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage) {
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
        [rep setSize:image.size];
        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (pngData) {
            [pb setData:pngData forType:NSPasteboardTypePNG];
        }
    }
    [pb writeObjects:@[image]];
    
    if ([SettingsManager sharedManager].playSound) {
        [self playShutterSound];
    }
    
    if ([SettingsManager sharedManager].autoSaveOnCopy) {
        NSString *autoPath = [[SettingsManager sharedManager] generateNewFilePathWithExtension];
        [self saveImage:image toPath:autoPath format:[SettingsManager sharedManager].imageFormat];
    } else {
        [self showNotificationWithTitle:@"ChillScreen" message:@"Đã sao chép ảnh chụp vào Clipboard!"];
    }
}

- (void)playShutterSound {
    if (_shutterSound) {
        [_shutterSound play];
    } else {
        NSBeep();
    }
}

- (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSUserNotification *notif = [[NSUserNotification alloc] init];
    notif.title = title;
    notif.informativeText = message;
    notif.soundName = nil;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notif];
#pragma clang diagnostic pop
}

- (BOOL)hasScreenCapturePermission {
    if (@available(macOS 10.15, *)) {
        return CGPreflightScreenCaptureAccess();
    }
    return YES;
}

- (void)openScreenCapturePreferences {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end
