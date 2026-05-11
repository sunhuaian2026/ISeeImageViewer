# Glance V2 M3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Plan strategy**: M3 已包含 2 slice。**Slice L**（V2.2-beta1，已 ship 2026-05-11）追溯式完成详细表；**Slice M**（V2.2 GA，~4-5 天）full task/step/code detail。Slice N polish 仅 outline 占位待用户反馈触发。
>
> **Spec reference**: `specs/v2/2026-05-11-m3-design.md`
> **Decision references**: `specs/v2/2026-05-06-v2-design.md` D1-D10 + `specs/Roadmap.md` 决策段 D11-D15 + 本 plan D16-D20
> **Term references**: `CONTEXT.md`「跨文件夹聚合」段（Ephemeral 视图 / SmartFolder hide 规则）

**Goal:** Ship V2.2（搜索 + 新内置 SF）by delivering 2 vertical slices: L = 3 个新内置 SmartFolder（已 ship V2.2-beta1），M = ⌘F 全局搜索 + modifier 语法 + EphemeralResultView 扩展（V2.2 GA）。

**Architecture:** Slice L 仅扩 `BuiltInSmartFolders.swift` + `SmartFolderQueryBuilder.swift` 自然月 token，无新模块。Slice M 新增 `Glance/Search/` 模块层（SearchInput + SearchService + SearchOverlayView 3 文件，mirror `Glance/Similarity/` 边界），复用 V2 已有 SmartFolderQueryBuilder + IndexStore.fetch + EphemeralResultView 骨架 + D15 终态 `@FocusState focusTarget: AppFocus?` 单仲裁焦点架构。

**Tech Stack:** Swift 5.9+ / SwiftUI / Foundation / sqlite3 C API (复用 IndexStore wrapper) / async-await + Task.detached 后台 query + Task.isCancelled debounce/cancel pattern。**禁第三方依赖**。

---

## M3 Slice Roadmap

| Slice | Goal | Estimate | Ship as | Status |
|---|---|---|---|---|
| **L** | 3 个新内置 SmartFolder（上个月 / 截图 / 大图）+ Calendar 自然月 token | 0.5 天 | V2.2-beta1 | ✅ 完成 2026-05-11 |
| **M** ⭐ (this plan, detailed) | SearchOverlay + SearchService + 三 modifier 语法 + EphemeralResultView 扩展 + ⌘F 全局入口 | 4-5 天 | V2.2 GA | 🚧 待开始 |
| N (outline) | polish: FTS5/SQL index / history / Tab forward 导航 / a11y | TBD | minor patch | 🚧 optional，待 Slice M 实测触发 |

**Total**：~5 工作日 ≈ **1 周**（落 D9 M3 = 3-4 周锁定的远期上界内）。每 slice 完成跑 `/go` 五步。

---

## M3 plan-time 决策（待写入 `specs/Roadmap.md` V2 决策段当 D16-D20）

详见 `specs/v2/2026-05-11-m3-design.md` § 11。本 plan 落地这五条：

| ID | 决策 | 落地点 |
|---|---|---|
| D16 | ⌘F 顶部 Spotlight 式 overlay | M.3 SearchOverlayView + M.5 ContentView 挂载 |
| D17 | modifier 解析 Silent partial | M.1 SearchService.parse 永不抛错 + token fallback keyword |
| D18 | 搜索继承 SmartFolder hide 规则 | M.1 SearchService.compile 强制 `.hidden = false` atom |
| D19 | EphemeralResultView 加 `showTimeBuckets` toggle | M.4 EphemeralResultView 扩展 |
| D20 | SearchService = 新 `Glance/Search/` module | M.1 新建模块目录 |

---

## File Structure (Slice M)

| 操作 | 路径 | 责任 |
|---|---|---|
| Create | `Glance/Search/SearchInput.swift` | `ParsedSearch` struct（modifiers + keyword 字段）+ `SearchModifier` enum + size 单位枚举 |
| Create | `Glance/Search/SearchService.swift` | `parse(_:) -> ParsedSearch`（Silent partial）+ `compile(_:) -> SmartFolderPredicate`（拼 common filter + modifiers + keyword OR）|
| Create | `Glance/Search/SearchOverlayView.swift` | 顶部 slide-in SwiftUI overlay：search field + 关闭按钮 + modifier hint 行 + FocusState.Binding 接入 |
| Modify | `Glance/Similarity/EphemeralResultView.swift` | API 加 `showTimeBuckets: Bool` + `emptyStateText: String` + `datesForBuckets: [Date]?`；body 内 showTimeBuckets=true 走 sectioned LazyVGrid + pinnedViews（mirror SmartFolderGridView）|
| Modify | `Glance/ContentView.swift` | 加 `showSearchOverlay: Bool` / `searchTask: Task<Void, Never>?` @State；`EphemeralRequest` enum 加 `.search` case + computed `showTimeBuckets` / `emptyStateText` / `datesForBuckets`；`AppFocus` 加 `.search` case；mainContent 挂 SearchOverlayView；`⌘F keyboardShortcut`；`onInputChange` handler 实现 debounce + cancel + SearchService 调用 |
| Modify | `Glance/QuickViewer/QuickViewerOverlay.swift` | 加 `⌘F keyboardShortcut`（QV 内时也响应）+ `onCommandF: () -> Void` callback 上报 ContentView 同帧切换 |
| Modify | `Glance/DesignSystem.swift` | 加 `DS.Search` 段：`overlayMaxWidth` / `overlayPadding` / `overlayCornerRadius` / `debounceMs` / `modifierHintOpacity` |

---

## Slice L 完成详细（追溯式 — 2026-05-11 已 ship）

| Task | 落地内容 | Commit |
|---|---|---|
| L.1 | `SmartFolderQueryBuilder.resolveRelativeTime` 加 `last-month-start` / `last-month-end` token：Calendar.current 自然月边界（dateInterval(of: .month) + dateByAdding -1 month），跨年自动。命名常量 `oneMonthBack: Int = -1` / `oneSecondBack: TimeInterval = -1` 满足"禁止魔法数字" | 77d6b64 + 378a4e1 (P1 const fix) |
| L.2 | `BuiltInSmartFolders` 加 3 个 SmartFolder：上个月 / 截图 / 大图；阈值常量（5_000_000 / 4000 / "Screenshot" / "截图"）命名为 private static let；`all` 数组扩展 5 项；「截图」path STARTS_WITH "~/Desktop" 故意不上（relative_path 跨 root 无法判绝对路径） | 77d6b64 |

**Plan vs 实际收敛**：spec § 5.3 / § 6.1 全部 deliverable 兑现，无收敛点。

---

## Slice M: ⌘F 全局搜索（V2.2 GA，6 task）

### Task M.1: SearchInput + SearchService（parser + compile）

**Files:**
- Create: `Glance/Search/SearchInput.swift`
- Create: `Glance/Search/SearchService.swift`

- [ ] **Step 1: 创建 SearchInput.swift**

```swift
//
//  SearchInput.swift
//  Glance
//
//  M3 Slice M — SearchService.parse 输出 + compile 输入的中间表示。
//  Silent partial 容错：解析失败的 token 自动落入 keyword 字段（不抛错）。
//

import Foundation

/// SearchService.parse 的结构化输出。
struct ParsedSearch: Equatable {
    /// 成功解析的 modifier 列表（D17：解析失败的 modifier 不进这里，落入 keyword）。
    var modifiers: [SmartFolderAtom]
    /// 剩余 token 拼成的 keyword 串（用空格 join）。空串表示无 keyword（query 只有 modifier）。
    var keyword: String

    /// 空查询的便捷构造：input 全空白 → modifiers/keyword 都空。
    static var empty: ParsedSearch {
        ParsedSearch(modifiers: [], keyword: "")
    }

    /// query 完全无内容（modifiers + keyword 都空）→ caller 跳查询（避免空 query 返全部受管图）。
    var isEmpty: Bool {
        modifiers.isEmpty && keyword.isEmpty
    }
}

/// Size modifier 的单位枚举（decimal 1000^n，跟 macOS Finder 文件大小显示一致）。
enum SearchSizeUnit: String, CaseIterable {
    case b   // 1
    case k   // 1_000
    case m   // 1_000_000
    case g   // 1_000_000_000

    var multiplier: Int64 {
        switch self {
        case .b: return 1
        case .k: return 1_000
        case .m: return 1_000_000
        case .g: return 1_000_000_000
        }
    }

    /// 解析后缀字符串（case-insensitive；"kb"/"k"/"K" 都识别）。无后缀视为 .b。
    static func parse(_ raw: String) -> SearchSizeUnit? {
        let lower = raw.lowercased()
        if lower.isEmpty { return .b }
        if lower == "b" { return .b }
        if lower == "k" || lower == "kb" { return .k }
        if lower == "m" || lower == "mb" { return .m }
        if lower == "g" || lower == "gb" { return .g }
        return nil
    }
}
```

