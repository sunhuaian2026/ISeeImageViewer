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
