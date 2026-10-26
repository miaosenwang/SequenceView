import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var windowControllers: [MainWindowController] = []
    private var launchedWithFiles = false

    public func applicationWillFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        // Register as a Services provider for "Open in SequenceView"
        NSApp.servicesProvider = self
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Only create a default empty window if no files were opened during launch
        // (via "Open With", drag-onto-dock, or command-line args)
        if !launchedWithFiles {
            let wc = createNewWindow()

            // Check if command line passed a path
            let args = CommandLine.arguments
            if args.count > 1 {
                launchedWithFiles = true
                let path = args[1]
                let url = URL(fileURLWithPath: path)
                wc.openFolder(url: url)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSServices Handler
    /// Called by macOS Services / Quick Actions when the user right-clicks a file/folder
    /// and selects "Open in SequenceView".
    @objc public func openInSequenceView(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let items = pboard.pasteboardItems else { return }
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                let wc = createNewWindow()
                wc.openFolder(url: url)
            }
        }
    }

    public func application(_ application: NSApplication, openFiles filenames: [String]) {
        launchedWithFiles = true
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)

            // If there's an active window with no images loaded, use it
            if let active = activeWindowController(),
               active.viewerViewController.sequenceManager.totalCount == 0 {
                active.openFolder(url: url)
            } else {
                // Open in a new window
                let wc = createNewWindow()
                wc.openFolder(url: url)
            }
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if windowControllers.isEmpty {
                _ = createNewWindow()
            } else {
                windowControllers.first?.showWindow(nil)
            }
        }
        return true
    }

    // MARK: - Window Management

    @discardableResult
    public func createNewWindow() -> MainWindowController {
        let wc = MainWindowController()
        wc.onWindowClose = { [weak self] controller in
            self?.windowControllers.removeAll { $0 === controller }
        }
        windowControllers.append(wc)
        wc.showWindow(nil)

        // Offset new windows slightly so they don't stack exactly
        if windowControllers.count > 1, let win = wc.window {
            let offset = CGFloat((windowControllers.count - 1) * 30)
            var frame = win.frame
            frame.origin.x += offset
            frame.origin.y -= offset
            win.setFrame(frame, display: true)
        }

        NSApp.activate(ignoringOtherApps: true)
        return wc
    }

    /// Returns the window controller for the currently key (focused) window.
    private func activeWindowController() -> MainWindowController? {
        guard let keyWindow = NSApp.keyWindow else {
            return windowControllers.first
        }
        return windowControllers.first { $0.window === keyWindow }
    }

    /// Returns the viewer controller for the currently focused window.
    private func activeViewerController() -> ViewerViewController? {
        return activeWindowController()?.viewerViewController
    }

    // MARK: - Menu Setup
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SequenceView", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide SequenceView", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit SequenceView", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(newWindowAction), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open Folder or Image...", action: #selector(openFileAction), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let fullScreenItem = NSMenuItem(title: "Toggle Full Screen", action: #selector(toggleFullScreenAction), keyEquivalent: "f")
        fullScreenItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(fullScreenItem)
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Fit Screen", action: #selector(fitScreenAction), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Fit Width", action: #selector(fitWidthAction), keyEquivalent: "2")
        viewMenu.addItem(withTitle: "Fit Height", action: #selector(fitHeightAction), keyEquivalent: "3")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Rotate Clockwise", action: #selector(rotateCWAction), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "Rotate Counter-Clockwise", action: #selector(rotateCCWAction), keyEquivalent: "l")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Navigate Menu
        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigate")
        let nextItem = NSMenuItem(title: "Next Image", action: #selector(nextImageAction), keyEquivalent: String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1))
        nextItem.keyEquivalentModifierMask = []
        navMenu.addItem(nextItem)

        let prevItem = NSMenuItem(title: "Previous Image", action: #selector(prevImageAction), keyEquivalent: String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1))
        prevItem.keyEquivalentModifierMask = []
        navMenu.addItem(prevItem)
        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "SequenceView Help", action: #selector(helpAction), keyEquivalent: "?")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions
    @objc private func newWindowAction() {
        _ = createNewWindow()
    }

    @objc private func openFileAction() {
        activeViewerController()?.showOpenPanel()
    }

    @objc private func toggleFullScreenAction() {
        activeWindowController()?.window?.toggleFullScreen(nil)
    }

    @objc private func fitScreenAction() {
        activeViewerController()?.hudDidClickToggleMode(HUDOverlayView())
    }

    @objc private func fitWidthAction() {
        activeViewerController()?.hudDidClickToggleMode(HUDOverlayView())
    }

    @objc private func fitHeightAction() {
        activeViewerController()?.hudDidClickToggleMode(HUDOverlayView())
    }

    @objc private func rotateCWAction() {
        // Trigger rotate on active window
    }

    @objc private func rotateCCWAction() {
        // Trigger rotate on active window
    }

    @objc private func nextImageAction() {
        activeViewerController()?.sequenceManager.next()
    }

    @objc private func prevImageAction() {
        activeViewerController()?.sequenceManager.previous()
    }

    @objc private func helpAction() {
        activeViewerController()?.hudDidClickHelp(HUDOverlayView())
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