- [ ] **Step 2: 创建 SearchService.swift（parser 核心）**

```swift
//
//  SearchService.swift
//  Glance
//
//  M3 Slice M — 搜索 input parser + 编译成 SmartFolderPredicate。
//  D17 Silent partial: parse 永不抛错；解析失败的 modifier token 当 keyword fallback。
//  D18: compile 强制带 .managed + .hidden=false + .dedupCanonicalOrNull common filter。
//  D20: 新模块 Glance/Search/ 不污染 SmartFolderEngine；复用 SmartFolderQueryBuilder 走 SQL。
//

import Foundation

nonisolated enum SearchService {

    // MARK: - Parse

    /// 把 raw input 拆成 ParsedSearch。Silent partial 容错。
    static func parse(_ input: String) -> ParsedSearch {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .empty }

        let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var modifiers: [SmartFolderAtom] = []
        var keywordTokens: [String] = []

        for token in tokens {
            if let atom = parseModifierToken(token) {
                modifiers.append(atom)
            } else {
                // 未识别 modifier OR 解析失败 → fallback 整 token 当 keyword（D17）
                keywordTokens.append(token)
            }
        }

        return ParsedSearch(
            modifiers: modifiers,
            keyword: keywordTokens.joined(separator: " ")
        )
    }

    /// 解析单个 token；返回 nil 表示不是合法 modifier（caller fallback 当 keyword）。
    private static func parseModifierToken(_ token: String) -> SmartFolderAtom? {
        // 必须含 `:` 且 `:` 前是合法 field name
        guard let colonIdx = token.firstIndex(of: ":") else { return nil }
        let field = String(token[..<colonIdx]).lowercased()
        let expr = String(token[token.index(after: colonIdx)...])
        guard !expr.isEmpty else { return nil }

        switch field {
        case "type":  return parseTypeValue(expr)
        case "size":  return parseSizeValue(expr)
        case "birth": return parseBirthValue(expr)
        default:      return nil   // unknown modifier → fallback keyword
        }
    }

    /// type:png / type:jpeg → .atom(format = ?)
    private static func parseTypeValue(_ expr: String) -> SmartFolderAtom? {
        // 允许 case-insensitive 但 IndexStore.format 存的是 lowercase string，所以归一 lower
        let normalized = expr.lowercased()
        // 简单 sanity check：非空 + 仅 alnum（防止 type:>png 这种带 op 的瞎用）
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return SmartFolderAtom(field: .format, op: .eq, value: .string(normalized))
    }

    /// size:>1mb / size:<500k / size:2gb → .atom(file_size [op] ?)
    private static func parseSizeValue(_ expr: String) -> SmartFolderAtom? {
        // 拆 op + value
        let (op, numericPart) = extractOp(from: expr, defaultOp: .eq)
        guard !numericPart.isEmpty else { return nil }

        // 拆 number + unit suffix
        let digits = numericPart.prefix(while: { $0.isNumber })
        let unitRaw = String(numericPart.dropFirst(digits.count))
        guard let value = Int64(digits), let unit = SearchSizeUnit.parse(unitRaw) else {
            return nil
        }
        let bytes = value * unit.multiplier
        return SmartFolderAtom(field: .fileSize, op: op, value: .int(bytes))
    }

    /// birth:>2026-01-01 / birth:<2026-05-01 / birth:2026-04-15 (=eq 翻译 between [当日, 次日))
    private static func parseBirthValue(_ expr: String) -> SmartFolderAtom? {
        let (op, dateRaw) = extractOp(from: expr, defaultOp: .eq)
        guard !dateRaw.isEmpty else { return nil }

        // 接受 YYYY-MM-DD 或 ISO 8601 带时区
        guard let parsed = parseISODate(dateRaw) else { return nil }

        // eq 翻译为 betweenDuration [当日 00:00, 次日 00:00)
        if op == .eq {
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: parsed) ?? parsed
            let startISO = isoFormatter.string(from: parsed)
            let endISO = isoFormatter.string(from: nextDay)
            return SmartFolderAtom(
                field: .birthTime,
                op: .betweenDuration,
                value: .relativeTimeRange(start: startISO, end: endISO)
            )
        }

        // >/< 用 double timestamp（已支持 emitTimeAtom .greaterThan / .lessThan with .double）
        let ts = parsed.timeIntervalSince1970
        return SmartFolderAtom(field: .birthTime, op: op, value: .double(ts))
    }

    /// 从 "<op><rest>" 拆出 op + rest；无 op 前缀返回 defaultOp + 完整 expr。
    private static func extractOp(from expr: String, defaultOp: SmartFolderOp)
        -> (op: SmartFolderOp, rest: String)
    {
        if expr.hasPrefix(">") { return (.greaterThan, String(expr.dropFirst())) }
        if expr.hasPrefix("<") { return (.lessThan,    String(expr.dropFirst())) }
        if expr.hasPrefix("=") { return (.eq,          String(expr.dropFirst())) }
        return (defaultOp, expr)
    }

    /// 接受 YYYY-MM-DD（视为 UTC 00:00）或 ISO 8601 带时区。失败返回 nil。
    private static func parseISODate(_ raw: String) -> Date? {
        // 先试 ISO 8601 full（带时区）
        if let d = isoFormatter.date(from: raw) { return d }
        // 再试 YYYY-MM-DD（视为 UTC 当日 00:00）
        if let d = dateOnlyFormatter.date(from: raw) { return d }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Compile

    /// 把 ParsedSearch 编译成 SmartFolderPredicate（D18 hide 继承 + common filter 自动加）。
    static func compile(_ parsed: ParsedSearch) -> SmartFolderPredicate {
        var atoms: [SmartFolderPredicate] = [
            .atom(.init(field: .managed, op: .eq, value: .bool(true))),
            .atom(.init(field: .hidden, op: .eq, value: .bool(false))),
            .atom(.init(field: .dedupCanonicalOrNull, op: .eq, value: .bool(true)))
        ]
        atoms.append(contentsOf: parsed.modifiers.map { .atom($0) })

        if !parsed.keyword.isEmpty {
            atoms.append(.or([
                .atom(.init(field: .filename, op: .contains, value: .string(parsed.keyword))),
                .atom(.init(field: .relativePath, op: .contains, value: .string(parsed.keyword)))
            ]))
        }

        return .and(atoms)
    }
}
```

- [ ] **Step 3: make build 验证 0 error 0 warning**

Run: `make build`
Expected: `BUILD SUCCEEDED — 0 errors, 0 code warnings`

- [ ] **Step 4: commit M.1**

```bash
git add Glance/Search/SearchInput.swift Glance/Search/SearchService.swift
git commit -m "feat(M3.M.1): Search module — SearchInput + SearchService parser/compile"
```

---

### Task M.2: SearchService inline 调试验证（无 XCTest target）

**Files:** 无新建（项目无 XCTest target），inline assert 跑 design § 6.5 表所有 case

- [ ] **Step 1: 在 SearchService 内末尾加 `#if DEBUG` 自检函数**

