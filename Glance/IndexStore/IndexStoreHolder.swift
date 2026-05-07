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
