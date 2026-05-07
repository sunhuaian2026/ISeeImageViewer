//
//  ImageInspectorView.swift
//  Glance
//

import SwiftUI

struct ImageInspectorView: View {
    let url: URL?
    @StateObject private var viewModel = ImageInspectorViewModel()

    var body: some View {
        Group {
            if url == nil {
                ContentUnavailableView(
                    "未选择图片",
                    systemImage: "info.circle",
                    description: Text("双击图片查看元信息")
                )
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let info = viewModel.info {
                infoForm(info)
            } else {
                ContentUnavailableView(
                    "无法读取元信息",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .task(id: url) {
            guard let url else { viewModel.cancel(); return }
            await viewModel.load(url: url)
        }
        .onDisappear { viewModel.cancel() }
        // 边线绑定到 Inspector 视图本身，跟随 .move(.trailing)+.opacity transition
        // 同步出入，避免 ContentView 里独立 Divider 与 Inspector 动画不同步
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DS.Color.separatorColor)
                .frame(width: DS.Inspector.separatorWidth)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func infoForm(_ info: ImageInfo) -> some View {
        Form {
            Section("文件信息") {
                LabeledContent("文件名", value: info.fileName)
                LabeledContent("尺寸", value: info.dimensions)
                LabeledContent("修改日期", value: info.modifiedDate)
                LabeledContent("大小", value: info.fileSize)
                if let cs = info.colorSpace {
                    LabeledContent("色彩空间", value: cs)
                }
            }

            if info.cameraMake != nil || info.cameraModel != nil || info.lensModel != nil {
                Section("相机") {
                    if let make = info.cameraMake { LabeledContent("品牌", value: make) }
                    if let model = info.cameraModel { LabeledContent("型号", value: model) }
                    if let lens = info.lensModel { LabeledContent("镜头", value: lens) }
                }
            }

            if info.aperture != nil || info.shutterSpeed != nil || info.iso != nil || info.focalLength != nil {
                Section("拍摄参数") {
                    if let taken = info.dateTaken { LabeledContent("拍摄时间", value: taken) }
                    if let ap = info.aperture { LabeledContent("光圈", value: ap) }
                    if let ss = info.shutterSpeed { LabeledContent("快门", value: ss) }
                    if let iso = info.iso { LabeledContent("ISO", value: iso) }
                    if let fl = info.focalLength { LabeledContent("焦距", value: fl) }
                    if let ev = info.exposureBias { LabeledContent("曝光补偿", value: ev) }
                }
            }

            if let gps = info.gps {
                Section("位置") {
                    LabeledContent("GPS", value: gps)
                }
            }
        }
        .formStyle(.grouped)
    }
}
