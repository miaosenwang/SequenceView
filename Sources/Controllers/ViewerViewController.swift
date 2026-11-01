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

        imageDisplayView.contextMenuProvider = { [weak self] event in
            return self?.buildContextMenu(for: event)
        }

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
        } else {
            imageDisplayView.setImage(nil)
            hudOverlay.update(item: nil, index: 0, total: 0, mode: imageDisplayView.mode, dimensions: nil)
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

        case 51, 117: // Delete / Backspace (51), Forward Delete (117)
            deleteCurrentImage()

        default:
            if let chars = event.charactersIgnoringModifiers,
               let firstScalar = chars.unicodeScalars.first,
               firstScalar.value == 0x7F || firstScalar.value == 0xF728 || firstScalar.value == 0x08 {
                deleteCurrentImage()
            } else if event.characters == "+" || event.characters == "=" {
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

    /// Starts image sequence browsing from the parent folder of the specified URL,
    /// and begins viewing at the specified item (the exact image file or the first image of the folder).
    public func startFromHere(url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        let parentDir = url.deletingLastPathComponent()
        sequenceManager.loadFolder(url: parentDir, initialTargetURL: url)
        hudOverlay.showTransientNotice("📂 Started from \"\(parentDir.lastPathComponent)\"")
    }

    // MARK: - Context Menu
    public func buildContextMenu(for event: NSEvent) -> NSMenu {
        let menu = NSMenu(title: "Context Menu")

        guard let currentItem = sequenceManager.currentItem else {
            let openItem = NSMenuItem(title: "Open Folder or Image...", action: #selector(contextOpenAction), keyEquivalent: "o")
            openItem.target = self
            menu.addItem(openItem)
            return menu
        }

        let fileURL = currentItem.url
        let currentFolder = fileURL.deletingLastPathComponent()
        let parentFolder = currentFolder.deletingLastPathComponent()

        // 1. "Start from Here"
        let startFromHereItem = NSMenuItem(
            title: "Start from Here",
            action: #selector(contextStartFromHereAction),
            keyEquivalent: ""
        )
        startFromHereItem.target = self
        startFromHereItem.toolTip = "Start image viewing from the parent folder at this item"
        menu.addItem(startFromHereItem)

        // 2. If parent folder exists and is distinct from root/filesystem root
        if parentFolder.path != currentFolder.path && parentFolder.path != "/" {
            let startParentItem = NSMenuItem(
                title: "Start from Parent Folder (\(parentFolder.lastPathComponent))",
                action: #selector(contextStartFromParentFolderAction),
                keyEquivalent: ""
            )
            startParentItem.target = self
            startParentItem.toolTip = "Browse all images from \"\(parentFolder.lastPathComponent)\" starting at this item"
            menu.addItem(startParentItem)
        }

        // 3. If currently browsing a parent folder and this item is in a subfolder:
        if let root = sequenceManager.rootFolderURL,
           root.standardizedFileURL.path != currentFolder.standardizedFileURL.path,
           currentFolder.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path) {
            let startSubfolderItem = NSMenuItem(
                title: "Start from Current Subfolder (\(currentFolder.lastPathComponent))",
                action: #selector(contextStartFromCurrentFolderAction),
                keyEquivalent: ""
            )
            startSubfolderItem.target = self
            startSubfolderItem.toolTip = "Limit viewing to only \"\(currentFolder.lastPathComponent)\" starting at this item"
            menu.addItem(startSubfolderItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Navigation
        let nextItem = NSMenuItem(title: "Next Image", action: #selector(contextNextAction), keyEquivalent: "")
        nextItem.target = self
        nextItem.isEnabled = sequenceManager.hasNext
        menu.addItem(nextItem)

        let prevItem = NSMenuItem(title: "Previous Image", action: #selector(contextPrevAction), keyEquivalent: "")
        prevItem.target = self
        prevItem.isEnabled = sequenceManager.hasPrevious
        menu.addItem(prevItem)

        let firstItem = NSMenuItem(title: "First Image", action: #selector(contextFirstAction), keyEquivalent: "")
        firstItem.target = self
        firstItem.isEnabled = sequenceManager.currentIndex > 0
        menu.addItem(firstItem)

        let lastItem = NSMenuItem(title: "Last Image", action: #selector(contextLastAction), keyEquivalent: "")
        lastItem.target = self
        lastItem.isEnabled = sequenceManager.currentIndex < sequenceManager.totalCount - 1
        menu.addItem(lastItem)

        menu.addItem(NSMenuItem.separator())

        // View Modes
        let fitScreenItem = NSMenuItem(title: "Fit Screen", action: #selector(contextFitScreenAction), keyEquivalent: "")
        fitScreenItem.target = self
        fitScreenItem.state = imageDisplayView.mode == .fitScreen ? .on : .off
        menu.addItem(fitScreenItem)

        let fitWidthItem = NSMenuItem(title: "Fit Width", action: #selector(contextFitWidthAction), keyEquivalent: "")
        fitWidthItem.target = self
        fitWidthItem.state = imageDisplayView.mode == .fitWidth ? .on : .off
        menu.addItem(fitWidthItem)

        let fitHeightItem = NSMenuItem(title: "Fit Height", action: #selector(contextFitHeightAction), keyEquivalent: "")
        fitHeightItem.target = self
        fitHeightItem.state = imageDisplayView.mode == .fitHeight ? .on : .off
        menu.addItem(fitHeightItem)

        menu.addItem(NSMenuItem.separator())

        let zoomInItem = NSMenuItem(title: "Zoom In (+)", action: #selector(contextZoomInAction), keyEquivalent: "")
        zoomInItem.target = self
        menu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Zoom Out (-)", action: #selector(contextZoomOutAction), keyEquivalent: "")
        zoomOutItem.target = self
        menu.addItem(zoomOutItem)

        if imageDisplayView.zoomMultiplier != 1.0 {
            let resetZoomItem = NSMenuItem(title: "Reset Zoom (0)", action: #selector(contextResetZoomAction), keyEquivalent: "")
            resetZoomItem.target = self
            menu.addItem(resetZoomItem)
        }

        let rotateCWItem = NSMenuItem(title: "Rotate Clockwise (90°)", action: #selector(contextRotateCWAction), keyEquivalent: "")
        rotateCWItem.target = self
        menu.addItem(rotateCWItem)

        let rotateCCWItem = NSMenuItem(title: "Rotate Counter-Clockwise (90°)", action: #selector(contextRotateCCWAction), keyEquivalent: "")
        rotateCCWItem.target = self
        menu.addItem(rotateCCWItem)

        let fsTitle = (view.window?.styleMask.contains(.fullScreen) == true) ? "Exit Full Screen" : "Enter Full Screen"
        let fullScreenItem = NSMenuItem(title: fsTitle, action: #selector(contextToggleFullScreenAction), keyEquivalent: "")
        fullScreenItem.target = self
        menu.addItem(fullScreenItem)

        menu.addItem(NSMenuItem.separator())

        // File Operations
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(contextRevealInFinderAction), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let copyPathItem = NSMenuItem(title: "Copy File Path", action: #selector(contextCopyPathAction), keyEquivalent: "")
        copyPathItem.target = self
        menu.addItem(copyPathItem)

        let openItem = NSMenuItem(title: "Open Folder or Image...", action: #selector(contextOpenAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let trashItem = NSMenuItem(title: "Move to Trash", action: #selector(contextTrashAction), keyEquivalent: "")
        trashItem.target = self
        menu.addItem(trashItem)

        return menu
    }

    @objc public func contextStartFromHereAction() {
        startFromHereCurrentAction()
    }

    public func startFromHereCurrentAction() {
        guard let currentItem = sequenceManager.currentItem else { return }
        let fileURL = currentItem.url
        let currentFolder = fileURL.deletingLastPathComponent()

        // If current sequence is rooted at currentFolder, expand to the parent folder
        // so all sibling folders/images in the parent are included, starting at currentItem.
        // Otherwise, start from currentFolder's parent folder.
        let parentDir: URL
        if let root = sequenceManager.rootFolderURL,
           root.standardizedFileURL.path == currentFolder.standardizedFileURL.path {
            parentDir = currentFolder.deletingLastPathComponent()
        } else {
            parentDir = currentFolder.deletingLastPathComponent()
        }

        sequenceManager.loadFolder(url: parentDir, initialTargetURL: fileURL)
        hudOverlay.showTransientNotice("📂 Browsing from \"\(parentDir.lastPathComponent)\"")
    }

    @objc public func contextStartFromParentFolderAction() {
        guard let currentItem = sequenceManager.currentItem else { return }
        let currentFolder = currentItem.url.deletingLastPathComponent()
        let parentDir = currentFolder.deletingLastPathComponent()
        sequenceManager.loadFolder(url: parentDir, initialTargetURL: currentItem.url)
        hudOverlay.showTransientNotice("📂 Browsing from \"\(parentDir.lastPathComponent)\"")
    }

    @objc public func contextStartFromCurrentFolderAction() {
        guard let currentItem = sequenceManager.currentItem else { return }
        let currentFolder = currentItem.url.deletingLastPathComponent()
        sequenceManager.loadFolder(url: currentFolder, initialTargetURL: currentItem.url)
        hudOverlay.showTransientNotice("📂 Browsing from \"\(currentFolder.lastPathComponent)\"")
    }

    @objc private func contextNextAction() { sequenceManager.next(); hudOverlay.pingVisibility() }
    @objc private func contextPrevAction() { sequenceManager.previous(); hudOverlay.pingVisibility() }
    @objc private func contextFirstAction() { sequenceManager.first(); hudOverlay.pingVisibility() }
    @objc private func contextLastAction() { sequenceManager.last(); hudOverlay.pingVisibility() }
    @objc private func contextFitScreenAction() { imageDisplayView.setMode(.fitScreen); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextFitWidthAction() { imageDisplayView.setMode(.fitWidth); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextFitHeightAction() { imageDisplayView.setMode(.fitHeight); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextZoomInAction() { imageDisplayView.zoomIn(); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextZoomOutAction() { imageDisplayView.zoomOut(); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextResetZoomAction() { imageDisplayView.resetZoom(); updateHUD(); hudOverlay.pingVisibility() }
    @objc private func contextRotateCWAction() { imageDisplayView.rotateClockwise(); hudOverlay.pingVisibility() }
    @objc private func contextRotateCCWAction() { imageDisplayView.rotateCounterClockwise(); hudOverlay.pingVisibility() }
    @objc private func contextToggleFullScreenAction() { view.window?.toggleFullScreen(nil) }
    @objc private func contextOpenAction() { showOpenPanel() }
    @objc private func contextTrashAction() { deleteCurrentImage() }

    @objc private func contextRevealInFinderAction() {
        guard let item = sequenceManager.currentItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func contextCopyPathAction() {
        guard let item = sequenceManager.currentItem else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.path, forType: .string)
        hudOverlay.showTransientNotice("📋 Copied file path to clipboard")
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

    // MARK: - Image Deletion
    public func deleteCurrentImage() {
        guard helpOverlay == nil else { return }
        guard let item = sequenceManager.currentItem else { return }
        let filename = item.filename
        let result = sequenceManager.deleteCurrentItem()
        if result.success {
            hudOverlay.showTransientNotice("🗑 Moved \"\(filename)\" to Trash")
        } else if let error = result.error {
            hudOverlay.showTransientNotice("❌ Failed to delete: \(error.localizedDescription)")
        }
    }
}
