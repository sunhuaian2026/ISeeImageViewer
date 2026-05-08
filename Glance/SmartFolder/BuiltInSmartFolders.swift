import Foundation

enum BuiltInSmartFolders {

    /// All built-ins in display order. Slice A: 全部最近。Slice B-β: + 本周新增。
    static let all: [SmartFolder] = [allRecent, thisWeekAdded]

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

    /// 「本周新增」— 最近 7 天内 birth_time 落入的图（滑动窗口，不是自然周）。
    /// 与 D4 时间分段段头"本周"（Calendar.firstDayOfWeek）双轨语义清晰：
    ///   - 此 SF：滑窗 -7d/now，跨自然周边界仍连续
    ///   - D4 段头：自然周边界 + 段标题文案
    static let thisWeekAdded: SmartFolder = SmartFolder(
        id: "this-week-added",
        displayName: "本周新增",
        predicate: .and([
            .atom(.init(field: .managed, op: .eq, value: .bool(true))),
            .atom(.init(field: .hidden, op: .eq, value: .bool(false))),
            .atom(.init(field: .dedupCanonicalOrNull, op: .eq, value: .bool(true))),
            .atom(.init(
                field: .birthTime,
                op: .betweenDuration,
                value: .relativeTimeRange(start: "-7d", end: "now")
            ))
        ]),
        sortBy: .birthTime,
        sortDescending: true,
        isBuiltIn: true
    )
}
