//
//  ImageInspectorViewModel.swift
//  Glance
//

import Foundation
import AppKit
import ImageIO
import Combine

struct ImageInfo {
    // 基础
    let fileName: String
    let fileSize: String
    let modifiedDate: String
    let dimensions: String
    let colorSpace: String?

    // EXIF（相机拍摄才有）
    let dateTaken: String?
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let aperture: String?
    let shutterSpeed: String?
    let iso: String?
    let focalLength: String?
    let exposureBias: String?
    let gps: String?
}

class ImageInspectorViewModel: ObservableObject {
    @Published var info: ImageInfo?
    @Published var isLoading = false

    private var loadTask: Task<Void, Never>?

    func load(url: URL) async {
        loadTask?.cancel()
        info = nil
        isLoading = true

        loadTask = Task {
            let result: ImageInfo? = await Task.detached(priority: .utility) {
                Self.readInfo(from: url)
            }.value
            guard !Task.isCancelled else { return }
            info = result
            isLoading = false
        }
        await loadTask?.value
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Private

    private nonisolated static func readInfo(from url: URL) -> ImageInfo? {
        // 文件属性
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let res = try? url.resourceValues(forKeys: keys) else { return nil }

        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteFormatter.countStyle = .file
        let sizeStr = byteFormatter.string(fromByteCount: Int64(res.fileSize ?? 0))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let modStr = res.contentModificationDate.map { dateFormatter.string(from: $0) } ?? "未知"

        // CGImageSource 属性
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        let w = props[kCGImagePropertyPixelWidth] as? Int
        let h = props[kCGImagePropertyPixelHeight] as? Int
        let dimensions = (w != nil && h != nil) ? "\(w!) × \(h!)" : "未知"
        let colorSpace = props[kCGImagePropertyColorModel] as? String

        // EXIF
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gpsDict = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let dateTaken = exif?[kCGImagePropertyExifDateTimeOriginal] as? String

        let aperture: String? = {
            guard let f = exif?[kCGImagePropertyExifFNumber] as? Double else { return nil }
            return String(format: "f/%.1f", f)
        }()

        let shutterSpeed: String? = {
            guard let exp = exif?[kCGImagePropertyExifExposureTime] as? Double, exp > 0 else { return nil }
            if exp >= 1 { return String(format: "%.1fs", exp) }
            return "1/\(Int((1.0 / exp).rounded()))s"
        }()

        let iso: String? = {
            guard let isoArr = exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int],
                  let first = isoArr.first else { return nil }
            return "ISO \(first)"
        }()

        let focalLength: String? = {
            guard let fl = exif?[kCGImagePropertyExifFocalLength] as? Double else { return nil }
            return "\(Int(fl))mm"
        }()

        let exposureBias: String? = {
            guard let ev = exif?[kCGImagePropertyExifExposureBiasValue] as? Double else { return nil }
            return String(format: "%+.1f EV", ev)
        }()

        let gps: String? = {
            guard let lat = gpsDict?[kCGImagePropertyGPSLatitude] as? Double,
                  let latRef = gpsDict?[kCGImagePropertyGPSLatitudeRef] as? String,
                  let lon = gpsDict?[kCGImagePropertyGPSLongitude] as? Double,
                  let lonRef = gpsDict?[kCGImagePropertyGPSLongitudeRef] as? String else { return nil }
            return String(format: "%.4f°%@ %.4f°%@", lat, latRef, lon, lonRef)
        }()

        return ImageInfo(
            fileName: url.lastPathComponent,
            fileSize: sizeStr,
            modifiedDate: modStr,
            dimensions: dimensions,
            colorSpace: colorSpace,
            dateTaken: dateTaken,
            cameraMake: tiff?[kCGImagePropertyTIFFMake] as? String,
            cameraModel: tiff?[kCGImagePropertyTIFFModel] as? String,
            lensModel: exif?[kCGImagePropertyExifLensModel] as? String,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            iso: iso,
            focalLength: focalLength,
            exposureBias: exposureBias,
            gps: gps
        )
    }
}
