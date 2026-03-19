//
//  InspectorPlaceholderView.swift
//  ISeeImageViewer
//

import SwiftUI
import ImageIO

struct InspectorPlaceholderView: View {
    let url: URL?
    @State private var info: BasicFileInfo? = nil

    var body: some View {
        Group {
            if url != nil {
                if let info {
                    Form {
                        Section("文件信息") {
                            LabeledContent("文件名", value: info.name)
                            LabeledContent("尺寸", value: info.dimensions)
                            LabeledContent("修改日期", value: info.modified)
                            LabeledContent("大小", value: info.size)
                        }
                    }
                    .formStyle(.grouped)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "未选择图片",
                    systemImage: "info.circle",
                    description: Text("双击图片查看元信息")
                )
            }
        }
        .task(id: url) {
            guard let url else { info = nil; return }
            info = nil
            info = await loadBasicFileInfo(url: url)
        }
    }
}

// MARK: - Model

struct BasicFileInfo {
    let name: String
    let dimensions: String
    let modified: String
    let size: String
}

// MARK: - Loading

private func loadBasicFileInfo(url: URL) async -> BasicFileInfo? {
    await Task.detached(priority: .utility) {
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

        var dimensions = "未知"
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            dimensions = "\(w) × \(h)"
        }

        return BasicFileInfo(
            name: url.lastPathComponent,
            dimensions: dimensions,
            modified: modStr,
            size: sizeStr
        )
    }.value
}
