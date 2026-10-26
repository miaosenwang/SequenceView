import AppKit

let item = ImageItem(url: URL(fileURLWithPath: "test_images/01_landscape_alpine.jpg"))
let img = NSImage(contentsOf: item.url)! // 1920x1080 (16:9)

// 1. Start small (windowed 400x300)
let displayView = ImageDisplayView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
displayView.setImage(img)
displayView.layout()

// 2. Transition to Fullscreen (1920x1080)
displayView.frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
displayView.layout()

// Subview 0 is scrollView, documentView contains imageView
let doc = displayView.subviews.first?.subviews.first?.subviews.first
let imageView = doc?.subviews.first as? NSImageView
print("ImageView Frame in Full Screen: \(imageView?.frame ?? .zero)")

assert(imageView != nil, "ImageView must exist")
assert(imageView!.frame.width == 1920, "ImageView width must be 1920 in full screen, got \(imageView!.frame.width)")
assert(imageView!.frame.height == 1080, "ImageView height must be 1080 in full screen, got \(imageView!.frame.height)")
print("✅ Fullscreen resize assertion verified!")
