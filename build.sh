#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Building SequenceView Native macOS App..."

# Detect working SDK
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
else
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

echo "📦 Using SDK: $SDK_PATH"

mkdir -p build/SequenceView.app/Contents/MacOS
mkdir -p build/SequenceView.app/Contents/Resources

SWIFT_FILES=(
    "Sources/Model/ImageItem.swift"
    "Sources/Model/ImageSequenceManager.swift"
    "Sources/Views/ImageDisplayView.swift"
    "Sources/Views/HUDOverlayView.swift"
    "Sources/Views/HelpOverlayView.swift"
    "Sources/Views/EmptyStateView.swift"
    "Sources/Controllers/ViewerViewController.swift"
    "Sources/Controllers/MainWindowController.swift"
    "Sources/App/AppDelegate.swift"
    "Sources/App/main.swift"
)

echo "⚡️ Compiling Swift sources..."
SDKROOT="$SDK_PATH" swiftc -O -sdk "$SDK_PATH" "${SWIFT_FILES[@]}" -o build/SequenceView.app/Contents/MacOS/SequenceView

# Copy Icon if available
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns build/SequenceView.app/Contents/Resources/AppIcon.icns
fi

# Create Info.plist
cat << 'EOF' > build/SequenceView.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SequenceView</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.sequenceview</string>
    <key>CFBundleName</key>
    <string>SequenceView</string>
    <key>CFBundleDisplayName</key>
    <string>SequenceView</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folder</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Image</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.image</string>
            </array>
        </dict>
    </array>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Open in SequenceView</string>
            </dict>
            <key>NSMessage</key>
            <string>openInSequenceView</string>
            <key>NSPortName</key>
            <string>SequenceView</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.folder</string>
                <string>public.image</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > build/SequenceView.app/Contents/PkgInfo

# Ad-hoc code sign
codesign --force --deep --sign - build/SequenceView.app 2>/dev/null || true

# Convenience symlink for CLI usage
ln -sf build/SequenceView.app/Contents/MacOS/SequenceView SequenceView

# If 'install' passed as argument, update /Applications and register with Launch Services
if [ "$1" == "install" ]; then
    echo "📲 Installing to /Applications..."
    rm -rf /Applications/SequenceView.app
    cp -R build/SequenceView.app /Applications/SequenceView.app

    # Register with Launch Services so the app shows in "Open With" menus
    echo "🔗 Registering with Launch Services..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/SequenceView.app 2>/dev/null || true

    # Install Finder Quick Action for right-click context menu
    WORKFLOW_DIR="$HOME/Library/Services/Open in SequenceView.workflow"
    echo "⚡️ Installing Finder Quick Action..."
    mkdir -p "$WORKFLOW_DIR/Contents"

    cat << 'WFEOF' > "$WORKFLOW_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Open in SequenceView</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.folder</string>
                <string>public.image</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
WFEOF

    cat << 'DOCEOF' > "$WORKFLOW_DIR/Contents/document.wflow"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <false/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMBundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>AMCategory</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>AMIconName</key>
                <string>Automator</string>
                <key>AMKeywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>AMName</key>
                <string>Run Shell Script</string>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMRequiredResources</key>
                <array/>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>for f in "$@"; do
    open -a "/Applications/SequenceView.app" "$f"
done</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/zsh</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>IgnoresInput</key>
                <false/>
                <key>InputUUID</key>
                <string>A1A1A1A1-B2B2-C3C3-D4D4-E5E5E5E5E5E5</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>ModifiedDate</key>
                <date>2024-01-01T00:00:00Z</date>
                <key>Name</key>
                <string>Run Shell Script</string>
                <key>OutputUUID</key>
                <string>F6F6F6F6-A7A7-B8B8-C9C9-D0D0D0D0D0D0</string>
                <key>UUID</key>
                <string>12345678-AAAA-BBBB-CCCC-DDDDDDDDDDD1</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>inputMethod</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                    <key>1</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>source</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>1</string>
                    </dict>
                    <key>2</key>
                    <dict>
                        <key>default value</key>
                        <false/>
                        <key>name</key>
                        <string>CheckedForUserDefaultShell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>2</string>
                    </dict>
                    <key>3</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>COMMAND_STRING</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>3</string>
                    </dict>
                    <key>4</key>
                    <dict>
                        <key>default value</key>
                        <string>/bin/zsh</string>
                        <key>name</key>
                        <string>shell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>4</string>
                    </dict>
                </dict>
                <key>conversionLabel</key>
                <integer>0</integer>
                <key>isViewVisible</key>
                <true/>
                <key>location</key>
                <string>529.000000:620.000000</string>
                <key>nibPath</key>
                <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
            </dict>
            <key>isViewVisible</key>
            <true/>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <integer>0</integer>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
DOCEOF

    echo "✅ Installed to /Applications and registered Quick Action."
    echo "   ℹ️  Right-click a folder or image in Finder → Quick Actions → 'Open in SequenceView'"
    echo "   ℹ️  Or use: Right-click → Open With → SequenceView"
fi

echo "✅ Successfully built: build/SequenceView.app and ./SequenceView"

