#!/usr/bin/env bash
set -e

APP_NAME="ChillScreen"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} for macOS..."

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Source files
SOURCES=(
    "Sources/main.m"
    "Sources/AppDelegate.m"
    "Sources/HotKeyManager.m"
    "Sources/ScreenCaptureManager.m"
    "Sources/SettingsManager.m"
    "Sources/Models/AnnotationItem.m"
    "Sources/UI/AnnotationToolbarView.m"
    "Sources/UI/CaptureOverlayView.m"
    "Sources/UI/OverlayWindow.m"
    "Sources/UI/HotKeyRecorderView.m"
    "Sources/UI/SettingsWindowController.m"
)

# Frameworks
FRAMEWORKS=(
    "-framework" "Cocoa"
    "-framework" "Carbon"
    "-framework" "ScreenCaptureKit"
    "-framework" "CoreGraphics"
    "-framework" "CoreImage"
    "-framework" "QuartzCore"
)

# Compile
clang -fobjc-arc -O2 -Wall \
    -mmacosx-version-min=12.0 \
    "${FRAMEWORKS[@]}" \
    "${SOURCES[@]}" \
    -o "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and Resources
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

# Clean AppleDouble dot files
dot_clean "${APP_BUNDLE}" 2>/dev/null || true

# Code sign (ad-hoc)
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "==> Build successful: ${APP_BUNDLE}"
