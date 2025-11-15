#if canImport(Darwin)
import Foundation
import TOONCore

struct RandomTOONCase {
    let toon: String
    let expected: JSONValue
    let requiresLenient: Bool
}

struct RandomTOONGenerator {
    private var rng: LCG
    private var indentUnit: String = "  "
    private let maxDepth = 2
    private let keyPool = ["id", "name", "items", "meta", "stats", "data", "values", "profile", "user", "flags"]
    private let headerPool = ["id", "name", "age", "score", "email", "active", "status", "tier", "created"]

    init(seed: UInt64) {
        self.rng = LCG(state: seed)
    }

    mutating func nextCase() -> RandomTOONCase {
        indentUnit = rng.nextBool() ? "  " : "    "
        let (text, object, lenient) = makeObject(indentLevel: 0, depth: 0)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        return RandomTOONCase(toon: trimmed, expected: .object(object), requiresLenient: lenient)
    }

    private mutating func makeObject(indentLevel: Int, depth: Int) -> (text: String, object: JSONObject, lenient: Bool) {
        var lines = ""
        var object = JSONObject()
        var requiresLenient = false
        let entryCount = 1
        for _ in 0..<entryCount {
            let key = randomKey()
            let entry = makeEntry(indentLevel: indentLevel, depth: depth, key: key)
            lines += entry.text
            object[key.actual] = entry.json
            requiresLenient = requiresLenient || entry.requiresLenient
        }
        return (lines, object, requiresLenient)
    }

    private mutating func makeEntry(indentLevel: Int, depth: Int, key: KeyLiteral) -> NodeResult {
        let maxChoice = depth >= maxDepth ? 2 : 5
        let choice = Int(rng.nextInt(max: maxChoice))
        switch choice {
        case 0:
            return primitiveEntry(indentLevel: indentLevel, key: key)
        case 1:
            let child = makeObject(indentLevel: indentLevel + 1, depth: depth + 1)
            let text = indent(indentLevel) + "\(key.token):\n" + child.text
            return NodeResult(text: text, json: .object(child.object), requiresLenient: child.lenient)
        case 2:
            return inlineArrayEntry(indentLevel: indentLevel, key: key)
        case 3:
            return dashArrayEntry(indentLevel: indentLevel, key: key)
        default:
            return tabularArrayEntry(indentLevel: indentLevel, key: key)
        }
    }

    private mutating func primitiveEntry(indentLevel: Int, key: KeyLiteral) -> NodeResult {
        let primitive = randomPrimitive()
        let line = indent(indentLevel) + "\(key.token): \(primitive.literal())\n"
        return NodeResult(text: line, json: primitive.json, requiresLenient: false)
    }

    private mutating func inlineArrayEntry(indentLevel: Int, key: KeyLiteral) -> NodeResult {
        let count = 1 + rng.nextInt(max: 3)
        var values: [PrimitiveLiteral] = []
        for _ in 0..<count {
            values.append(randomPrimitive())
        }
        let delimiter = Delimiter.allCases[rng.nextInt(max: Delimiter.allCases.count)]
        var declared = count
        var requiresLenient = false
        if rng.nextInt(max: 5) == 0 {
            requiresLenient = true
            if rng.nextBool() {
                declared += 1
            } else if declared > 0 {
                declared -= 1
            }
        }
        let valueText = values.map { $0.literal(for: delimiter) }.joined(separator: delimiter.separator)
        let line = indent(indentLevel) + "\(key.token)[\(declared)\(delimiter.headerSuffix)]: \(valueText)\n"
        let jsonValues = values.map(\.json)
        return NodeResult(text: line, json: .array(jsonValues), requiresLenient: requiresLenient)
    }

    private mutating func dashArrayEntry(indentLevel: Int, key: KeyLiteral) -> NodeResult {
        let count = 1 + rng.nextInt(max: 3)
        var values: [PrimitiveLiteral] = []
        for _ in 0..<count {
            values.append(randomPrimitive())
        }
        var text = indent(indentLevel) + "\(key.token)[\(count)]:\n"
        for value in values {
            text += indent(indentLevel + 1) + "- \(value.literal())\n"
        }
        return NodeResult(text: text, json: .array(values.map(\.json)), requiresLenient: false)
    }

