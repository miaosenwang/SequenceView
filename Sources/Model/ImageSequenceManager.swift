import Foundation
import AppKit

public protocol ImageSequenceManagerDelegate: AnyObject {
    func sequenceManager(_ manager: ImageSequenceManager, didUpdateList count: Int)
    func sequenceManager(_ manager: ImageSequenceManager, didChangeIndex index: Int, item: ImageItem?)
    func sequenceManagerDidFinishScanning(_ manager: ImageSequenceManager)
}

public class ImageSequenceManager {
    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif",
        "tiff", "tif", "bmp", "svg", "avif", "ico", "icns",
        "psd", "cr2", "cr3", "nef", "arw", "dng", "raw"
    ]

    public weak var delegate: ImageSequenceManagerDelegate?

    public private(set) var rootFolderURL: URL?
    public private(set) var items: [ImageItem] = []
    public private(set) var currentIndex: Int = 0
    public private(set) var isScanning: Bool = false

    // Image cache for smooth navigation
    private let memoryCache = NSCache<NSString, NSImage>()
    private var scanWorkItem: DispatchWorkItem?
    private let loadQueue = DispatchQueue(label: "com.sequenceview.imageloader", qos: .userInitiated)

    public init() {
        memoryCache.countLimit = 15 // Keeps up to 15 full-res images in RAM
        memoryCache.totalCostLimit = 250 * 1024 * 1024 // ~250MB RAM limit
    }

    public var currentItem: ImageItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    public var totalCount: Int {
        return items.count
    }

    public var hasNext: Bool {
        return currentIndex < items.count - 1
    }

    public var hasPrevious: Bool {
        return currentIndex > 0
    }

    // MARK: - Scanning
    public func loadFolder(url: URL, initialTargetURL: URL? = nil) {
        // Cancel ongoing scan
        scanWorkItem?.cancel()
        isScanning = true
        rootFolderURL = url
        items.removeAll()
        currentIndex = 0
        memoryCache.removeAllObjects()

        delegate?.sequenceManager(self, didUpdateList: 0)
        delegate?.sequenceManager(self, didChangeIndex: 0, item: nil)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            var discovered: [URL] = []
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
            
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var lastReportCount = 0

            while let fileURL = enumerator?.nextObject() as? URL {
                if self.scanWorkItem?.isCancelled == true { return }

                let ext = fileURL.pathExtension.lowercased()
                if ImageSequenceManager.supportedExtensions.contains(ext) {
                    discovered.append(fileURL)

                    // Report initial batch quickly so user sees image immediately
                    if (discovered.count == 1 || discovered.count == 10 || discovered.count % 50 == 0) && discovered.count != lastReportCount {
                        lastReportCount = discovered.count
                        let snapshot = discovered
                        DispatchQueue.main.async {
                            if self.items.isEmpty {
                                self.applyBatch(urls: snapshot, rootURL: url, initialTargetURL: initialTargetURL)
                            }
                        }
                    }
                }
            }

            // Natural alphanumeric sort so "img_2" precedes "img_10"
            let sortedURLs = discovered.sorted { a, b in
                a.path.localizedStandardCompare(b.path) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.applyFinalList(sortedURLs: sortedURLs, rootURL: url, initialTargetURL: initialTargetURL)
                self.isScanning = false
                self.delegate?.sequenceManagerDidFinishScanning(self)
            }
        }

        self.scanWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func applyBatch(urls: [URL], rootURL: URL, initialTargetURL: URL?) {
        let newItems = urls.map { ImageItem(url: $0, rootURL: rootURL) }
        self.items = newItems
        if !self.items.isEmpty && self.currentItem == nil {
            self.currentIndex = 0
            self.delegate?.sequenceManager(self, didChangeIndex: self.currentIndex, item: self.items.first)
            self.preloadNeighbors()
        }
        self.delegate?.sequenceManager(self, didUpdateList: self.items.count)
    }

    private func applyFinalList(sortedURLs: [URL], rootURL: URL, initialTargetURL: URL?) {
        self.items = sortedURLs.map { ImageItem(url: $0, rootURL: rootURL) }

        if let target = initialTargetURL,
           let matchIndex = self.items.firstIndex(where: { $0.url.standardizedFileURL.path == target.standardizedFileURL.path }) {
            self.currentIndex = matchIndex
        } else if self.currentIndex >= self.items.count {
            self.currentIndex = max(0, self.items.count - 1)
        } else if initialTargetURL == nil {
            self.currentIndex = 0
        }

        self.delegate?.sequenceManager(self, didUpdateList: self.items.count)
        self.delegate?.sequenceManager(self, didChangeIndex: self.currentIndex, item: self.currentItem)
        self.preloadNeighbors()
    }

    // MARK: - Navigation
    @discardableResult
    public func next() -> Bool {
        guard hasNext else { return false }
        currentIndex += 1
        delegate?.sequenceManager(self, didChangeIndex: currentIndex, item: currentItem)
        preloadNeighbors()
        return true
    }

    @discardableResult
    public func previous() -> Bool {
        guard hasPrevious else { return false }
        currentIndex -= 1
        delegate?.sequenceManager(self, didChangeIndex: currentIndex, item: currentItem)
        preloadNeighbors()
        return true
    }

    public func goToIndex(_ index: Int) {
        guard index >= 0, index < items.count, index != currentIndex else { return }
        currentIndex = index
        delegate?.sequenceManager(self, didChangeIndex: currentIndex, item: currentItem)
        preloadNeighbors()
    }

    public func first() {
        guard !items.isEmpty, currentIndex != 0 else { return }
        currentIndex = 0
        delegate?.sequenceManager(self, didChangeIndex: currentIndex, item: currentItem)
        preloadNeighbors()
    }

    public func last() {
        guard !items.isEmpty, currentIndex != items.count - 1 else { return }
        currentIndex = items.count - 1
        delegate?.sequenceManager(self, didChangeIndex: currentIndex, item: currentItem)
        preloadNeighbors()
    }

    // MARK: - Image Loading & Cache
    public func loadImage(for item: ImageItem, completion: @escaping (NSImage?) -> Void) {
        let key = item.url.path as NSString
        if let cached = memoryCache.object(forKey: key) {
            completion(cached)
            return
        }

        loadQueue.async { [weak self] in
            guard let self = self else { return }
            let image = NSImage(contentsOf: item.url)
            
            if let img = image {
                let cost = Int(img.size.width * img.size.height * 4)
                self.memoryCache.setObject(img, forKey: key, cost: cost)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    private func preloadNeighbors() {
        let indicesToPreload = [currentIndex + 1, currentIndex - 1, currentIndex + 2]
        for idx in indicesToPreload where idx >= 0 && idx < items.count {
            let item = items[idx]
            let key = item.url.path as NSString
            if memoryCache.object(forKey: key) == nil {
                loadQueue.async { [weak self] in
                    guard let self = self else { return }
                    if let img = NSImage(contentsOf: item.url) {
                        let cost = Int(img.size.width * img.size.height * 4)
                        self.memoryCache.setObject(img, forKey: key, cost: cost)
                    }
                }
            }
        }
    }
}
