import Foundation
import ImageIO
import CoreGraphics

public struct ImageItem: Equatable, Identifiable {
    public let id: String
    public let url: URL
    public let filename: String
    public let relativePath: String
    public let fileSize: Int64
    public let formatName: String

    public init(url: URL, rootURL: URL? = nil) {
        self.id = url.path
        self.url = url
        self.filename = url.lastPathComponent
        
        if let root = rootURL {
            let rootPath = root.standardizedFileURL.path
            let fullPath = url.standardizedFileURL.path
            if fullPath.hasPrefix(rootPath) {
                var rel = String(fullPath.dropFirst(rootPath.count))
                if rel.hasPrefix("/") { rel.removeFirst() }
                self.relativePath = rel.isEmpty ? url.lastPathComponent : rel
            } else {
                self.relativePath = url.lastPathComponent
            }
        } else {
            self.relativePath = url.lastPathComponent
        }

        let ext = url.pathExtension.uppercased()
        self.formatName = ext.isEmpty ? "IMG" : ext

        var size: Int64 = 0
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let s = values.fileSize {
            size = Int64(s)
        }
        self.fileSize = size
    }

    public var formattedFileSize: String {
        guard fileSize > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    public func readDimensions() -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        var width = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        var height = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        if orientation >= 5 && orientation <= 8 {
            swap(&width, &height)
        }
        if width > 0 && height > 0 {
            return CGSize(width: width, height: height)
        }
        return nil
    }

    public static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        return lhs.url.standardizedFileURL.path == rhs.url.standardizedFileURL.path
    }
}
