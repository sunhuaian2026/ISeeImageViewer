//
//  IndexStoreHolder.swift
//  Glance
//
//  异步包装可能 throw 的 IndexStore 初始化。让 ContentView 通过
//  .onChange(of: isReady) 观察 Bool（IndexStore 是 class 不 Equatable，
//  无法直接 .onChange(of: store)）触发 wireIfReady。
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class IndexStoreHolder: ObservableObject {
    @Published var store: IndexStore?
    @Published var initError: String?
    @Published var isReady: Bool = false

    /// Slice I.1 — 当前正在扫描的 root 进度（nil = 无扫描运行）。bridge 在 scan 启动时
    /// set，onProgress callback 更新，scan 完成或失败 clear。
    @Published var progress: IndexingProgress?

    /// Slice I.2 — 最近一次 scan / dedup / FSEvents 操作错误（nil = 无错误）。
    /// ContentView overlay 红色 banner 展示；用户 dismiss → set nil。
    @Published var lastError: String?

    /// Slice I.2 — 用户点 progress chip 上的 X 触发取消当前扫描（cancel 当前 scan task）。
    /// bridge 在 scan task 创建时 capture，holder 通过此 closure 转发取消信号。
    var cancelCurrentScan: (() -> Void)?

    init() {
        Task { await self.bootstrap() }
    }

    private func bootstrap() async {
        do {
            let s = try IndexStore()
            self.store = s
            self.isReady = true
        } catch {
            self.initError = "\(error)"
            print("[IndexStoreHolder] init failed: \(error)")
        }
    }
}
