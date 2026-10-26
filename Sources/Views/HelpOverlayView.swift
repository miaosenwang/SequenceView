import AppKit

public class HelpOverlayView: NSView {
    public var onClose: (() -> Void)?

    private let card = NSVisualEffectView()

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
        layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.65).cgColor

        card.translatesAutoresizingMaskIntoConstraints = false
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 20
        card.layer?.masksToBounds = true
        card.layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor
        card.layer?.borderWidth = 1.0

        addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 520),
            card.heightAnchor.constraint(equalToConstant: 540)
        ])

        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .centerX
        card.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])

        // Title
        let titleLabel = NSTextField(labelWithString: "⌨️ SequenceView Shortcuts")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        mainStack.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Keyboard controls for uninterrupted fullscreen viewing")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        mainStack.addArrangedSubview(subtitleLabel)

        // Shortcuts List
        let grid = NSGridView(views: [
            [makeKeyBadge("→ / Space"), makeDescLabel("Next image in sequence")],
            [makeKeyBadge("← / ⇧ Space"), makeDescLabel("Previous image in sequence")],
            [makeKeyBadge("W"), makeDescLabel("Cycle: Fit Screen → Fit Width → Fit Height")],
            [makeKeyBadge("H"), makeDescLabel("Toggle Fit Height mode directly")],
            [makeKeyBadge("Numpad 8 / 2"), makeDescLabel("Scroll up / down (hold Shift for faster)")],
            [makeKeyBadge("Numpad 4 / 6"), makeDescLabel("Scroll left / right (hold Shift for faster)")],
            [makeKeyBadge("Numpad 7 / 1"), makeDescLabel("Jump to top / bottom (Home / End)")],
            [makeKeyBadge("+ / -"), makeDescLabel("Zoom in / Zoom out")],
            [makeKeyBadge("0"), makeDescLabel("Reset zoom to 100% / Fit")],
            [makeKeyBadge("F / Return"), makeDescLabel("Toggle Full Screen")],
            [makeKeyBadge("⌘ O"), makeDescLabel("Open Folder or Image...")],
            [makeKeyBadge("R / L"), makeDescLabel("Rotate 90° Clockwise / Counter-Clockwise")],
            [makeKeyBadge("I"), makeDescLabel("Toggle persistent HUD bar")],
            [makeKeyBadge("? / Esc"), makeDescLabel("Show Help / Close Help or exit Full Screen")]
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 16
        grid.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        mainStack.addArrangedSubview(grid)

        // Close Button
        let closeBtn = NSButton(title: "Got it (Esc)", target: self, action: #selector(dismiss))
        closeBtn.bezelStyle = .rounded
        closeBtn.keyEquivalent = "\u{1b}" // Esc
        mainStack.addArrangedSubview(closeBtn)
    }

    private func makeKeyBadge(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: " \(text) ")
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(red: 0.38, green: 0.85, blue: 0.98, alpha: 1.0)
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        label.layer?.cornerRadius = 5
        label.layer?.borderWidth = 0.5
        label.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        label.alignment = .right
        return label
    }

    private func makeDescLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = NSColor(white: 0.9, alpha: 1.0)
        return label
    }

    @objc private func dismiss() {
        onClose?()
    }

    public override func mouseDown(with event: NSEvent) {
        let pointInCard = card.convert(event.locationInWindow, from: nil)
        if !card.bounds.contains(pointInCard) {
            dismiss()
        }
    }
}
