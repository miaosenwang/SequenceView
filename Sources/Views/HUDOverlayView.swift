import AppKit

public protocol HUDOverlayViewDelegate: AnyObject {
    func hudDidClickPrevious(_ hud: HUDOverlayView)
    func hudDidClickNext(_ hud: HUDOverlayView)
    func hudDidClickToggleMode(_ hud: HUDOverlayView)
    func hudDidClickToggleFullScreen(_ hud: HUDOverlayView)
    func hudDidClickOpenFolder(_ hud: HUDOverlayView)
    func hudDidClickHelp(_ hud: HUDOverlayView)
}

public class HUDOverlayView: NSView {
    public weak var delegate: HUDOverlayViewDelegate?

    private let topPill = NSVisualEffectView()
    private let bottomPill = NSVisualEffectView()

    // Top pill components
    private let folderLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let counterLabel = NSTextField(labelWithString: "0 / 0")
    private let modeButton = NSButton()
    private let fullscreenButton = NSButton()
    private let helpButton = NSButton()
    private let openButton = NSButton()

    // Bottom pill components
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let scrollHintLabel = NSTextField(labelWithString: "")

    private var fadeTimer: Timer?
    public var isPinned: Bool = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true

        // Top Pill
        topPill.translatesAutoresizingMaskIntoConstraints = false
        topPill.material = .hudWindow
        topPill.blendingMode = .withinWindow
        topPill.state = .active
        topPill.wantsLayer = true
        topPill.layer?.cornerRadius = 16
        topPill.layer?.masksToBounds = true
        topPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        topPill.layer?.borderWidth = 1.0

        addSubview(topPill)

        // Bottom Pill
        bottomPill.translatesAutoresizingMaskIntoConstraints = false
        bottomPill.material = .hudWindow
        bottomPill.blendingMode = .withinWindow
        bottomPill.state = .active
        bottomPill.wantsLayer = true
        bottomPill.layer?.cornerRadius = 14
        bottomPill.layer?.masksToBounds = true
        bottomPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        bottomPill.layer?.borderWidth = 1.0

        addSubview(bottomPill)

        NSLayoutConstraint.activate([
            topPill.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            topPill.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            topPill.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            topPill.heightAnchor.constraint(equalToConstant: 44),

            bottomPill.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomPill.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            bottomPill.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            bottomPill.heightAnchor.constraint(equalToConstant: 38)
        ])

