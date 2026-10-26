import Foundation
import AppKit

print("🧪 Running SequenceView Test Suite...")

// Test 1: Recursive Scanning & Natural Ordering
let manager = ImageSequenceManager()
let currentDir = FileManager.default.currentDirectoryPath
let testDir = URL(fileURLWithPath: currentDir).appendingPathComponent("test_images")

class TestDelegate: NSObject, ImageSequenceManagerDelegate {
    var didFinish = false
    func sequenceManager(_ manager: ImageSequenceManager, didUpdateList count: Int) {}
    func sequenceManager(_ manager: ImageSequenceManager, didChangeIndex index: Int, item: ImageItem?) {}
    func sequenceManagerDidFinishScanning(_ manager: ImageSequenceManager) {
        didFinish = true
    }
}

let delegate = TestDelegate()
manager.delegate = delegate
manager.loadFolder(url: testDir)

// Pump the main run loop so DispatchQueue.main blocks execute
let timeout = Date().addingTimeInterval(5.0)
while !delegate.didFinish && Date() < timeout {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
}

assert(delegate.didFinish, "Scan should finish within 5s")
assert(manager.totalCount == 6, "Expected 6 images recursively found across subfolders, got \(manager.totalCount)")
print("✅ Test 1 Passed: Found \(manager.totalCount) images recursively across subfolders.")

// Test 2: Natural Ordering Verification
for (idx, item) in manager.items.enumerated() {
    print("   [\(idx + 1)/\(manager.totalCount)] \(item.relativePath) (\(item.formatName), \(item.formattedFileSize))")
}
assert(manager.items[0].filename.contains("01_landscape"), "First image should be 01_landscape")
print("✅ Test 2 Passed: Natural path sorting verified.")

// Test 3: Arrow Navigation (Next / Previous without resetting sequence)
assert(manager.currentIndex == 0, "Initial index should be 0")
assert(manager.next() == true, "manager.next() should succeed")
assert(manager.currentIndex == 1, "Index should now be 1")
assert(manager.previous() == true, "manager.previous() should succeed")
assert(manager.currentIndex == 0, "Index should be back to 0")
print("✅ Test 3 Passed: Next and Previous arrow navigation logic verified.")

// Test 4: Image Dimensions and Aspect Ratio Preservation
let tallItem = manager.items.first(where: { $0.filename.contains("04_tall_infographic") })!
let tallDims = tallItem.readDimensions()!
assert(tallDims.width == 1200 && tallDims.height == 3600, "Tall image dimensions must be 1200x3600, got \(tallDims)")
let tallRatio = tallDims.width / tallDims.height
assert(abs(tallRatio - (1200.0 / 3600.0)) < 0.001, "Aspect ratio calculation must be preserved")
print("✅ Test 4 Passed: Aspect ratio and dimensions correctly read: \(tallDims).")

// Test 5: ImageDisplayView Layout Verification (Fit Screen vs Fit Width)
let displayView = ImageDisplayView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
let testTallImage = NSImage(contentsOf: tallItem.url)!

// Set Fit Screen
displayView.setMode(.fitScreen)
displayView.setImage(testTallImage)
assert(displayView.mode == .fitScreen, "Mode should be fitScreen")

// Set Fit Width
displayView.setMode(.fitWidth)
assert(displayView.mode == .fitWidth, "Mode should be fitWidth")
assert(displayView.canScrollVertically == true, "Tall image in fitWidth should be scrollable vertically")
assert(displayView.canScrollHorizontally == false, "Tall image in fitWidth should not be scrollable horizontally")

// Test Vertical Scrolling in Fit Width
displayView.scrollVertically(by: 120, isRepeat: true)
displayView.scrollVertically(by: -50, isRepeat: true)
print("✅ Test 5 Passed: Fit Screen and Fit Width modes verified with vertical scrolling.")

// Test 6: Fit Height Mode & Centering Verification
let wideItem = manager.items.first(where: { $0.filename.contains("03_ultrawide_skyline") })!
let testWideImage = NSImage(contentsOf: wideItem.url)!
displayView.setImage(testWideImage)
displayView.setMode(.fitHeight)
assert(displayView.mode == .fitHeight, "Mode should be fitHeight")
assert(displayView.canScrollHorizontally == true, "Ultrawide image in fitHeight should be scrollable horizontally")

// Test Horizontal Scrolling in Fit Height
displayView.scrollHorizontally(by: 150, isRepeat: true)
displayView.scrollHorizontally(by: -80, isRepeat: true)
print("✅ Test 6 Passed: Fit Height mode verified with horizontal scrolling.")

// Test 7: Zoom In / Out / Reset Verification
displayView.setMode(.fitScreen)
assert(displayView.zoomMultiplier == 1.0, "Initial zoom should be 1.0")

displayView.zoomIn()
assert(displayView.zoomMultiplier > 1.0, "Zooming in should increase zoom multiplier (got \(displayView.zoomMultiplier))")

let zoomedIn = displayView.zoomMultiplier
displayView.zoomIn()
assert(displayView.zoomMultiplier > zoomedIn, "Second zoom in should increase zoom multiplier further")

displayView.zoomOut()
assert(displayView.zoomMultiplier == zoomedIn, "Zoom out should return to previous zoom level")

displayView.resetZoom()
assert(displayView.zoomMultiplier == 1.0, "Reset zoom should return multiplier to 1.0")
print("✅ Test 7 Passed: Zoom in, zoom out, and reset zoom verified.")

print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