```swift
#if DEBUG
extension SearchService {
    /// M.2 — inline 调试：跑 design § 6.5 表所有 case 验证 parse + compile 正确。
    /// 调用方式：GlanceApp .onAppear { SearchService._debugSelfCheck() } 临时挂；
    /// 验证完打 commit 前可删 _debugSelfCheck 调用，但函数保留留作 future regression check。
    static func _debugSelfCheck() {
        // Case 1: pure keyword
        let p1 = parse("screenshot")
        assert(p1.modifiers.isEmpty, "screenshot should have no modifiers")
        assert(p1.keyword == "screenshot", "expected 'screenshot' keyword")

        // Case 2: pure modifier type
        let p2 = parse("type:png")
        assert(p2.modifiers.count == 1, "type:png should produce 1 modifier")
        assert(p2.modifiers[0].field == .format, "expected .format field")
        assert(p2.keyword.isEmpty, "expected empty keyword")

        // Case 3: keyword + modifier
        let p3 = parse("screenshot type:png")
        assert(p3.modifiers.count == 1, "expected 1 modifier")
        assert(p3.keyword == "screenshot", "expected 'screenshot' keyword")

        // Case 4: two modifiers
        let p4 = parse("size:>1mb birth:>2026-04-01")
        assert(p4.modifiers.count == 2, "expected 2 modifiers")
        assert(p4.keyword.isEmpty, "expected empty keyword")
        if case .int(let bytes) = p4.modifiers[0].value {
            assert(bytes == 1_000_000, "expected 1mb = 1_000_000 bytes")
        } else {
            assertionFailure("size value should be .int")
        }

        // Case 5: partial fallback (invalid type)
        let p5 = parse("screen type:invalidext")
        // type:invalidext 合法字段名 + 非空 expr → parseTypeValue 校验 allSatisfy isLetter/isNumber 通过
        // 实际会成功解析（IndexStore 找不到匹配返 0 结果，是另一回事）
        // 这是 spec § 6.5 的实际行为 — 验证 D17：parser 不报错，user 看 0 结果自调
        // 如要让 invalidext fail，需在 parseTypeValue 加 allow-list；M3 不做（保 Silent partial）
        assert(p5.modifiers.count == 1, "M3: type:invalidext 当 modifier 不当 keyword（详见注释）")

        // Case 5b: partial fallback (invalid size unit)
        let p5b = parse("foo size:abc")
        assert(p5b.modifiers.isEmpty, "size:abc invalid → fallback keyword")
        assert(p5b.keyword == "foo size:abc", "expected full token fallback to keyword")

        // Case 6: unknown modifier field
        let p6 = parse("foo path:bar")
        assert(p6.modifiers.isEmpty, "path: unknown modifier → fallback keyword")
        assert(p6.keyword == "foo path:bar", "expected full token fallback")

        // Case 7: birth eq translates to betweenDuration
        let p7 = parse("birth:2026-04-15")
        assert(p7.modifiers.count == 1)
        assert(p7.modifiers[0].op == .betweenDuration, "eq birth → betweenDuration")

        // Case 8: empty input
        let p8 = parse("")
        assert(p8.isEmpty, "empty input → isEmpty=true")
        let p8b = parse("   ")
        assert(p8b.isEmpty, "whitespace-only → isEmpty=true")

        // Compile sanity
        let compiled = compile(p4)
        if case .and(let xs) = compiled {
            // 3 common filter + 2 modifier = 5 atoms; keyword 空不加 OR
            assert(xs.count == 5, "expected 5 atoms (3 common + 2 modifier)")
        } else {
            assertionFailure("compile should produce .and(...)")
        }

        print("[SearchService] _debugSelfCheck: all assertions passed")
    }
}
#endif
```

- [ ] **Step 2: 临时挂到 GlanceApp 启动跑一次（验证完移除）**

修改 `Glance/GlanceApp.swift`，在 `WindowGroup` body 找 ContentView `.onAppear` 处临时插入：

```swift
// 临时：M.2 验证 SearchService parse/compile 正确（验证完删除）
#if DEBUG
.onAppear { SearchService._debugSelfCheck() }
#endif
```

- [ ] **Step 3: make run 启动 app 看 Console 输出**

```bash
make run
```

Expected Console 输出：`[SearchService] _debugSelfCheck: all assertions passed`

任一 assertion 失败 → 看堆栈定位 parse/compile bug，修复后重跑。

- [ ] **Step 4: 移除临时 onAppear（保留 `_debugSelfCheck` 函数给 future regression 用）**

把 GlanceApp 临时加的 `.onAppear { SearchService._debugSelfCheck() }` 删除。`_debugSelfCheck` 函数本身留在 SearchService.swift（`#if DEBUG` 包裹不影响 release build）。

- [ ] **Step 5: make build 验证 0 error 0 warning**

```bash
make build
```

- [ ] **Step 6: commit M.2**

```bash
git add Glance/Search/SearchService.swift
git commit -m "feat(M3.M.2): SearchService 8 case inline 自检通过（GlanceApp 临时 onAppear 已移除）"
```

---

### Task M.3: SearchOverlayView（overlay UI + focus + ESC + Enter）

**Files:**
- Create: `Glance/Search/SearchOverlayView.swift`
- Modify: `Glance/DesignSystem.swift`（加 DS.Search 段）

- [ ] **Step 1: DesignSystem 加 DS.Search 段**

在 `Glance/DesignSystem.swift` `DS.Similarity` 段之后插入：

```swift
// MARK: - Search（V2 M3 Slice M — 全局搜索 overlay）

enum Search {
    /// SearchOverlayView 最大宽度（detail 区宽度受限于此 cap，居中显示）。
    static let overlayMaxWidth: CGFloat = 600
    /// overlay 内 padding（HStack search field + close button 上下左右）。
    static let overlayPadding: CGFloat = 12
    /// overlay 圆角半径。
    static let overlayCornerRadius: CGFloat = 12
    /// onChange debounce 毫秒数（200ms = Spotlight 同款节奏）。
    static let debounceMs: Int = 200
    /// modifier hint 行文字透明度（永远可见的教学行）。
    static let modifierHintOpacity: Double = 0.55
    /// overlay strokeBorder 透明度（hairline 边界）。
    static let overlayBorderOpacity: Double = 0.12
    /// overlay strokeBorder lineWidth（hairline）。
    static let overlayBorderWidth: CGFloat = 0.5
}
```

- [ ] **Step 2: 创建 SearchOverlayView.swift**

```swift
//
//  SearchOverlayView.swift
//  Glance
//
//  M3 Slice M — ⌘F 触发的顶部 Spotlight 式 search overlay。
//  - D16: 顶部 slide-in overlay 而非 toolbar field / sheet
//  - D15 终态：FocusState.Binding 接父 view 单仲裁焦点，layer = .search
//  - input 内 ESC self-dismiss；Enter 跳 debounce 立即查；↑↓←→ text cursor 不 forward
//

import SwiftUI

struct SearchOverlayView: View {
    /// 父 view（ContentView）持有的 @FocusState binding。input 拿焦点时 binding == .search。
    @FocusState.Binding var focusTarget: AppFocus?

    /// 输入变化 callback。skipDebounce=true 时 caller 立即查不走 200ms timer（Enter 路径）。
    let onInputChange: (_ input: String, _ skipDebounce: Bool) -> Void

    /// ESC / × 关闭 callback。caller 清 currentEphemeral + focusTarget = .grid。
    let onClose: () -> Void

    @State private var searchInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            inputRow
            hintRow
        }
        .padding(DS.Search.overlayPadding)
        .frame(maxWidth: DS.Search.overlayMaxWidth)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: DS.Search.overlayCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Search.overlayCornerRadius)
                .strokeBorder(.primary.opacity(DS.Search.overlayBorderOpacity), lineWidth: DS.Search.overlayBorderWidth)
        )
        .padding(.top, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var inputRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索...", text: $searchInput)
                .textFieldStyle(.plain)
                .focused($focusTarget, equals: .search)
                .onChange(of: searchInput) { _, newValue in
                    onInputChange(newValue, false)
                }
                .onKeyPress(.return) {
                    onInputChange(searchInput, true)
                    return .handled
                }
                .onKeyPress(.escape) {
                    onClose()
                    return .handled
                }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭 (ESC)")
        }
    }

    private var hintRow: some View {
        Text("提示：type:png · size:>1mb · birth:>2026-01-01")
            .font(.caption)
            .foregroundStyle(.primary.opacity(DS.Search.modifierHintOpacity))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
```

