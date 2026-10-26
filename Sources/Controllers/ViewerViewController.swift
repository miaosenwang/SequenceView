import AppKit

public class ViewerViewController: NSViewController, ImageSequenceManagerDelegate, ImageDisplayViewDelegate, HUDOverlayViewDelegate {

    public let sequenceManager = ImageSequenceManager()

    private let imageDisplayView = ImageDisplayView()
    private let hudOverlay = HUDOverlayView()
    private let emptyStateView = EmptyStateView()
    private var helpOverlay: HelpOverlayView?

    private var trackingArea: NSTrackingArea?
    private var cursorHideTimer: Timer?

    public override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 750))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        self.view = root
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        sequenceManager.delegate = self
        imageDisplayView.delegate = self
        hudOverlay.delegate = self

        setupViews()
        setupTrackingArea()
        setupWindowNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        imageDisplayView.updateLayout(resetScroll: false)
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
        imageDisplayView.updateLayout(resetScroll: false)
        hudOverlay.pingVisibility()
    }

    public func handleWindowResize() {
        DispatchQueue.main.async { [weak self] in
            self?.imageDisplayView.updateLayout(resetScroll: false)
            self?.hudOverlay.pingVisibility()
        }
    }

    private func setupWindowNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeSize(_:)),
            name: NSWindow.didResizeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeSize(_:)),
            name: NSWindow.didEnterFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeSize(_:)),
            name: NSWindow.didExitFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeSize(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: nil
        )
    }

    @objc private func windowDidChangeSize(_ notification: Notification) {
        handleWindowResize()
    }

    private func setupViews() {
        // Image Display View
        imageDisplayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageDisplayView)

        // Empty State View
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.onSelectFolder = { [weak self] in
            self?.showOpenPanel()
        }
        view.addSubview(emptyStateView)

        // HUD Overlay View
        hudOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudOverlay)

        NSLayoutConstraint.activate([
            imageDisplayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageDisplayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageDisplayView.topAnchor.constraint(equalTo: view.topAnchor),
            imageDisplayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hudOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hudOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hudOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            hudOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateUIState()
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        self.trackingArea = area
    }

    private func updateUIState() {
        let hasImages = sequenceManager.totalCount > 0
        emptyStateView.isHidden = hasImages
        imageDisplayView.isHidden = !hasImages
        hudOverlay.isHidden = !hasImages

        if hasImages {
            loadCurrentItemImage()
        }
    }

    private func loadCurrentItemImage() {
        guard let item = sequenceManager.currentItem else {
            imageDisplayView.setImage(nil)
            hudOverlay.update(item: nil, index: 0, total: 0, mode: imageDisplayView.mode, dimensions: nil)
            return
        }

        sequenceManager.loadImage(for: item) { [weak self] image in
            guard let self = self else { return }
            // Verify item hasn't changed while loading
            if self.sequenceManager.currentItem == item {
                self.imageDisplayView.setImage(image, resetScroll: true)
                let dims = image?.size
                self.hudOverlay.update(
                    item: item,
                    index: self.sequenceManager.currentIndex,
                    total: self.sequenceManager.totalCount,
                    mode: self.imageDisplayView.mode,
                    dimensions: dims
                )
                self.hudOverlay.pingVisibility()
            }
        }
    }

    // MARK: - SequenceManager Delegate
    public func sequenceManager(_ manager: ImageSequenceManager, didUpdateList count: Int) {
        updateUIState()
        if let item = manager.currentItem {
            hudOverlay.update(
                item: item,
                index: manager.currentIndex,
                total: manager.totalCount,
                mode: imageDisplayView.mode,
                dimensions: nil
            )
        }
    }

    public func sequenceManager(_ manager: ImageSequenceManager, didChangeIndex index: Int, item: ImageItem?) {
        loadCurrentItemImage()
    }

    public func sequenceManagerDidFinishScanning(_ manager: ImageSequenceManager) {
        if let item = manager.currentItem {
            hudOverlay.update(
                item: item,
                index: manager.currentIndex,
                total: manager.totalCount,
                mode: imageDisplayView.mode,
                dimensions: nil
            )
        }
    }

    // MARK: - ImageDisplayView Delegate
    public func imageDisplayView(_ view: ImageDisplayView, didUpdateScrollProgress progress: CGFloat) {
        hudOverlay.updateScrollProgress(progress)
    }

    // MARK: - HUDOverlayView Delegate
    public func hudDidClickPrevious(_ hud: HUDOverlayView) {
        sequenceManager.previous()
        hudOverlay.pingVisibility()
    }

    public func hudDidClickNext(_ hud: HUDOverlayView) {
        sequenceManager.next()
        hudOverlay.pingVisibility()
    }

    public func hudDidClickToggleMode(_ hud: HUDOverlayView) {
        if imageDisplayView.zoomMultiplier != 1.0 {
            imageDisplayView.resetZoom()
        } else {
            imageDisplayView.toggleMode()
        }
        updateHUD()
        hudOverlay.pingVisibility()
    }

    public func hudDidClickToggleFullScreen(_ hud: HUDOverlayView) {
        view.window?.toggleFullScreen(nil)
    }

    public func hudDidClickOpenFolder(_ hud: HUDOverlayView) {
        showOpenPanel()
    }

    public func hudDidClickHelp(_ hud: HUDOverlayView) {
        toggleHelp()
    }

    private func updateHUD() {
        hudOverlay.update(
            item: sequenceManager.currentItem,
            index: sequenceManager.currentIndex,
            total: sequenceManager.totalCount,
            mode: imageDisplayView.mode,
            dimensions: imageDisplayView.currentImageSize,
            zoomMultiplier: imageDisplayView.zoomMultiplier
        )
    }

    // MARK: - Keyboard Handling
    public override var acceptsFirstResponder: Bool { true }

    public override func keyDown(with event: NSEvent) {
        hudOverlay.pingVisibility()
        showCursor()

        switch event.keyCode {
        case 123: // Standard Left Arrow -> Previous image
            sequenceManager.previous()

        case 124: // Standard Right Arrow -> Next image
            sequenceManager.next()

        case 125: // Standard Down Arrow -> Next image
            sequenceManager.next()

        case 126: // Standard Up Arrow -> Previous image
            sequenceManager.previous()

        // MARK: - Number Pad Arrow Keys (Scrolling)
        case 91: // Keypad 8 -> Up Arrow
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 240 : 90
            imageDisplayView.scrollVertically(by: -step, isRepeat: event.isARepeat)

        case 84: // Keypad 2 -> Down Arrow
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 240 : 90
            imageDisplayView.scrollVertically(by: step, isRepeat: event.isARepeat)

        case 86: // Keypad 4 -> Left Arrow
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 240 : 90
            imageDisplayView.scrollHorizontally(by: -step, isRepeat: event.isARepeat)

        case 88: // Keypad 6 -> Right Arrow
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 240 : 90
            imageDisplayView.scrollHorizontally(by: step, isRepeat: event.isARepeat)

        case 89: // Keypad 7 -> Home
            imageDisplayView.scrollToTop()
            imageDisplayView.scrollToLeadingEdge()

        case 83: // Keypad 1 -> End
            imageDisplayView.scrollToBottom()
            imageDisplayView.scrollToTrailingEdge()

        case 92: // Keypad 9 -> Page Up
            imageDisplayView.pageUp()

        case 85: // Keypad 3 -> Page Down
            imageDisplayView.pageDown()

        case 87: // Keypad 5 -> Center
            imageDisplayView.centerScroll()

        // MARK: - Zooming (+ / - / 0)
        case 24, 69, 81: // Equal/Plus key (24), Keypad Plus (69), Keypad Equals (81)
            imageDisplayView.zoomIn()
            updateHUD()

        case 27, 78: // Minus key (27), Keypad Minus (78)
            imageDisplayView.zoomOut()
            updateHUD()

        case 29, 82: // '0' key (29), Keypad 0 (82) -> Reset Zoom to 100% / Fit
            imageDisplayView.resetZoom()
            updateHUD()

        case 49: // Space
            if event.modifierFlags.contains(.shift) {
                sequenceManager.previous()
            } else {
                sequenceManager.next()
            }

        case 13: // 'W' Key -> Toggle Fit Width / Fit Height / Fit Screen
            imageDisplayView.toggleMode()
            updateHUD()

        case 3: // 'F' Key -> Toggle Full Screen
            view.window?.toggleFullScreen(nil)

        case 36: // Return -> Toggle Full Screen
            view.window?.toggleFullScreen(nil)

        case 15: // 'R' Key -> Rotate 90 CW
            imageDisplayView.rotateClockwise()

        case 37: // 'L' Key -> Rotate 90 CCW
            imageDisplayView.rotateCounterClockwise()

        case 4: // 'H' Key -> Toggle Fit Height
            if imageDisplayView.mode == .fitHeight {
                imageDisplayView.setMode(.fitScreen)
            } else {
                imageDisplayView.setMode(.fitHeight)
            }
            updateHUD()

        case 34: // 'I' Key -> Toggle HUD pinned
            hudOverlay.togglePinned()

        case 116: // Page Up
            if imageDisplayView.mode == .fitHeight {
                let step = -imageDisplayView.bounds.width * 0.8
                imageDisplayView.scrollHorizontally(by: step, isRepeat: false)
            } else {
                imageDisplayView.pageUp()
            }

        case 121: // Page Down
            if imageDisplayView.mode == .fitHeight {
                let step = imageDisplayView.bounds.width * 0.8
                imageDisplayView.scrollHorizontally(by: step, isRepeat: false)
            } else {
                imageDisplayView.pageDown()
            }

        case 115: // Home
            if imageDisplayView.mode == .fitHeight {
                imageDisplayView.scrollToLeadingEdge()
            } else {
                imageDisplayView.scrollToTop()
            }

        case 119: // End
            if imageDisplayView.mode == .fitHeight {
                imageDisplayView.scrollToTrailingEdge()
            } else {
                imageDisplayView.scrollToBottom()
            }

        case 53: // Esc
            if helpOverlay != nil {
                dismissHelp()
            } else if let win = view.window, win.styleMask.contains(.fullScreen) {
                win.toggleFullScreen(nil)
            }

        default:
            if event.characters == "+" || event.characters == "=" {
                imageDisplayView.zoomIn()
                updateHUD()
            } else if event.characters == "-" {
                imageDisplayView.zoomOut()
                updateHUD()
            } else if event.characters == "0" {
                imageDisplayView.resetZoom()
                updateHUD()
            } else if event.characters == "?" {
                toggleHelp()
            } else {
                super.keyDown(with: event)
            }
        }
    }

    // MARK: - Mouse Movement & Cursor Auto-hide
    public override func mouseMoved(with event: NSEvent) {
        hudOverlay.pingVisibility()
        showCursor()

        cursorHideTimer?.invalidate()
        if let win = view.window, win.styleMask.contains(.fullScreen) {
            cursorHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hideCursor()
            }
        }
    }

    private func hideCursor() {
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    private func showCursor() {
        // Will automatically show when mouse moves
    }

    // MARK: - Open Panel
    public func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.message = "Choose a folder or image to view in sequence"
        panel.prompt = "Open"

        panel.beginSheetModal(for: view.window ?? NSApp.mainWindow ?? NSWindow()) { [weak self] response in
            guard let self = self, response == .OK, let selectedURL = panel.url else { return }
            self.openTarget(url: selectedURL)
        }
    }

    public func openTarget(url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                sequenceManager.loadFolder(url: url)
            } else {
                // Single file: load its parent directory and jump to this file!
                let parentDir = url.deletingLastPathComponent()
                sequenceManager.loadFolder(url: parentDir, initialTargetURL: url)
            }
        }
    }

    // MARK: - Help Dialog
    private func toggleHelp() {
        if helpOverlay != nil {
            dismissHelp()
        } else {
            showHelp()
        }
    }

    private func showHelp() {
        guard helpOverlay == nil else { return }
        let help = HelpOverlayView()
        help.translatesAutoresizingMaskIntoConstraints = false
        help.onClose = { [weak self] in
            self?.dismissHelp()
        }
        view.addSubview(help)
        NSLayoutConstraint.activate([
            help.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            help.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            help.topAnchor.constraint(equalTo: view.topAnchor),
            help.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.helpOverlay = help
    }

    private func dismissHelp() {
        helpOverlay?.removeFromSuperview()
        helpOverlay = nil
        view.window?.makeFirstResponder(self)
    }
}
