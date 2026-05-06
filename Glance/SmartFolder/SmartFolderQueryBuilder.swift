import Foundation

enum SmartFolderQueryError: Error {
    case unsupportedFieldOpCombo(field: SmartFolderField, op: SmartFolderOp)
    case typeMismatch(field: SmartFolderField, value: SmartFolderValue)
}

// `CompiledSmartFolderQuery` lives in `Glance/IndexStore/CompiledSmartFolderQuery.swift`
// (it's the contract between this builder's output and IndexStore.fetch's input).

enum SmartFolderQueryBuilder {

    static func compile(_ folder: SmartFolder, now: Date = Date()) throws -> CompiledSmartFolderQuery {
        var params: [Any] = []
        let whereSQL = try emit(folder.predicate, params: &params, now: now)
        let orderSQL = "\(folder.sortBy.rawValue) \(folder.sortDescending ? "DESC" : "ASC")"
        return CompiledSmartFolderQuery(whereClause: whereSQL, parameters: params, orderBy: orderSQL)
    }

    private static func emit(_ p: SmartFolderPredicate, params: inout [Any], now: Date) throws -> String {
        switch p {
        case .and(let xs):
            let parts = try xs.map { try emit($0, params: &params, now: now) }
            return "(" + parts.joined(separator: " AND ") + ")"
        case .or(let xs):
            let parts = try xs.map { try emit($0, params: &params, now: now) }
            return "(" + parts.joined(separator: " OR ") + ")"
        case .atom(let atom):
            return try emitAtom(atom, params: &params, now: now)
        }
    }

    private static func emitAtom(_ a: SmartFolderAtom, params: inout [Any], now: Date) throws -> String {
        switch a.field {
        case .managed:
            // Slice A: 所有 indexed images 都已属于已注册的 managed root，无需额外过滤
            return "1"
        case .hidden:
            // Slice A: 没有 subfolder hide 状态；Slice D 时 wires real check
            return "0 = 0"
        case .dedupCanonicalOrNull:
            return "(dedup_canonical IS NULL OR dedup_canonical = 1)"
        case .filename, .relativePath, .format:
            return try emitStringAtom(a, column: a.field.rawValue, params: &params)
        case .fileSize, .dimensionsWidth, .dimensionsHeight:
            return try emitIntAtom(a, column: a.field.rawValue, params: &params)
        case .birthTime:
            return try emitTimeAtom(a, column: "birth_time", params: &params, now: now)
        }
    }

    private static func emitStringAtom(_ a: SmartFolderAtom, column: String, params: inout [Any]) throws -> String {
        switch a.op {
        case .eq:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v)
            return "\(column) = ?"
        case .ne:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v)
            return "\(column) != ?"
        case .contains:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append("%\(v)%")
            return "\(column) LIKE ?"
        case .startsWith:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append("\(v)%")
            return "\(column) LIKE ?"
        case .inSet:
            guard case .stringArray(let xs) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            let placeholders = xs.map { _ in "?" }.joined(separator: ",")
            params.append(contentsOf: xs as [Any])
            return "\(column) IN (\(placeholders))"
        default:
            throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func emitIntAtom(_ a: SmartFolderAtom, column: String, params: inout [Any]) throws -> String {
        guard case .int(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
        switch a.op {
        case .greaterThan: params.append(v); return "\(column) > ?"
        case .lessThan: params.append(v); return "\(column) < ?"
        case .eq: params.append(v); return "\(column) = ?"
        case .ne: params.append(v); return "\(column) != ?"
        default: throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func emitTimeAtom(_ a: SmartFolderAtom, column: String, params: inout [Any], now: Date) throws -> String {
        switch a.op {
        case .betweenDuration:
            guard case .relativeTimeRange(let s, let e) = a.value else {
                throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value)
            }
            let startTs = resolveRelativeTime(s, now: now)
            let endTs = resolveRelativeTime(e, now: now)
            params.append(startTs)
            params.append(endTs)
            return "(\(column) >= ? AND \(column) <= ?)"
        case .greaterThan:
            guard case .double(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v); return "\(column) > ?"
        case .lessThan:
            guard case .double(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v); return "\(column) < ?"
        default:
            throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func resolveRelativeTime(_ token: String, now: Date) -> Double {
        if token == "now" { return now.timeIntervalSince1970 }
        if let last = token.last, last == "d",
           let n = Int(token.dropLast()) {
            return now.addingTimeInterval(TimeInterval(n) * 86400).timeIntervalSince1970
        }
        let fmt = ISO8601DateFormatter()
        if let d = fmt.date(from: token) {
            return d.timeIntervalSince1970
        }
        return now.timeIntervalSince1970
    }
}
