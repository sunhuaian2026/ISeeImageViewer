import Foundation
import SwiftUI
import Combine

@MainActor
final class SmartFolderStore: ObservableObject {

    @Published var availableSmartFolders: [SmartFolder] = BuiltInSmartFolders.all
    @Published var selected: SmartFolder?
    @Published var queryResult: [IndexedImage] = []
    @Published var isQuerying: Bool = false
    @Published var lastError: String?

    /// Optional engine：A.17 用 placeholder()/attach 模式让 ContentView 可在 IndexStore
    /// 异步 ready 之前先创建 store；ready 后调 attach(engine:) 完成 wire-up。
    /// Slice I 重构候选项：改为 enum state（loading/ready/failed）。
    var engine: SmartFolderEngine?

    init(engine: SmartFolderEngine?) {
        self.engine = engine
    }

    /// Pre-IndexStore-ready 占位实例。ContentView wireIfReady() 后调 attach(engine:)
    /// 把真实 engine 接进来。
    static func placeholder() -> SmartFolderStore {
        SmartFolderStore(engine: nil)
    }

    func attach(engine: SmartFolderEngine) {
        self.engine = engine
    }

    /// Select a smart folder and refresh its query result.
    func select(_ folder: SmartFolder?) async {
        selected = folder
        await refreshSelected()
    }

    /// Re-execute the currently-selected smart folder query.
    func refreshSelected() async {
        guard let folder = selected, let eng = engine else {
            queryResult = []
            return
        }
        isQuerying = true
        lastError = nil
        defer { isQuerying = false }

        // Capture engine into local before detach to avoid capturing self in @Sendable closure
        let capturedEngine = eng
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try capturedEngine.execute(folder)
            }.value
            queryResult = result
        } catch {
            lastError = "\(error)"
            queryResult = []
        }
    }
}
