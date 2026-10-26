import AppKit

public class MainWindow: NSWindow, NSDraggingDestination {
    public var onFileDrop: ((URL) -> Void)?

    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        registerForDraggedTypes([.fileURL])
    }

    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return .copy
        }
        return []
    }

    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first {
            onFileDrop?(first)
            return true
        }
        return false
    }
}

public class MainWindowController: NSWindowController, NSWindowDelegate {
    public let viewerViewController = ViewerViewController()
    public var onWindowClose: ((MainWindowController) -> Void)?

    public init() {
        let window = MainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 850),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "SequenceView"
        window.center()
        window.minSize = NSSize(width: 640, height: 480)
        window.backgroundColor = .black
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
        window.contentViewController = viewerViewController

        super.init(window: window)

        window.delegate = self

        window.onFileDrop = { [weak self] url in
            self?.viewerViewController.openTarget(url: url)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func openFolder(url: URL) {
        viewerViewController.openTarget(url: url)
    }

    // MARK: - NSWindowDelegate
    public func windowWillClose(_ notification: Notification) {
        onWindowClose?(self)
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        viewerViewController.handleWindowResize()
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        viewerViewController.handleWindowResize()
    }

    public func windowDidResize(_ notification: Notification) {
        viewerViewController.handleWindowResize()
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        viewerViewController.handleWindowResize()
    }
}