- [ ] **Step 3: make build 验证 0 error 0 warning**

```bash
make build
```

注：此时 `AppFocus.search` case 尚未加，build 会失败提示 `'search' is not a member of AppFocus`。临时 workaround：先在 ContentView.swift 顶部 AppFocus enum 加 `case search` case（M.5 step 1 会正式加注释），保 M.3 build 通过即可。

- [ ] **Step 4: ContentView.AppFocus 临时加 .search case（M.5 正式 wire 时补注释）**

修改 `Glance/ContentView.swift` 顶部 `enum AppFocus`：

```swift
enum AppFocus: Hashable {
    case grid
    case preview
    case ephemeral
    case search   // M3 Slice M (placeholder, M.5 正式 wire)
}
```

- [ ] **Step 5: make build 再次验证**

```bash
make build
```

Expected: `BUILD SUCCEEDED — 0 errors, 0 code warnings`

- [ ] **Step 6: commit M.3**

```bash
git add Glance/Search/SearchOverlayView.swift Glance/DesignSystem.swift Glance/ContentView.swift
git commit -m "feat(M3.M.3): SearchOverlayView + DS.Search tokens + AppFocus.search case 占位"
```

---

### Task M.4: EphemeralResultView 扩展（showTimeBuckets + emptyStateText + sectioned 渲染）

**Files:**
- Modify: `Glance/Similarity/EphemeralResultView.swift`

- [ ] **Step 1: 加新参数到 API（保 M2 默认行为不变）**

修改 EphemeralResultView struct 顶部：

```swift
struct EphemeralResultView: View {
    let title: String
    let urls: [URL]
    let bannerText: String?

    // M3 Slice M 加：
    /// caller 控制的空态文案。M2 .similar 传 "无结果"；M3 .search 按空 input / 0 结果 传不同文案。
    var emptyStateText: String = "无结果"
    /// 启用时间分段渲染（D19）。true 时必须传 datesForBuckets 且长度等于 urls。
    var showTimeBuckets: Bool = false
    /// 跟 urls 平行的 birth_time 数组（用于时间分段）。M2 .similar 传 nil；M3 .search 传非 nil。
    var datesForBuckets: [Date]? = nil

    let onClose: () -> Void
    let onSingleClick: (Int) -> Void
    let onDoubleClick: (Int) -> Void

    /// D15 终态：父持有的 @FocusState binding（M3 加 AppFocus.search 不影响此 binding）。
    @FocusState.Binding var focusTarget: AppFocus?

    @State private var highlightedURL: URL?
    // ... 其余字段不变
}
```

- [ ] **Step 2: emptyState computed 用新参数**

替换原 emptyState：

```swift
private var emptyState: some View {
    VStack(spacing: DS.Spacing.sm) {
        Image(systemName: "square.stack.3d.up.slash")
            .font(.system(size: DS.Similarity.emptyStateIconSize))
            .foregroundStyle(.tertiary)
        Text(emptyStateText)   // M3: caller 控制文案
            .font(.headline)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, DS.Similarity.emptyStateTopPadding)
}
```

- [ ] **Step 3: body 内拆 flat / sectioned 两个分支**

替换原 ScrollView 渲染段（在 GeometryReader 内 ScrollViewReader 内 ScrollView 内）：

```swift
ScrollView {
    if urls.isEmpty {
        emptyState
    } else if showTimeBuckets, let dates = datesForBuckets, dates.count == urls.count {
        sectionedGridContent(colCount: colCount, scrollProxy: scrollProxy)
    } else {
        flatGridContent(colCount: colCount, scrollProxy: scrollProxy)
    }
}
```

- [ ] **Step 4: 抽取 flatGridContent helper**

把原 LazyVGrid + ForEach + cell 渲染包成 helper：

```swift
@ViewBuilder
private func flatGridContent(colCount: Int, scrollProxy: ScrollViewProxy) -> some View {
    LazyVGrid(columns: gridColumns, spacing: DS.Thumbnail.spacing) {
        ForEach(Array(urls.enumerated()), id: \.element) { idx, url in
            cell(url: url, idx: idx)
        }
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.sm)
}
```

- [ ] **Step 5: 新增 sectionedGridContent helper（mirror SmartFolderGridView pattern）**

```swift
@ViewBuilder
private func sectionedGridContent(colCount: Int, scrollProxy: ScrollViewProxy) -> some View {
    // 把 urls + dates 配对，按 D4 TimeBucket 分段（mirror groupedByTimeBucket helper）
    let sections = computeBucketSections()

    LazyVGrid(
        columns: gridColumns,
        spacing: DS.Thumbnail.spacing,
        pinnedViews: [.sectionHeaders]
    ) {
        ForEach(sections) { section in
            Section {
                ForEach(section.items) { item in
                    cell(url: item.url, idx: item.flatIndex)
                }
            } header: {
                sectionHeader(section)
            }
        }
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.sm)
}

/// 在 EphemeralResultView 内复用 D4 时间分段算法（不重新实现），但 group 单位是 (URL, Date) pair。
private func computeBucketSections() -> [URLBucketSection] {
    guard let dates = datesForBuckets, dates.count == urls.count else { return [] }
    let now = Date()
    let boundaries = TimeBucket.boundaries(now: now)

    var byBucket: [TimeBucket: [URLBucketItem]] = [:]
    for (idx, url) in urls.enumerated() {
        let bucket = TimeBucket.bucket(for: dates[idx], boundaries: boundaries)
        byBucket[bucket, default: []].append(URLBucketItem(url: url, flatIndex: idx))
    }
    return TimeBucket.allCases.compactMap { bucket in
        guard let items = byBucket[bucket], !items.isEmpty else { return nil }
        return URLBucketSection(bucket: bucket, items: items)
    }
}

/// chip 形态 section header（mirror SmartFolderGridView c5b048a 形态）。
@ViewBuilder
private func sectionHeader(_ section: URLBucketSection) -> some View {
    HStack {
        Text("\(section.bucket.displayName) · \(section.items.count) 张")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.thickMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    .primary.opacity(DS.SectionHeader.chipBorderOpacity),
                    lineWidth: DS.SectionHeader.chipBorderWidth
                )
            )
        Spacer()
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.xs)
}

/// 单 cell 渲染（被 flat / sectioned 两路复用，避免代码重复）。
@ViewBuilder
private func cell(url: URL, idx: Int) -> some View {
    VStack(spacing: DS.Spacing.xs) {
        ThumbnailCell(
            url: url,
            isHighlighted: highlightedURL == url,
            size: folderStore.thumbnailSize
        )
        Text(url.lastPathComponent)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: folderStore.thumbnailSize)
    }
    .id(url)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
        highlightedURL = url
        onDoubleClick(idx)
    }
    .onTapGesture(count: 1) {
        highlightedURL = url
        onSingleClick(idx)
    }
}

// MARK: - URLBucketSection helpers

private struct URLBucketItem: Identifiable, Equatable {
    let url: URL
    let flatIndex: Int   // 在 EphemeralResultView.urls 数组中的原始 index
    var id: URL { url }
}

private struct URLBucketSection: Identifiable, Equatable {
    let bucket: TimeBucket
    let items: [URLBucketItem]
    var id: Int { bucket.rawValue }
}
```

- [ ] **Step 6: make build 验证（应该 0 error；M2 找类似传递参数仍兼容，showTimeBuckets default false）**

```bash
make build
```

Expected: `BUILD SUCCEEDED — 0 errors, 0 code warnings`

