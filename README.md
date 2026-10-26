# SequenceView — Native macOS Image Sequence Viewer

An ultra-fast, native macOS app built with **Swift** and **AppKit** to browse images in a sequence within a folder and all its subfolders. Designed for an immersive fullscreen experience where you never lose focus or exit full screen when paging through images.

---

## ✨ Key Features

- **Recursive Subfolder Traversal**:
  Recursively discovers all images across nested subdirectories, using natural alphanumeric sorting (`1`, `2`, `10` instead of `1`, `10`, `2`).
- **Uninterrupted Fullscreen Sequence Navigation**:
  Use **Left (`←`)** and **Right (`→`)** arrow keys or **Space** to step through images sequentially. The app remains in fullscreen mode without exiting or flickering.
- **Fit Width & Fit Height Modes with Auto-Centering**:
  Zoom the image to fit the exact screen width (ideal for long infographics, webtoon/comic strips, documents, vertical panoramas) or exact screen height (ideal for wide panoramic photos and timelines). Images **automatically default to center** when entering these modes or navigating images.
- **Zoom In / Out with `+` and `-`**:
  Smoothly zoom into any image with **`+`** (or **`=`**) and zoom out with **`-`** (up to 1000% zoom). Press **`0`** at any time to reset zoom back to fit view.
- **Number Pad Arrow Key Scrolling**:
  Use the arrows on the number pad to scroll and pan through all parts of tall, wide, or zoomed images:
  - **Numpad `8` (`↑`) / `2` (`↓`)**: Scroll vertically (hold `Shift` for fast scroll)
  - **Numpad `4` (`←`) / `6` (`→`)**: Scroll horizontally (hold `Shift` for fast scroll)
  - **Numpad `7` (Home) / `1` (End)**: Jump to top/leading edge or bottom/trailing edge
  - **Numpad `5`**: Re-center image
- **Aspect Ratio Preservation**:
  Strictly preserves the original image aspect ratio in **Fit Screen**, **Fit Width**, and **Fit Height** modes—no distortion or stretching.
- **Broad Format Support (60+ Formats)**:
  Natively supports **JPEG, PNG, GIF, WebP, HEIC/HEIF, TIFF, BMP, SVG, AVIF, ICNS**, as well as camera RAW formats (Canon CR2/CR3, Nikon NEF, Sony ARW, Adobe DNG) via Apple ImageIO and AppKit.
- **Ultra-Responsive Background Prefetching**:
  Decodes next and previous images in a background thread with an intelligent LRU memory cache for instant, stutter-free arrow navigation.
- **Glassmorphic Floating HUD**:
  Displays current file path, dimensions, format, file size, sequence counter (`42 / 128`), and scroll percentage. Automatically fades out after inactivity for distraction-free viewing.
- **Drag & Drop + CLI Integration**:
  Drop any folder or image file directly onto the window or launch from terminal with `./SequenceView /path/to/folder`. Opening a single image automatically indexes its entire folder hierarchy and jumps straight to that image.

---

## ⌨️ Keyboard Shortcuts & Controls

| Key | Action |
| :--- | :--- |
| **`→`** or **`Space`** | **Next image** in sequence |
| **`←`** or **`Shift + Space`** | **Previous image** in sequence |
| **`+`** / **`-`** (or Numpad **`+`** / **`-`**) | **Zoom in / Zoom out** (25% to 1000%) |
| **`0`** (or Numpad **`0`**) | **Reset zoom** to 100% / Fit |
| **Numpad `8` / `2`** | **Scroll up / down** (hold `Shift` for faster scroll) |
| **Numpad `4` / `6`** | **Scroll left / right** (hold `Shift` for faster scroll) |
| **Numpad `7` / `1`** | Jump to top / bottom (Home / End) |
| **Numpad `5`** | Re-center image |
| **`W`** | **Cycle view mode** (Fit Screen → Fit Width → Fit Height) |
| **`H`** | **Toggle Fit Height mode** directly |
| **`PgUp` / `PgDn`** | Page scroll up / down |
| **`Home` / `End`** | Jump to top / bottom |
| **`F`** or **`Return`** | **Toggle Full Screen** |
| **`Cmd + O`** | Choose folder or image dialog |
| **`R` / `L`** | Rotate 90° Clockwise / Counter-Clockwise |
| **`I`** | Toggle persistent HUD info bar |
| **`?`** | Toggle Keyboard Shortcuts Help Sheet |
| **`Esc`** | Close Help sheet or exit Full Screen |
| **`Cmd + Q`** | Quit application |

---

## 🚀 Running the App

### 1. Launch via Terminal
```bash
# View a specific directory (including all subfolders)
./SequenceView /path/to/your/images

# Or view the included sample test folder
./SequenceView test_images
```

### 2. Launch as macOS App Bundle
```bash
open build/SequenceView.app
```
You can also drag `build/SequenceView.app` to your `/Applications` folder.

---

## 🔨 Building from Source

To compile the native app bundle:
```bash
./build.sh
```

To run the automated test suite:
```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  Sources/Model/ImageItem.swift \
  Sources/Model/ImageSequenceManager.swift \
  Sources/Views/ImageDisplayView.swift \
  Tests/main.swift \
  -o build/test_runner && ./build/test_runner && rm -f build/test_runner
```

---

## 📂 Project Architecture

```
image_viewer_anti/
├── build.sh                               # Build script for macOS app bundle
├── SequenceView                           # CLI symlink executable
├── Resources/
│   └── AppIcon.icns                       # High-res retina macOS app icon
├── Sources/
│   ├── App/
│   │   ├── main.swift                     # Entry point & activation policy
│   │   └── AppDelegate.swift              # App lifecycle, menus & open handlers
│   ├── Model/
│   │   ├── ImageItem.swift                # Image metadata & dimension extractor
│   │   └── ImageSequenceManager.swift     # Recursive folder scanner & LRU cache
│   ├── Views/
│   │   ├── ImageDisplayView.swift         # Aspect fit / Fit width scrolling view
│   │   ├── HUDOverlayView.swift           # Frosted glass floating HUD bar
│   │   ├── HelpOverlayView.swift          # Frosted glass shortcuts modal
│   │   └── EmptyStateView.swift           # Drag & drop welcome view
│   └── Controllers/
│       ├── ViewerViewController.swift     # Core keyboard & gesture event router
│       └── MainWindowController.swift     # Fullscreen window & drag-and-drop
├── Tests/
│   └── main.swift                         # Automated test suite
└── test_images/                           # Sample images with subfolders
```
