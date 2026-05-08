import Foundation
import SwiftUI
import Combine

@MainActor
final class SmartFolderStore: ObservableObject {

    @Published var availableSmartFolders: [SmartFolder] = BuiltInSmartFolders.all

    /// Slice I.3 — 单一状态机替代 selected/queryResult/isQuerying/lastError 四独立字段。
    /// 无效组合（如 isQuerying=true 同时 queryResult 非空）从结构上不可表达。
    @Published var state: SmartFolderState = .idle

    /// Optional engine：A.17 placeholder()/attach 模式让 ContentView 可在 IndexStore
    /// 异步 ready 之前先创建 store；ready 后调 attach(engine:) 完成 wire-up。
    var engine: SmartFolderEngine?

    init(engine: SmartFolderEngine?) {
        self.engine = engine
    }

    static func placeholder() -> SmartFolderStore {
        SmartFolderStore(engine: nil)
    }

    func attach(engine: SmartFolderEngine) {
        self.engine = engine
    }

    // MARK: - 兼容旧 API 的 computed accessors（views / ContentView 直接读不变）

    var selected: SmartFolder? {
        switch state {
        case .idle: return nil
        case .loading(let f), .loaded(let f, _), .error(let f, _): return f
        }
    }

    var queryResult: [IndexedImage] {
        if case .loaded(_, let imgs) = state { return imgs }
        return []
    }

    var isQuerying: Bool {
        if case .loading = state { return true }
        return false
    }

    var lastError: String? {
        if case .error(_, let msg) = state { return msg }
        return nil
    }

    // MARK: - State transitions

    /// Select a smart folder and refresh its query result. nil → state .idle。
    func select(_ folder: SmartFolder?) async {
        guard let folder else {
            state = .idle
            return
        }
        state = .loading(folder)
        await runQuery(for: folder)
    }

    /// Re-execute the currently-selected smart folder query.
    func refreshSelected() async {
        guard let folder = selected else { return }
        state = .loading(folder)
        await runQuery(for: folder)
    }

    /// 运行 query + 处理 stale-write（query 跑过程中用户已切到别的 SF / 清 selection）。
    private func runQuery(for folder: SmartFolder) async {
        guard let eng = engine else { return }
        let captured = eng
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try captured.execute(folder)
            }.value
            // Stale-write guard：仅当当前 state 仍指向同一 folder 才写回结果
            if case .loading(let cur) = state, cur.id == folder.id {
                state = .loaded(folder, result)
            }
        } catch {
            if case .loading(let cur) = state, cur.id == folder.id {
                state = .error(folder, "\(error)")
            }
        }
    }
}