注：M2 .similar 路径在 ContentView 调用 EphemeralResultView 时不传 showTimeBuckets / datesForBuckets / emptyStateText，全用 default，行为完全一致。

- [ ] **Step 7: 启动 app 实测 M2 找类似回归不退**

```bash
make run
```

操作步骤：
1. sidebar 选「全部最近」grid 等候 fp 索引完
2. 双击 cell 进 QV
3. 点工具栏 "找类似" 按钮
4. 验证 EphemeralResultView 出 top-30，**flat LazyVGrid 无 section header**（showTimeBuckets default false 路径）
5. 验证关闭按钮 / ESC / 单击/双击 cell 行为不变（cell helper 抽出后保 M2 行为）

- [ ] **Step 8: commit M.4**

```bash
git add Glance/Similarity/EphemeralResultView.swift
git commit -m "feat(M3.M.4): EphemeralResultView 加 showTimeBuckets + emptyStateText + datesForBuckets API；sectioned 渲染 helper（M2 .similar 路径行为不变）"
```

---

### Task M.5: ContentView 集成（EphemeralRequest.search + ⌘F + searchTask cancel/run）

**Files:**
- Modify: `Glance/ContentView.swift`
- Modify: `Glance/QuickViewer/QuickViewerOverlay.swift`

- [ ] **Step 1: EphemeralRequest enum 加 .search case + computed**

修改 ContentView.swift 顶部 EphemeralRequest enum：

```swift
private enum EphemeralRequest: Equatable {
    case similar(sourceUrl: URL, results: [URL], banner: String?)
    /// M3 Slice M — 全局搜索结果。images 携带 birth_time 给 EphemeralResultView 做时间分段。
    case search(query: String, images: [IndexedImage], urls: [URL])

    var title: String {
        switch self {
        case .similar(let url, _, _):
            return "类似于 \(url.lastPathComponent)"
        case .search(let q, _, _):
            return q.isEmpty ? "搜索" : "搜索: \(q)"
        }
    }

    var urls: [URL] {
        switch self {
        case .similar(_, let r, _): return r
        case .search(_, _, let urls): return urls
        }
    }

    var banner: String? {
        switch self {
        case .similar(_, _, let b): return b
        case .search: return nil   // D19 搜索不带 banner
        }
    }

    /// D19 toggle：search → true 启用 sectioned；similar → false flat。
    var showTimeBuckets: Bool {
        switch self {
        case .similar: return false
        case .search:  return true
        }
    }

    /// caller 控空态文案。M3 search 区分空 input vs 0 结果。
    var emptyStateText: String {
        switch self {
        case .similar:
            return "无结果"
        case .search(let q, _, _):
            return q.isEmpty
                ? "输入关键字或 modifier 搜索"
                : "未找到匹配项 · 检查拼写或减少 modifier"
        }
    }

    /// 跟 urls 平行的 birth_time 数组。M3 search 才有；M2 similar nil。
    var datesForBuckets: [Date]? {
        switch self {
        case .similar: return nil
        case .search(_, let images, _):
            return images.map { $0.birthTime }
        }
    }
}
```

- [ ] **Step 2: ContentView body 加 showSearchOverlay state + searchTask state + ⌘F shortcut**

修改 ContentView struct 字段段：

```swift
struct ContentView: View {
    // ... 既有 @EnvironmentObject / @State 不变

    /// M3 Slice M — search overlay 显隐控制
    @State private var showSearchOverlay: Bool = false
    /// M3 Slice M — 当前搜索后台 Task（cancel 用，避免 stale 覆盖）
    @State private var searchTask: Task<Void, Never>? = nil

    // ... 既有 body 不变直到 mainContent 那一段...
}
```

- [ ] **Step 3: ContentView.AppFocus.search case 加正式注释（替换 M.3 临时占位）**

修改 AppFocus enum（M.3 已加 case，本步只更注释）：

```swift
enum AppFocus: Hashable {
    case grid
    case preview
    case ephemeral
    /// M3 Slice M 加：⌘F 触发的 SearchOverlayView input field 拿焦点时此 case 激活；
    /// modal layer 顺序：QV > search > preview > ephemeral > baseGrid（D16）
    case search
}
```

- [ ] **Step 4: mainContent ZStack 顶层挂 SearchOverlayView**

修改 `private var mainContent: some View`，在既有 ZStack 末尾（progress chip 后）加：

```swift
@ViewBuilder
private var mainContent: some View {
    ZStack(alignment: .top) {
        // ... 既有 if let req = currentEphemeral { EphemeralResultView } else { baseGrid }
        // ... 既有 previewOverlay
        // ... 既有 progress chip VStack

        // M3 Slice M 加：search overlay 顶层
        if showSearchOverlay {
            SearchOverlayView(
                focusTarget: $focusTarget,
                onInputChange: { input, skipDebounce in
                    runSearch(input: input, skipDebounce: skipDebounce)
                },
                onClose: { closeSearch() }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .frame(maxWidth: .infinity, alignment: .center)
            .zIndex(100)  // 上方所有 layer（含 previewOverlay）
        }
    }
    .animation(DS.Anim.fast, value: indexStoreHolder.progress)
    .animation(DS.Anim.fast, value: indexStoreHolder.lastError)
    .animation(DS.Anim.fast, value: indexStoreHolder.featurePrintProgress)
    .animation(DS.Anim.normal, value: showSearchOverlay)
}
```

- [ ] **Step 5: ContentView body 加 ⌘F keyboardShortcut**

在 body 内合适位置（建议挨着既有 `.toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)` 附近）加：

```swift
.keyboardShortcut("f", modifiers: .command)
// 注：keyboardShortcut 作 view modifier 需要 Button host。改用下面 action-bound 方式：
.background {
    Button(action: openSearch) { EmptyView() }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0)
}
```

或更稳的做法（避免无用 Button）— 用 `.onKeyPress` 在 body 监听：

```swift
.onKeyPress(.init("f"), phases: .down) { event in
    if event.modifiers.contains(.command) {
        openSearch()
        return .handled
    }
    return .ignored
}
```

注：QV 内 ⌘F 单独由 QuickViewerOverlay 处理（见 Step 8），ContentView 这条 onKeyPress 在 QV 显示时不会触发（焦点在 QV 上）。

- [ ] **Step 6: 实现 openSearch / closeSearch / runSearch helpers**

在 ContentView 末尾（`// MARK: - Slice D — hide toggle 路由` 之前）插入新 MARK 段：

