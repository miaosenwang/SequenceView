import AppKit

public class EmptyStateView: NSView {
    public var onSelectFolder: (() -> Void)?

    private let card = NSVisualEffectView()
    private let dropBorder = CAShapeLayer()

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
        layer?.backgroundColor = NSColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1.0).cgColor

        // Frosted Card
        card.translatesAutoresizingMaskIntoConstraints = false
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 24
        card.layer?.masksToBounds = true
        card.layer?.borderColor = NSColor(white: 1.0, alpha: 0.14).cgColor
        card.layer?.borderWidth = 1.0

        addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 480),
            card.heightAnchor.constraint(equalToConstant: 440)
        ])

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .centerX
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 36),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -36)
        ])

        // Icon
        let iconLabel = NSTextField(labelWithString: "🖼️")
        iconLabel.font = NSFont.systemFont(ofSize: 52)
        iconLabel.alignment = .center
        stack.addArrangedSubview(iconLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: "SequenceView")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)

        // Subtitle
        let subtitle = NSTextField(labelWithString: "Immersive Fullscreen Image Sequence Viewer")
        subtitleLabel(subtitle)
        stack.addArrangedSubview(subtitle)

        // Feature Pills
        let features = [
            "📂 Recursive subfolder scanning",
            "↔️ Arrow keys navigate without exiting fullscreen",
            "↕️ Fit Width mode with smooth arrow scrolling",
            "⚡️ High-speed prefetching for instant paging"
        ]
        for feature in features {
            let label = NSTextField(labelWithString: feature)
            label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            label.textColor = NSColor(white: 0.85, alpha: 1.0)
            stack.addArrangedSubview(label)
        }

        // Open Folder Button
        let openButton = NSButton(title: "Choose Folder to View...", target: self, action: #selector(openFolderAction))
        openButton.bezelStyle = .rounded
        openButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        openButton.keyEquivalent = "o"
        openButton.keyEquivalentModifierMask = .command
        stack.addArrangedSubview(openButton)

        let hint = NSTextField(labelWithString: "or drag and drop any folder or image here")
        hint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hint.textColor = NSColor(white: 0.55, alpha: 1.0)
        stack.addArrangedSubview(hint)
    }

    private func subtitleLabel(_ label: NSTextField) {
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(red: 0.38, green: 0.85, blue: 0.98, alpha: 1.0)
    }

    @objc private func openFolderAction() {
        onSelectFolder?()
    }
}
