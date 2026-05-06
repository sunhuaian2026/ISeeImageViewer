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

    let engine: SmartFolderEngine

    init(engine: SmartFolderEngine) {
        self.engine = engine
    }

    /// Select a smart folder and refresh its query result.
    func select(_ folder: SmartFolder?) async {
        selected = folder
        await refreshSelected()
    }

    /// Re-execute the currently-selected smart folder query.
    func refreshSelected() async {
        guard let folder = selected else {
            queryResult = []
            return
        }
        isQuerying = true
        lastError = nil
        defer { isQuerying = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) { [engine] in
                try engine.execute(folder)
            }.value
            queryResult = result
        } catch {
            lastError = "\(error)"
            queryResult = []
        }
    }
}