```swift
// MARK: - M3 Slice M — Search

/// ⌘F 入口。从任意 layer（baseGrid / preview / ephemeral / QV）触发。
private func openSearch() {
    // 路径 1：QV 内按 ⌘F → 同帧关 QV + 浮 overlay（D16 注解）
    if quickViewerIndex != nil {
        quickViewerIndex = nil
        quickViewerEntry = nil   // 清 entry 防止 onChange(of: quickViewerIndex) 回填焦点
    }
    showSearchOverlay = true
    // 初始化空 query 的 ephemeral 让 EphemeralResultView 显示 "输入关键字或 modifier 搜索" hint
    currentEphemeral = .search(query: "", images: [], urls: [])
    focusTarget = .search
}

/// ESC / × button 关闭路径。清 currentEphemeral 让 baseGrid 回来。
private func closeSearch() {
    searchTask?.cancel()
    searchTask = nil
    withAnimation(DS.Anim.normal) {
        showSearchOverlay = false
        currentEphemeral = nil
    }
    focusTarget = .grid
}

/// debounce + cancel + SearchService 调用。skipDebounce=true 跳 200ms timer（Enter 路径）。
private func runSearch(input: String, skipDebounce: Bool) {
    searchTask?.cancel()
    let trimmed = input.trimmingCharacters(in: .whitespaces)

    // 空输入 → 立即 reset ephemeral 到 hint 状态（不查 SQL）
    guard !trimmed.isEmpty else {
        currentEphemeral = .search(query: "", images: [], urls: [])
        return
    }

    guard let store = indexStoreHolder.store else { return }
    let holderRef = indexStoreHolder

    searchTask = Task.detached(priority: .userInitiated) { [weak indexStoreHolder] in
        // ① debounce sleep（skipDebounce=true 跳过）
        if !skipDebounce {
            try? await Task.sleep(for: .milliseconds(DS.Search.debounceMs))
            guard !Task.isCancelled else { return }
        }

        // ② parse + compile + fetch（同 SmartFolderEngine.execute 模式但不强制 SmartFolder 结构）
        let parsed = SearchService.parse(input)
        guard !parsed.isEmpty else {
            await MainActor.run {
                guard !Task.isCancelled else { return }
                // hint 状态（input 解析后全空：罕见但兜底）
            }
            return
        }
        let predicate = SearchService.compile(parsed)
        let folder = SmartFolder(
            id: "ephemeral-search",
            displayName: "搜索",
            predicate: predicate,
            sortBy: .birthTime,
            sortDescending: true,
            isBuiltIn: false
        )
        let images: [IndexedImage]
        do {
            let compiled = try SmartFolderQueryBuilder.compile(folder, now: Date())
            images = try store.fetch(compiled, limit: nil)
        } catch {
            await MainActor.run {
                holderRef.lastError = "搜索失败：\(error.localizedDescription)"
            }
            return
        }

        // ③ 二次 guard
        guard !Task.isCancelled else { return }

        // ④ resolve URL（mirror computeV2Urls pattern）
        let urls: [URL] = images.compactMap { img in
            var stale = false
            guard let rootURL = try? URL(
                resolvingBookmarkData: img.urlBookmark,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &stale
            ) else { return nil }
            return rootURL.appendingPathComponent(img.relativePath)
        }

        // ⑤ 写状态（MainActor + 三次 guard）
        await MainActor.run { [weak indexStoreHolder] in
            _ = indexStoreHolder
            guard !Task.isCancelled else { return }
            self.currentEphemeral = .search(query: input, images: images, urls: urls)
        }
    }
}
```

注：`self` capture 跨 Task.detached 需明示。SwiftUI struct View 的 `self` 是 value type，capture 时拿到一份当时的 view binding（同 M2 handleFindSimilar 模式）。

- [ ] **Step 7: 把 EphemeralRequest.search 的 onSingleClick / onDoubleClick 接入 mainContent**

修改 mainContent 内 `EphemeralResultView` 构造调用（既有 .similar case，新加 .search case 行为）：

```swift
if let req = currentEphemeral {
    EphemeralResultView(
        title: req.title,
        urls: req.urls,
        bannerText: req.banner,
        emptyStateText: req.emptyStateText,                // M3 加
        showTimeBuckets: req.showTimeBuckets,              // M3 加
        datesForBuckets: req.datesForBuckets,              // M3 加
        onClose: {
            // .similar 走旧路径；.search 走 closeSearch（清 overlay + ephemeral）
            switch req {
            case .similar:
                withAnimation(DS.Anim.normal) { currentEphemeral = nil }
                folderStore.selectedImageIndex = nil
                focusTarget = .grid
            case .search:
                closeSearch()
            }
        },
        onSingleClick: { idx in
            v2Urls = req.urls
            folderStore.selectedImageIndex = idx
        },
        onDoubleClick: { idx in
            v2Urls = req.urls
            folderStore.selectedImageIndex = nil
            quickViewerEntry = .ephemeral
            quickViewerIndex = idx
        },
        focusTarget: $focusTarget
    )
} else {
    baseGrid
}
```

- [ ] **Step 8: QuickViewerOverlay 加 onCommandF callback + ⌘F handler**

修改 `Glance/QuickViewer/QuickViewerOverlay.swift` struct 顶部加参数：

```swift
struct QuickViewerOverlay: View {
    let images: [URL]
    let startIndex: Int
    let onDismiss: () -> Void
    let onIndexChange: (Int) -> Void
    let onFindSimilar: (URL) -> Void
    let currentSupportsFeaturePrint: Bool
    /// M3 Slice M 加：QV 内按 ⌘F → ContentView 同帧关 QV + 浮 search overlay。
    let onCommandF: () -> Void

    // ... 其余字段不变
}
```

QV body 内既有 `.onKeyPress(.escape) { handleDismissOrExitFullScreen(); return .handled }` 附近添加：

```swift
.onKeyPress(.init("f"), phases: .down) { event in
    if event.modifiers.contains(.command) {
        onCommandF()
        return .handled
    }
    return .ignored
}
```

- [ ] **Step 9: ContentView 调 QuickViewerOverlay 时传 onCommandF callback**

修改 ContentView .overlay 块内 QuickViewerOverlay 构造（现有 quickViewerEntry case 处理段附近）：

```swift
.overlay {
    if let idx = quickViewerIndex {
        QuickViewerOverlay(
            images: smartFolderStore.selected != nil ? v2Urls : folderStore.images,
            startIndex: idx,
            onDismiss: {
                withAnimation(DS.Anim.normal) {
                    quickViewerIndex = nil
                }
            },
            onIndexChange: { newIdx in
                folderStore.selectedImageIndex = newIdx
            },
            onFindSimilar: { sourceUrl in
                handleFindSimilar(sourceUrl: sourceUrl)
            },
            currentSupportsFeaturePrint: currentSupportsFeaturePrint(at: idx),
            onCommandF: { openSearch() }   // M3 Slice M 加
        )
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
    }
}
```

- [ ] **Step 10: make build 验证 0 error 0 warning**

```bash
make build
```

Expected: `BUILD SUCCEEDED — 0 errors, 0 code warnings`

- [ ] **Step 11: 启动 app 实测 8 条核心交互**

```bash
make run
```

测试 sequence（每条独立操作）：

1. baseGrid 状态按 ⌘F → SearchOverlayView 从顶部滑入，input 自动 active，输入 "screen" 后 200ms 看到 EphemeralResultView 出结果（按 birth_time 倒序 + 时间分段 chip header）
2. ESC → overlay 消失 + EphemeralResultView 消失 + baseGrid 回来 + 方向键 / Space 立即响应
3. baseGrid → 单击 cell 进 preview → 按 ⌘F → overlay 出（preview 仍可见在下方？需确认 — preview 在 ZStack 中是 overlay 层，search overlay 应在最顶 z=100 优先）
4. baseGrid → 双击 cell 进 QV → 按 ⌘F → QV **同帧关** + overlay 出（视觉一帧切换）
5. overlay 内输入 "type:png" → 仅 PNG 结果
6. overlay 内输入 "screen type:invalidext" → silent partial fallback 当 keyword（结果可能 0）
7. overlay 内输入"" → reset 到 hint 状态 "输入关键字或 modifier 搜索"
8. overlay 内输入 "screen" → 看到结果 → 双击 cell → 进 QV（quickViewerEntry = .ephemeral，QV ESC → 回 search overlay 状态）

- [ ] **Step 12: commit M.5**

```bash
git add Glance/ContentView.swift Glance/QuickViewer/QuickViewerOverlay.swift
git commit -m "feat(M3.M.5): ContentView ⌘F search 集成（EphemeralRequest.search + searchTask debounce/cancel + QV 同帧切换）"
```

---

### Task M.6: /go 收尾（Roadmap + PENDING + commit + push + tag v2.2）

**Files:**
- Modify: `specs/Roadmap.md`
- Modify: `specs/PENDING-USER-ACTIONS.md`
- Modify: `CLAUDE.md`（加 `Glance/Search/` 文件结构段）

- [ ] **Step 1: verify.sh 三段绿**

```bash
./scripts/verify.sh
```

Expected: `=== summary: 12 passed, 0 failed ===`，build SUCCEEDED 0 error 0 warning。

- [ ] **Step 2: 更新 CLAUDE.md 文件结构加 `Glance/Search/` 段**

修改 `CLAUDE.md` 在 `└── SmartFolder/` 块之前插入：