    private mutating func tabularArrayEntry(indentLevel: Int, key: KeyLiteral) -> NodeResult {
        var headers: [String] = []
        let headerCount = min(headerPool.count, 2 + rng.nextInt(max: 3))
        while headers.count < headerCount {
            let candidate = headerPool[rng.nextInt(max: headerPool.count)]
            if !headers.contains(candidate) {
                headers.append(candidate)
            }
        }

        let rowsCount = 1 + rng.nextInt(max: 3)
        let delimiter: Delimiter = .comma

        var text = indent(indentLevel) + "\(key.token)[\(rowsCount)\(delimiter.headerSuffix)]{\(headers.joined(separator: ","))}:\n"
        var jsonRows: [JSONValue] = []

        for _ in 0..<rowsCount {
            var row: [PrimitiveLiteral] = []
            for _ in headers {
                row.append(randomPrimitive())
            }

            let literal = row.map { $0.literal(for: delimiter) }.joined(separator: delimiter.separator)
            text += indent(indentLevel + 1) + "\(literal)\n"

            let normalized = normalizeRow(row, expected: headers.count)
            var object = JSONObject()
            for (index, header) in headers.enumerated() {
                object[header] = normalized[index].json
            }
            jsonRows.append(.object(object))
        }

        return NodeResult(text: text, json: .array(jsonRows), requiresLenient: false)
    }

    private mutating func randomKey() -> KeyLiteral {
        var base = keyPool[rng.nextInt(max: keyPool.count)]
        if rng.nextBool() {
            base += "_\(rng.nextInt(max: 10))"
        }
        if rng.nextInt(max: 5) == 0 {
            base += " label"
        }
        let token: String
        if base.contains(where: { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "-" }) {
            token = "\"\(base)\""
        } else {
            token = base
        }
        return KeyLiteral(actual: base, token: token)
    }

    private mutating func randomPrimitive() -> PrimitiveLiteral {
        let choice = rng.nextInt(max: 5)
        switch choice {
        case 0:
            let value = "value\(rng.nextInt(max: 100))"
            return PrimitiveLiteral(json: .string(value), raw: value, forceQuotes: false)
        case 1:
            let value = "value \(rng.nextInt(max: 100))"
            return PrimitiveLiteral(json: .string(value), raw: value, forceQuotes: true)
        case 2:
            let baseValue = Double(rng.nextInt(max: 100)) / 3.0
            let literal: String
            let numeric: Double
            if baseValue == floor(baseValue) {
                literal = String(Int(baseValue))
                numeric = baseValue
            } else {
                literal = String(format: "%.2f", baseValue)
                numeric = Double(literal) ?? baseValue
            }
            return PrimitiveLiteral(json: .number(numeric), raw: literal, forceQuotes: false)
        case 3:
            let bool = rng.nextBool()
            return PrimitiveLiteral(json: .bool(bool), raw: bool ? "true" : "false", forceQuotes: false)
        default:
            return PrimitiveLiteral(json: .null, raw: "null", forceQuotes: false)
        }
    }

    private func indent(_ level: Int) -> String {
        guard level > 0 else { return "" }
        return String(repeating: indentUnit, count: level)
    }
}

private func normalizeRow(_ values: [PrimitiveLiteral], expected: Int) -> [PrimitiveLiteral] {
    if values.count == expected {
        return values
    } else if values.count > expected {
        return Array(values.prefix(expected))
    } else {
        var padded = values
        for _ in values.count..<expected {
            padded.append(PrimitiveLiteral(json: .null, raw: "null", forceQuotes: false))
        }
        return padded
    }
}

private struct KeyLiteral {
    let actual: String
    let token: String
}

private struct PrimitiveLiteral {
    let json: JSONValue
    let raw: String
    let forceQuotes: Bool

    func literal(for delimiter: Delimiter? = nil) -> String {
        if case .string = json {
            let needsQuotes = forceQuotes || delimiter?.shouldQuote(raw) == true
            return needsQuotes ? "\"\(raw)\"" : raw
        }
        return raw
    }
}

private struct NodeResult {
    let text: String
    let json: JSONValue
    let requiresLenient: Bool
}

private enum Delimiter: CaseIterable {
    case comma
    case pipe

    var headerSuffix: String {
        switch self {
        case .comma:
            return ""
        case .pipe:
            return "|"
        }
    }

    var separator: String {
        switch self {
        case .comma:
            return ","
        case .pipe:
            return "|"
        }
    }

    func shouldQuote(_ value: String) -> Bool {
        switch self {
        case .comma, .pipe:
            return value.contains(separator) || value.contains(" ")
        }
    }
}

private struct LCG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }

    mutating func nextInt(max: Int) -> Int {
        return Int(next() % UInt64(max))
    }

    mutating func nextBool() -> Bool {
        return (next() & 1) == 0
    }
}
#endif
