import AppKit
import QuartzCore

public enum ViewMode: String, CaseIterable {
    case fitScreen = "Fit Screen"
    case fitWidth = "Fit Width"
    case fitHeight = "Fit Height"
}

public protocol ImageDisplayViewDelegate: AnyObject {
    func imageDisplayView(_ view: ImageDisplayView, didUpdateScrollProgress progress: CGFloat)
}

public class ImageDocumentView: NSView {
    override public var isFlipped: Bool { true }
}

public class ImageDisplayView: NSView {
    public weak var delegate: ImageDisplayViewDelegate?

    public private(set) var mode: ViewMode = .fitScreen
    public private(set) var rotationAngle: CGFloat = 0 // in degrees: 0, 90, 180, 270

    private let scrollView = NSScrollView()
    private let documentView = ImageDocumentView()
    private let imageView = NSImageView()

    private var currentImage: NSImage?
    private var rawImageSize: CGSize = .zero

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        // Configure ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .black
        scrollView.drawsBackground = true
        scrollView.documentView = documentView

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Configure Document View
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.black.cgColor

        // Configure ImageView
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        imageView.wantsLayer = true
        imageView.layer?.contentsGravity = .resizeAspect
        documentView.addSubview(imageView)

        // Listen to frame and bounds changes
        postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewDidResize),
            name: NSView.frameDidChangeNotification,
            object: self
        )

        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewDidResize),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func layout() {
        super.layout()
        updateLayout(resetScroll: false)
    }

    public private(set) var zoomMultiplier: CGFloat = 1.0
    public static let defaultZoomSteps: [CGFloat] = [
        0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0, 8.0, 10.0
    ]

    public var currentImageSize: CGSize {
        return rawImageSize
    }

    // MARK: - Public API
    public func setImage(_ image: NSImage?, resetScroll: Bool = true) {
        self.currentImage = image
        self.imageView.image = image
        if resetScroll {
            self.zoomMultiplier = 1.0
        }
        if let img = image {
            if let rep = img.representations.first {
                self.rawImageSize = CGSize(width: rep.pixelsWide > 0 ? rep.pixelsWide : Int(img.size.width),
                                           height: rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(img.size.height))
            } else {
                self.rawImageSize = img.size
            }
        } else {
            self.rawImageSize = .zero
        }

        updateLayout(resetScroll: resetScroll)
    }

    public func setMode(_ newMode: ViewMode) {
        self.mode = newMode
        self.zoomMultiplier = 1.0
        updateLayout(resetScroll: true)
    }

    public func toggleMode() {
        switch mode {
        case .fitScreen:
            setMode(.fitWidth)
        case .fitWidth:
            setMode(.fitHeight)
        case .fitHeight:
            setMode(.fitScreen)
        }
    }

    // MARK: - Zooming
    public func zoomIn() {
        if let next = ImageDisplayView.defaultZoomSteps.first(where: { $0 > zoomMultiplier + 0.02 }) {
            setZoomMultiplier(next)
        } else {
            setZoomMultiplier(min(10.0, zoomMultiplier * 1.25))
        }
    }

    public func zoomOut() {
        if let prev = ImageDisplayView.defaultZoomSteps.last(where: { $0 < zoomMultiplier - 0.02 }) {
            setZoomMultiplier(prev)
        } else {
            setZoomMultiplier(max(0.25, zoomMultiplier / 1.25))
        }
    }

    public func resetZoom() {
        setZoomMultiplier(1.0)
    }

    public func setZoomMultiplier(_ newZoom: CGFloat) {
        let clamped = max(0.25, min(10.0, newZoom))
        guard abs(clamped - zoomMultiplier) > 0.001 else { return }

        let clipView = scrollView.contentView
        let viewportCenter = NSPoint(
            x: clipView.bounds.origin.x + clipView.bounds.width / 2,
            y: clipView.bounds.origin.y + clipView.bounds.height / 2
        )
        let oldDocWidth = max(1, documentView.frame.width)
        let oldDocHeight = max(1, documentView.frame.height)

        zoomMultiplier = clamped
        updateLayout(resetScroll: false)

        let newDocWidth = documentView.frame.width
        let newDocHeight = documentView.frame.height

        let scaleX = newDocWidth / oldDocWidth
        let scaleY = newDocHeight / oldDocHeight

        let newCenterX = viewportCenter.x * scaleX
        let newCenterY = viewportCenter.y * scaleY

        let maxX = max(0, newDocWidth - clipView.bounds.width)
        let maxY = max(0, newDocHeight - clipView.bounds.height)

        let targetX = max(0, min(maxX, newCenterX - clipView.bounds.width / 2))
        let targetY = max(0, min(maxY, newCenterY - clipView.bounds.height / 2))

        clipView.scroll(to: NSPoint(x: targetX, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func centerScroll() {
        let clipView = scrollView.contentView
        let maxY = max(0, documentView.frame.height - clipView.bounds.height)
        let maxX = max(0, documentView.frame.width - clipView.bounds.width)
        clipView.scroll(to: NSPoint(x: maxX / 2, y: maxY / 2))
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func rotateClockwise() {
        rotationAngle = CGFloat((Int(rotationAngle) + 90) % 360)
        updateLayout(resetScroll: false)
    }

    public func rotateCounterClockwise() {
        rotationAngle = CGFloat((Int(rotationAngle) + 270) % 360)
        updateLayout(resetScroll: false)
    }

    public func resetRotation() {
        rotationAngle = 0
        updateLayout(resetScroll: false)
    }

    // MARK: - Scrolling Capabilities
    public var viewportSize: CGSize {
        return bounds.size.width > 0 && bounds.size.height > 0 ? bounds.size : scrollView.contentView.bounds.size
    }

    public var canScrollVertically: Bool {
        return (documentView.frame.height - viewportSize.height) > 1
    }

    public var canScrollHorizontally: Bool {
        return (documentView.frame.width - viewportSize.width) > 1
    }

    // MARK: - Scrolling
    public func scrollVertically(by delta: CGFloat, isRepeat: Bool) {
        let clipView = scrollView.contentView
        let currentOrigin = clipView.bounds.origin
        let maxY = max(0, documentView.frame.height - clipView.bounds.height)
        guard maxY > 0 else { return }

        let targetY = max(0, min(maxY, currentOrigin.y + delta))
        if targetY == currentOrigin.y { return }

        let targetPoint = NSPoint(x: currentOrigin.x, y: targetY)
        clipView.scroll(to: targetPoint)
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func scrollHorizontally(by delta: CGFloat, isRepeat: Bool) {
        let clipView = scrollView.contentView
        let currentOrigin = clipView.bounds.origin
        let maxX = max(0, documentView.frame.width - clipView.bounds.width)
        guard maxX > 0 else { return }

        let targetX = max(0, min(maxX, currentOrigin.x + delta))
        if targetX == currentOrigin.x { return }

        let targetPoint = NSPoint(x: targetX, y: currentOrigin.y)
        clipView.scroll(to: targetPoint)
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func scrollToTop() {
        let clipView = scrollView.contentView
        let origin = NSPoint(x: clipView.bounds.origin.x, y: 0)
        clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func scrollToLeadingEdge() {
        let clipView = scrollView.contentView
        let origin = NSPoint(x: 0, y: clipView.bounds.origin.y)
        clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func scrollToTrailingEdge() {
        let clipView = scrollView.contentView
        let maxX = max(0, documentView.frame.width - clipView.bounds.width)
        clipView.scroll(to: NSPoint(x: maxX, y: clipView.bounds.origin.y))
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func scrollToBottom() {
        let clipView = scrollView.contentView
        let maxY = max(0, documentView.frame.height - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: maxY))
        scrollView.reflectScrolledClipView(clipView)
        notifyScrollProgress()
    }

    public func pageDown() {
        let step = scrollView.contentView.bounds.height * 0.8
        scrollVertically(by: step, isRepeat: false)
    }

    public func pageUp() {
        let step = -scrollView.contentView.bounds.height * 0.8
        scrollVertically(by: step, isRepeat: false)
    }

    // MARK: - Layout & Sizing
    @objc private func viewDidResize() {
        updateLayout(resetScroll: false)
    }

    @objc private func boundsDidChange() {
        notifyScrollProgress()
    }

    private func notifyScrollProgress() {
        let clipView = scrollView.contentView
        if zoomMultiplier != 1.0 {
            let maxY = max(0, documentView.frame.height - clipView.bounds.height)
            let maxX = max(0, documentView.frame.width - clipView.bounds.width)
            if maxY >= maxX && maxY > 0 {
                let progress = max(0, min(1, clipView.bounds.origin.y / maxY))
                delegate?.imageDisplayView(self, didUpdateScrollProgress: progress)
            } else if maxX > 0 {
                let progress = max(0, min(1, clipView.bounds.origin.x / maxX))
                delegate?.imageDisplayView(self, didUpdateScrollProgress: progress)
            } else {
                delegate?.imageDisplayView(self, didUpdateScrollProgress: 1.0)
            }
            return
        }

        switch mode {
        case .fitHeight:
            let maxX = documentView.frame.width - clipView.bounds.width
            if maxX <= 0 {
                delegate?.imageDisplayView(self, didUpdateScrollProgress: 1.0)
            } else {
                let progress = max(0, min(1, clipView.bounds.origin.x / maxX))
                delegate?.imageDisplayView(self, didUpdateScrollProgress: progress)
            }
        case .fitWidth:
            let maxY = documentView.frame.height - clipView.bounds.height
            if maxY <= 0 {
                delegate?.imageDisplayView(self, didUpdateScrollProgress: 1.0)
            } else {
                let progress = max(0, min(1, clipView.bounds.origin.y / maxY))
                delegate?.imageDisplayView(self, didUpdateScrollProgress: progress)
            }
        case .fitScreen:
            delegate?.imageDisplayView(self, didUpdateScrollProgress: 1.0)
        }
    }

    public func updateLayout(resetScroll: Bool = false) {
        guard rawImageSize.width > 0 && rawImageSize.height > 0 else {
            imageView.frame = .zero
            documentView.frame = bounds
            return
        }

        // Accurately capture viewport size from view bounds or scrollview
        let viewport = bounds.size.width > 0 && bounds.size.height > 0 ? bounds.size : scrollView.contentView.frame.size
        guard viewport.width > 0 && viewport.height > 0 else { return }

        let isQuarterTurn = (Int(rotationAngle) == 90 || Int(rotationAngle) == 270)
        let effectiveWidth = isQuarterTurn ? rawImageSize.height : rawImageSize.width
        let effectiveHeight = isQuarterTurn ? rawImageSize.width : rawImageSize.height
        let aspectRatio = effectiveWidth / effectiveHeight

        var baseWidth: CGFloat = 0
        var baseHeight: CGFloat = 0

        switch mode {
        case .fitScreen:
            let viewportRatio = viewport.width / viewport.height
            if viewportRatio > aspectRatio {
                baseHeight = viewport.height
                baseWidth = baseHeight * aspectRatio
            } else {
                baseWidth = viewport.width
                baseHeight = baseWidth / aspectRatio
            }

        case .fitWidth:
            baseWidth = viewport.width
            baseHeight = baseWidth / aspectRatio

        case .fitHeight:
            baseHeight = viewport.height
            baseWidth = baseHeight * aspectRatio
        }

        let targetWidth = baseWidth * zoomMultiplier
        let targetHeight = baseHeight * zoomMultiplier

        let docWidth = max(viewport.width, targetWidth)
        let docHeight = max(viewport.height, targetHeight)

        documentView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)

        let imageX: CGFloat = (docWidth - targetWidth) / 2
        let imageY: CGFloat = (docHeight - targetHeight) / 2

        imageView.frame = NSRect(x: imageX, y: imageY, width: targetWidth, height: targetHeight)
        imageView.frameCenterRotation = rotationAngle

        if resetScroll {
            let clipView = scrollView.contentView
            // Center the scroll position
            let maxY = max(0, docHeight - viewport.height)
            let maxX = max(0, docWidth - viewport.width)
            let centeredOrigin = NSPoint(x: maxX / 2, y: maxY / 2)
            clipView.scroll(to: centeredOrigin)
            scrollView.reflectScrolledClipView(clipView)
        } else {
            let clipView = scrollView.contentView
            let maxY = max(0, docHeight - viewport.height)
            let maxX = max(0, docWidth - viewport.width)
            var clampedOrigin = clipView.bounds.origin
            if clampedOrigin.y > maxY { clampedOrigin.y = maxY }
            if clampedOrigin.x > maxX { clampedOrigin.x = maxX }
            if clampedOrigin != clipView.bounds.origin {
                clipView.scroll(to: clampedOrigin)
                scrollView.reflectScrolledClipView(clipView)
            }
        }

        notifyScrollProgress()
    }
}