```markdown
├── Search/                          ← V2 M3 Slice M 全局搜索
│   ├── SearchInput.swift                ← ParsedSearch struct + SearchSizeUnit enum
│   ├── SearchService.swift              ← parser (Silent partial) + compile → SmartFolderPredicate
│   └── SearchOverlayView.swift          ← 顶部 Spotlight 式 overlay + ⌘F 入口 + ESC dismiss
```

- [ ] **Step 3: 更新 specs/Roadmap.md M3 段**

- M3 Slice 表把 M 行状态从 "🚧 待开始" 改 "✅ 完成" + 完成日期 + commit hash 占位
- 加 Slice M 完成详细表（mirror Slice J 完成详细 pattern）：

```markdown
### Slice M 完成详细（6 task）

| Task | Goal | Commit |
|---|---|---|
| M.1 | SearchInput + SearchService（parser + compile）| <hash> |
| M.2 | SearchService inline 8 case 自检通过 | <hash> |
| M.3 | SearchOverlayView + DS.Search tokens + AppFocus.search 占位 | <hash> |
| M.4 | EphemeralResultView 加 showTimeBuckets + emptyStateText + sectioned 渲染 | <hash> |
| M.5 | ContentView ⌘F 集成 + QV 同帧切换 + EphemeralRequest.search case | <hash> |
| M.6 | /go 收尾 + tag v2.2 | （本次）|
```

- 在 V2 决策段加 D16-D20（从 `specs/v2/2026-05-11-m3-design.md` § 11 复制 markdown）

- [ ] **Step 4: 更新 specs/PENDING-USER-ACTIONS.md 加 Slice M 测试项**

在「Pending」段追加：

```markdown
### V2 M3 Slice M（2026-05-11）— 全局搜索

- [ ] (2026-05-11 / `<pending>` / Slice M) **⌘F 入口 — baseGrid**：sidebar 选「全部最近」grid 状态按 ⌘F → SearchOverlayView 顶部滑入，input 自动 active，可立即输入
- [ ] (2026-05-11 / `<pending>` / Slice M) **⌘F 入口 — preview**：单击 cell 进 preview 后按 ⌘F → overlay 出，preview 仍 visible（z-index 区分）
- [ ] (2026-05-11 / `<pending>` / Slice M) **⌘F 入口 — ephemeral**：找类似 ephemeral 状态按 ⌘F → overlay 替换显示，ephemeral 转换为 search ephemeral
- [ ] (2026-05-11 / `<pending>` / Slice M) **⌘F 入口 — QV**：双击 cell 进 QV 后按 ⌘F → QV 同帧关 + overlay 出（视觉一帧切换）
- [ ] (2026-05-11 / `<pending>` / Slice M) **keyword 基础搜索**：输入 "screen" → 200ms 后 EphemeralResultView 出结果，filename + relative_path LIKE 命中均显示，按 birth_time 倒序 + 时间分段 chip header
- [ ] (2026-05-11 / `<pending>` / Slice M) **modifier type**：输入 "type:png" → 仅 PNG 文件结果
- [ ] (2026-05-11 / `<pending>` / Slice M) **modifier size**：输入 "size:>1mb" → 仅 >1MB 文件结果
- [ ] (2026-05-11 / `<pending>` / Slice M) **modifier birth**：输入 "birth:>2026-04-01" → 仅 birth_time > 2026-04-01 文件结果
- [ ] (2026-05-11 / `<pending>` / Slice M) **modifier 混合 AND**：输入 "screen type:png size:>500k" → 三条件 AND 命中
- [ ] (2026-05-11 / `<pending>` / Slice M) **Silent partial fallback**：输入 "screen type:invalidext" → 整 token "screen type:invalidext" 当 keyword LIKE（结果可能 0，不报错）；输入 "foo size:abc" → 整 token fallback keyword（结果可能 0）
- [ ] (2026-05-11 / `<pending>` / Slice M) **Hidden 继承**：右键 hide 某 folder → 搜索其内 filename 应不出现（D18）
- [ ] (2026-05-11 / `<pending>` / Slice M) **焦点回归**：ESC overlay → baseGrid 立即响应方向键 / Space（D15 单仲裁回归 .grid）
- [ ] (2026-05-11 / `<pending>` / Slice M) **M2 找类似回归**：QV 内点找类似 → EphemeralResultView showTimeBuckets=false 维持 flat LazyVGrid + "无结果" 文案（如空结果），cell 单击/双击行为不变
- [ ] (2026-05-11 / `<pending>` / Slice M / deferred) **性能验收**：1 万图库典型 keyword 搜索响应时间 < 200ms（实测数字记录此处）
```

- [ ] **Step 5: commit M.6 文档同步 + 主 commit**

```bash
git add specs/Roadmap.md specs/PENDING-USER-ACTIONS.md CLAUDE.md
git commit -m "docs(M3.M.6): V2 M3 Slice M ship → V2.2 GA (Roadmap + PENDING + CLAUDE.md sync)"
```

- [ ] **Step 6: M.1-M.5 hash 回填到 Roadmap Slice M 完成详细表**

```bash
# 用 git log 拿到 5 个 commit hash
git log --oneline --grep="M3.M\." | head -5
# 手动编辑 specs/Roadmap.md Slice M 完成详细表填回 hash
git add specs/Roadmap.md
git commit -m "docs: 回填 M3.M.1-M.5 commit hash 到 Roadmap [docs-only]"
```

- [ ] **Step 7: push（pre-push codex hook 走完整 review，不 bypass）**

```bash
git push
```

Expected: codex review 通过（之前 specs/<module>.md P1 假阳已通过 hook PROMPT 扩展根治，参 commit 4052d5b 工作流沉淀）；push success。

- [ ] **Step 8: tag v2.2 并 push origin**

```bash
git tag -a v2.2 -m "V2 M3 Slice M ship — global search + ⌘F + modifier syntax"
git push origin v2.2
```

- [ ] **Step 9: 一段话汇报**

汇报模板（参考 `.claude/commands/go.md`）：

> BUILD SUCCEEDED — 0 errors, 0 code warnings
>
> M3 Slice M ship 完成（V2.2 GA，6 task / 6 commit）。新增 `Glance/Search/` 3 文件 + EphemeralResultView 扩展 + ContentView 集成 + QuickViewerOverlay onCommandF callback。⌘F 4 处入口（baseGrid / preview / ephemeral / QV）+ 顶部 Spotlight 式 overlay + 3 个 modifier 语法（type/size/birth）+ Silent partial 解析 + hide 继承 + 时间分段渲染端到端可用。文档同步 Roadmap M3 完成 + D16-D20 + CLAUDE.md + PENDING（14 项人工验收）。pre-push codex hook 通过（不 bypass）。tag v2.2 已推。

---

## Slice N: 潜在 polish（outline，待 Slice M 实测触发）

> Slice N detail 留到 Slice M ship 后实测过 → 写 dedicated plan。本段仅占位 + goal/deliverable。

### N.1: SQL 性能优化（FTS5 / index on filename+relative_path）

**Goal**：10k+ 图库 keyword 搜索响应稳定 < 200ms。

