#!/bin/bash
set -e

APP_NAME="EdgeTap"
EXECUTABLE_NAME="EdgeTapApp"
BUNDLE_ID="com.edgetap.mac"
VERSION="1.0.0"

ARCH=$(uname -m)
BUILD_DIR=".build/${ARCH}-apple-macosx/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building Release executable..."
swift build -c release

echo "📦 Packaging ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/"

# Copy SPM resource bundle (contains Localizable.strings etc.)
RESOURCE_BUNDLE="${BUILD_DIR}/EdgeTap_EdgeTapApp.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -r "${RESOURCE_BUNDLE}" "${MACOS_DIR}/"
    echo "📋 Copied resource bundle"
fi

# Copy icon
if [ -f "Sources/EdgeTapApp/Resources/AppIcon.icns" ]; then
    cp "Sources/EdgeTapApp/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🖋️ Codesigning..."
codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Build Complete: ./${APP_DIR}"
echo "🎉 You can now move EdgeTap.app to your Applications folder."