        setupTopPillContents()
        setupBottomPillContents()
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === self {
            return nil
        }
        return hit
    }

    private func setupTopPillContents() {
        let hStack = NSStackView()
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.orientation = .horizontal
        hStack.spacing = 12
        hStack.alignment = .centerY
        topPill.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: topPill.leadingAnchor, constant: 14),
            hStack.trailingAnchor.constraint(equalTo: topPill.trailingAnchor, constant: -14),
            hStack.topAnchor.constraint(equalTo: topPill.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: topPill.bottomAnchor)
        ])

        // Open Button
        configurePillButton(openButton, title: "📁 Open", action: #selector(openClicked))
        hStack.addArrangedSubview(openButton)

        // Divider
        hStack.addArrangedSubview(createDivider())

        // File Title & Meta Stack
        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 1
        titleStack.alignment = .leading

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleStack.addArrangedSubview(titleLabel)

        metaLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = NSColor(white: 0.75, alpha: 1.0)
        titleStack.addArrangedSubview(metaLabel)

        hStack.addArrangedSubview(titleStack)

        // Divider
        hStack.addArrangedSubview(createDivider())

        // Counter
        counterLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        counterLabel.textColor = NSColor(red: 0.38, green: 0.85, blue: 0.98, alpha: 1.0) // Neon cyan
        hStack.addArrangedSubview(counterLabel)

        // Divider
        hStack.addArrangedSubview(createDivider())

        // Mode Button
        configurePillButton(modeButton, title: "Fit Screen (W)", action: #selector(modeClicked))
        hStack.addArrangedSubview(modeButton)

        // Fullscreen Button
        configurePillButton(fullscreenButton, title: "⤢ (F)", action: #selector(fullscreenClicked))
        hStack.addArrangedSubview(fullscreenButton)

        // Help Button
        configurePillButton(helpButton, title: "?", action: #selector(helpClicked))
        hStack.addArrangedSubview(helpButton)
    }

    private func setupBottomPillContents() {
        let hStack = NSStackView()
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.orientation = .horizontal
        hStack.spacing = 14
        hStack.alignment = .centerY
        bottomPill.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: bottomPill.leadingAnchor, constant: 14),
            hStack.trailingAnchor.constraint(equalTo: bottomPill.trailingAnchor, constant: -14),
            hStack.topAnchor.constraint(equalTo: bottomPill.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomPill.bottomAnchor)
        ])

        configurePillButton(prevButton, title: "◀ Prev [←]", action: #selector(prevClicked))
        hStack.addArrangedSubview(prevButton)

        scrollHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        scrollHintLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        hStack.addArrangedSubview(scrollHintLabel)

        configurePillButton(nextButton, title: "Next [→] ▶", action: #selector(nextClicked))
        hStack.addArrangedSubview(nextButton)
    }

    private func configurePillButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
    }

    private func createDivider() -> NSView {
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 18)
        ])
        return divider
    }

    // MARK: - Actions
    @objc private func openClicked() { delegate?.hudDidClickOpenFolder(self) }
    @objc private func modeClicked() { delegate?.hudDidClickToggleMode(self) }
    @objc private func fullscreenClicked() { delegate?.hudDidClickToggleFullScreen(self) }
    @objc private func helpClicked() { delegate?.hudDidClickHelp(self) }
    @objc private func prevClicked() { delegate?.hudDidClickPrevious(self) }
    @objc private func nextClicked() { delegate?.hudDidClickNext(self) }

    // MARK: - Update Data
    public func update(item: ImageItem?, index: Int, total: Int, mode: ViewMode, dimensions: CGSize?, zoomMultiplier: CGFloat = 1.0) {
        if let it = item {
            titleLabel.stringValue = it.relativePath

            var metaParts: [String] = []
            if let dim = dimensions ?? it.readDimensions() {
                metaParts.append("\(Int(dim.width)) × \(Int(dim.height))")
            }
            metaParts.append(it.formatName)
            if !it.formattedFileSize.isEmpty {
                metaParts.append(it.formattedFileSize)
            }
            metaLabel.stringValue = metaParts.joined(separator: " • ")
            counterLabel.stringValue = "\(index + 1) / \(total)"
            prevButton.isEnabled = index > 0
            nextButton.isEnabled = index < total - 1
        } else {
            titleLabel.stringValue = "No image"
            metaLabel.stringValue = ""
            counterLabel.stringValue = "0 / 0"
            prevButton.isEnabled = false
            nextButton.isEnabled = false
        }

        if zoomMultiplier != 1.0 {
            let pct = Int(round(zoomMultiplier * 100))
            modeButton.title = "\(mode.rawValue) (\(pct)%) [0]"
            scrollHintLabel.stringValue = "↕↔ Numpad 8/2/4/6 to scroll • +/- to zoom • 0 to reset"
        } else {
            switch mode {
            case .fitScreen:
                modeButton.title = "Mode: Fit Screen [W]"
                scrollHintLabel.stringValue = "Fit Screen active • +/- to zoom"
            case .fitWidth:
                modeButton.title = "Mode: Fit Width [W]"
                scrollHintLabel.stringValue = "↕ Numpad 8/2 to scroll • +/- to zoom"
            case .fitHeight:
                modeButton.title = "Mode: Fit Height [H]"
                scrollHintLabel.stringValue = "↔ Numpad 4/6 to scroll • +/- to zoom"
            }
        }
    }

    public func updateScrollProgress(_ progress: CGFloat) {
        let pct = Int(progress * 100)
        if modeButton.title.contains("%") {
            scrollHintLabel.stringValue = "↕↔ Scroll: \(pct)% • Numpad 8/2/4/6"
        } else if modeButton.title.contains("Fit Width") {
            scrollHintLabel.stringValue = "↕ Scroll: \(pct)% • Numpad 8/2"
        } else if modeButton.title.contains("Fit Height") {
            scrollHintLabel.stringValue = "↔ Scroll: \(pct)% • Numpad 4/6"
        }
    }

    // MARK: - Auto Fade
    public func pingVisibility() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 1.0
        }

        fadeTimer?.invalidate()
        if !isPinned {
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
                guard let self = self, !self.isPinned else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.5
                    self.animator().alphaValue = 0.0
                }
            }
        }
    }

    public func togglePinned() {
        isPinned.toggle()
        if isPinned {
            fadeTimer?.invalidate()
            alphaValue = 1.0
        } else {
            pingVisibility()
        }
    }
}