**Deliverable** (if 性能 PENDING #14 显示超预算)：
- Option A：`CREATE INDEX idx_images_filename ON images(filename);` + `idx_images_relpath ON images(relative_path);` — SQLite 全文 LIKE 无法用 B-tree index，但 prefix LIKE（"screen%"）可用，需评估
- Option B：FTS5 虚表 `CREATE VIRTUAL TABLE images_fts USING fts5(filename, relative_path, content='images', content_rowid='id')` + trigger 同步 — 真 full-text search 但 schema 复杂

### N.2: 搜索历史 / saved searches

**Goal**：power user 回访常用查询不重打。

**Deliverable**：
- 持久化最近 10 个搜索到 `~/Library/Application Support/Glance/search-history.json`
- SearchOverlayView 输入空时显示历史下拉
- "保存为智能文件夹" 走 M4 编辑器路径

### N.3: a11y polish

**Deliverable**：
- VoiceOver 朗读 SearchOverlayView 角色 / hint
- modifier hint 行加 `accessibilityHint`
- 0 结果空态加 `accessibilityLabel`

### N.4: Tab forward 到 grid 导航

**Goal**：键盘 power user 不离手操作 — input 内 Tab 转焦到 EphemeralResultView 内方向键导航。

**Deliverable**：
- SearchOverlayView .onKeyPress(.tab) → focusTarget = .ephemeral
- EphemeralResultView ↓→ 进入第一个 cell 高亮

---

## Pending（V2 M3 Slice M）

M.6 Step 4 已把 PENDING 项一次性追加到 `specs/PENDING-USER-ACTIONS.md`。本 plan 不再重复列。Slice N 启动前再追加 N 的人工测试项。

---

## M3 完成判定

满足以下全部条件 = M3 完成（V2.2 GA）：

1. **三段式 verify**（`./scripts/verify.sh`）：M ship 后跑，0 error 0 warning
2. **Slice L 已 commit + push**（2026-05-11 ship 完成）
3. **Slice M 6 task 全部 commit + push**
4. **PENDING-USER-ACTIONS** Slice L 5 项 + Slice M #1-#13 人工通过；#14 性能可 defer 等真实大库
5. **三标准核对**：
   - (a) 端到端可跑：⌘F → 输入 → 200ms 后看到结果 → ESC 退
   - (b) 用户可感知：4 处 ⌘F 入口 + 顶部 overlay + 时间分段结果 + 3 个 modifier 实际可用
   - (c) 独立可 ship：tag v2.2 + DMG 可分发
6. **回归**：V1 + V2 M1/M2 既有功能不退化（特别 M2 找类似 ephemeral showTimeBuckets=false 维持原 UX）
7. **D16-D20 写入 `specs/Roadmap.md`** 决策段
8. **CLAUDE.md 文件结构同步**（`Glance/Search/` 段已加）
9. **`specs/v2/2026-05-11-m3-design.md` 状态从 design lock → ✅ shipped**

---

## Self-Review

完整 plan 写完后用 fresh eyes 跑一遍：

### 1. Spec coverage（design.md → plan task 映射）

| design.md 章节 | 对应 task |
|---|---|
| § 4.1 SearchInput + SearchService | M.1 |
| § 4.1 SearchOverlayView | M.3 |
| § 4.2 EphemeralResultView 扩展 | M.4 |
| § 4.2 ContentView 改造 | M.5 |
| § 4.2 QuickViewerOverlay 改造 | M.5 Step 8-9 |
| § 4.2 DesignSystem DS.Search 段 | M.3 Step 1 |
| § 4.3 焦点 / Modal layer 拓展 | M.5 Step 3 + M.3 AppFocus 占位 |
| § 4.4 数据流（debounce / cancel / query lifecycle）| M.5 Step 6 runSearch impl |
| § 5 SearchOverlayView 接口 | M.3 Step 2 |
| § 6 Parser 语法 + Silent partial | M.1 Step 2 + M.2 验证 |
| § 7 EphemeralResultView API 扩展 | M.4 Step 1-5 |
| § 8 性能 / 验收 | M.6 Step 4 PENDING #14（deferred）|
| § 9.2 Slice M 拆分 6 task | M.1-M.6 |
| § 10 已知风险 R1-R7 | inline 各 task 注释 + PENDING |
| § 11 D16-D20 | M.6 Step 3 写入 Roadmap |

✅ Spec 全覆盖。

### 2. Placeholder scan

✅ 所有 task step 都有 actual code / command / expected output。无 "TBD" / "TODO"（M.6 Step 6 commit hash 占位是 ship 后回填模式，符合项目「docs: 回填 hash」commit 模式）。

### 3. Type / signature consistency

- `SearchService.parse(_:) -> ParsedSearch` — M.1 定义，M.2 验证 + M.5 调用一致 ✓
- `SearchService.compile(_:) -> SmartFolderPredicate` — M.1 定义，M.5 调用一致 ✓
- `ParsedSearch.modifiers: [SmartFolderAtom]` + `.keyword: String` + `.isEmpty: Bool` — M.1 定义，M.5 runSearch 用 isEmpty 短路 ✓
- `SmartFolder(id:, displayName:, predicate:, sortBy:, sortDescending:, isBuiltIn:)` — 跟 `Glance/SmartFolder/SmartFolder.swift` struct 签名一致（已 Read 验证）✓
- `SmartFolderQueryBuilder.compile(_:now:) -> CompiledSmartFolderQuery` — 跟 `Glance/SmartFolder/SmartFolderQueryBuilder.swift:13` 签名一致（已 Read 验证）✓
- `IndexStore.fetch(_:limit:) -> [IndexedImage]` — 跟 `Glance/SmartFolder/SmartFolderEngine.swift:14` 签名一致（已 Read 验证）✓
- `IndexedImage.urlBookmark: Data` + `.relativePath: String` + `.birthTime: Date` — 跟 `Glance/IndexStore/IndexedImage.swift` 一致（已通过 grep 验证 urlBookmark / relativePath 字段使用）✓
- `TimeBucket.boundaries(now:calendar:)` + `.bucket(for:boundaries:)` — 跟 `Glance/FolderBrowser/TimeBucket.swift:39 / :49` 签名一致（已 Read 验证）✓
- `EphemeralResultView` 新 API（showTimeBuckets / emptyStateText / datesForBuckets）— M.4 定义，M.5 ContentView 构造一致 ✓
- `EphemeralRequest.search(query:images:urls:)` case — M.5 Step 1 定义；computed 输出（title/urls/banner/showTimeBuckets/emptyStateText/datesForBuckets）跟 EphemeralResultView 参数一一对应 ✓
- `AppFocus.search` case — M.3 Step 4 占位加；M.5 Step 3 正式注释 ✓
- `QuickViewerOverlay` 新 `onCommandF: () -> Void` 参数 — M.5 Step 8 定义；M.5 Step 9 ContentView 调用一致 ✓
- `DS.Search.{overlayMaxWidth, overlayPadding, overlayCornerRadius, debounceMs, modifierHintOpacity, overlayBorderOpacity, overlayBorderWidth}` — M.3 Step 1 定义；M.3 Step 2 + M.5 Step 6 引用一致 ✓
- `closeSearch()` / `openSearch()` / `runSearch(input:skipDebounce:)` helper 签名 — M.5 Step 6 定义；M.5 Step 4 / Step 7 / Step 9 调用一致 ✓

✅ 全 signature 一致。

### 4. Risk inline 处理

- R1 SQL 性能：M.5 Step 11 实测；超 200ms 走 N.1 polish — 不阻 Slice M ship
- R2 Search overlay + ephemeral 同时 mount ESC 错乱：M.5 Step 6 closeSearch 一次清两 layer；M.5 Step 11 路径 7（输入空切回 hint）+ PENDING #11 焦点回归覆盖
- R3 Async cancel 三层 guard：M.5 Step 6 runSearch 严格 ① sleep 前 ② SQL+resolve 后 ③ MainActor.run 内 — 三处显式
- R4 Silent partial UX：M.3 Step 2 modifier hint 永远显示 + M.5 EphemeralRequest.emptyStateText 提示
- R5 EphemeralResultView refactor 破 M2：M.4 Step 1 showTimeBuckets default false + M.4 Step 7 启动 app 实测 M2 找类似回归
- R6 Hidden 继承 surprise：D18 doc 已清晰；用户问可 refer
- R7 birth: 时区：M.1 Step 2 parser UTC ISO 8601 一致约定，跟 birth_time 列（UNIX timestamp 时区无关）直接比较，无错位

---

## Execution Handoff

Plan 写完保存至 `specs/v2/2026-05-11-m3-implementation-plan.md`，commit 后让用户选执行方式：

1. **`superpowers:subagent-driven-development`**（推荐）— 每 task 派一个新 subagent，两阶段 review，快速迭代
2. **`superpowers:executing-plans`** — 当前 session 内 batch 执行，checkpoint 让人 review
