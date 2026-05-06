import Foundation

final class SmartFolderEngine {

    let store: IndexStore

    init(store: IndexStore) {
        self.store = store
    }

    func execute(_ folder: SmartFolder, now: Date = Date(), limit: Int? = nil) throws -> [IndexedImage] {
        let compiled = try SmartFolderQueryBuilder.compile(folder, now: now)
        return try store.fetch(compiled, limit: limit)
    }
}
