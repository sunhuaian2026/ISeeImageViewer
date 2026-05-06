import Foundation

enum BuiltInSmartFolders {

    /// All built-ins in display order. Slice A: 1 only. Slice B+C will add "本周新增".
    static let all: [SmartFolder] = [allRecent]

    static let allRecent: SmartFolder = SmartFolder(
        id: "all-recent",
        displayName: "全部最近",
        predicate: .and([
            .atom(.init(field: .managed, op: .eq, value: .bool(true))),
            .atom(.init(field: .hidden, op: .eq, value: .bool(false))),
            .atom(.init(field: .dedupCanonicalOrNull, op: .eq, value: .bool(true)))
        ]),
        sortBy: .birthTime,
        sortDescending: true,
        isBuiltIn: true
    )
}
