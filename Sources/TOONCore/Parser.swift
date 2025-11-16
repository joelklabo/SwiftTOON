import Foundation

public enum ParserError: Error, Equatable, LocalizedError {
    case unexpectedToken(line: Int, column: Int, expected: String)
    case invalidNumberLiteral(String, line: Int, column: Int)
    case inlineArrayLengthMismatch(expected: Int, actual: Int, line: Int, column: Int)
    case tabularRowFieldMismatch(expected: Int, actual: Int, line: Int, column: Int)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedToken(line, column, expected):
            return "Unexpected token at \(line):\(column). Expected \(expected)."
        case let .invalidNumberLiteral(value, line, column):
            return "Invalid number literal '\(value)' at \(line):\(column)."
        case let .inlineArrayLengthMismatch(expected, actual, line, column):
            return "Array declared with \(expected) values but found \(actual) at \(line):\(column)."
        case let .tabularRowFieldMismatch(expected, actual, line, column):
            return "Tabular row expected \(expected) fields but found \(actual) at \(line):\(column)."
        }
    }
}

public struct Parser {
    public struct Options {
        public var lenientArrays: Bool

        public init(lenientArrays: Bool = false) {
            self.lenientArrays = lenientArrays
        }
    }

    private var tokens: [Token]
    private var index: Int = 0
    private let sourceBytes: [UInt8]
    private let options: Options
    private var chunkBuffer: [Token] = []
    private var rowChunkBuffer: [Token] = []
    private enum ArrayDelimiter {
        case comma
        case tab
        case pipe
    }

    public init(input: String, options: Options = Options()) throws {
        self.tokens = try Lexer.tokenize(input)
        self.sourceBytes = Array(input.utf8)
        self.options = options
    }

    public mutating func parse() throws -> JSONValue {
        let signpostID = PerformanceSignpost.begin("Parser.parse")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.parse) : nil
        defer {
            PerformanceSignpost.end("Parser.parse", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.parse, since: timer)
            }
        }
        consumeNewlines()
        guard let token = peekToken() else { return .object(JSONObject()) }
        if token.kind == .eof {
            return .object(JSONObject())
        }
        if token.kind == .leftBracket {
            guard let array = try parseArrayValue(keyToken: token, key: nil) else {
                throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "array")
            }
            return array
        }
        if isObjectStart(token: token) {
            return .object(try parseObject(currentIndent: 0))
        }
        return try parseInlineValue()
    }

    private func isObjectStart(token: Token) -> Bool {
        switch token.kind {
        case .identifier, .stringLiteral:
            guard let next = peekToken(offset: 1) else { return false }
            switch next.kind {
            case .colon, .leftBracket:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    private mutating func parseObject(currentIndent: Int) throws -> JSONObject {
        let signpostID = PerformanceSignpost.begin("Parser.parseObject")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.parseObject) : nil
        defer {
            PerformanceSignpost.end("Parser.parseObject", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.parseObject, since: timer)
            }
        }
        var result = JSONObject()
        while true {
            consumeNewlines()
            guard let token = peekToken() else { break }
            switch token.kind {
            case .indent:
                advance()
                continue
            case .identifier(let key), .stringLiteral(let key):
                advance()
                if let arrayValue = try parseArrayValue(keyToken: token, key: key) {
                    result[key] = arrayValue
                    continue
                }
                try expect(kind: .colon)
                if matchNewline() {
                    if let indentLevel = try? expectIndent() {
                        let nested = try parseObject(currentIndent: indentLevel)
                        result[key] = .object(nested)
                    } else {
                        result[key] = .object(JSONObject())
                    }
                } else {
                    if let next = peekToken(), next.kind == .eof {
                        result[key] = .object(JSONObject())
                    } else {
                        let value = try parseInlineValue()
                        result[key] = value
                    }
                }
            case .dedent(let level):
                if level < currentIndent {
                    return result
                }
                advance()
            case .dash:
                return result
            case .eof:
                return result
            default:
                throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "identifier")
            }
        }
        return result
    }

    private mutating func parseValue() throws -> JSONValue {
        let signpostID = PerformanceSignpost.begin("Parser.parseValue")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.parseValue) : nil
        defer {
            PerformanceSignpost.end("Parser.parseValue", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.parseValue, since: timer)
            }
        }
        consumeNewlines()
        guard let token = peekToken() else {
            throw ParserError.unexpectedToken(line: 0, column: 0, expected: "value")
        }
        switch token.kind {
        case .leftBracket:
            guard let array = try parseArrayValue(keyToken: token, key: nil) else {
                throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "array")
            }
            return array
        default:
            return try parseStandaloneValue()
        }
    }

    private mutating func parseStandaloneValue() throws -> JSONValue {
        if let simple = try parseSimpleStandaloneValue() {
            return simple
        }
        chunkBuffer.removeAll(keepingCapacity: true)
        while let token = peekToken() {
            switch token.kind {
            case .newline, .eof, .dedent:
                guard let context = chunkBuffer.first else {
                    throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "value")
                }
                return try buildValue(from: chunkBuffer, contextToken: context, endIndex: token.range.lowerBound)
            default:
                chunkBuffer.append(token)
                advance()
            }
        }
        guard let context = chunkBuffer.first else {
            throw ParserError.unexpectedToken(line: 0, column: 0, expected: "value")
        }
        let endIndex = chunkBuffer.last?.range.upperBound
        return try buildValue(from: chunkBuffer, contextToken: context, endIndex: endIndex)
    }

    private mutating func parseArrayValue(keyToken: Token, key: String?) throws -> JSONValue? {
        let signpostID = PerformanceSignpost.begin("Parser.parseArrayValue")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.parseArrayValue) : nil
        defer {
            PerformanceSignpost.end("Parser.parseArrayValue", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.parseArrayValue, since: timer)
            }
        }
        guard let bracketToken = peekToken(), bracketToken.kind == .leftBracket else { return nil }
        let (length, delimiter) = try parseArraySignature(contextToken: keyToken)
        guard let next = peekToken() else {
            throw ParserError.unexpectedToken(line: keyToken.line, column: keyToken.column, expected: "array declaration")
        }

        switch next.kind {
        case .leftBrace:
            advance()
            let headers = try parseHeaders(delimiter: delimiter)
            try expect(kind: .colon)
            guard matchNewline() else {
                throw ParserError.unexpectedToken(line: keyToken.line, column: keyToken.column, expected: "newline before tabular rows")
            }
            if length == 0 {
                if hasPendingIndent(), !options.lenientArrays {
                    throw ParserError.inlineArrayLengthMismatch(expected: length, actual: length + 1, line: keyToken.line, column: keyToken.column)
                }
                return .array([])
            }
            _ = try expectIndent()
            let rows = try parseTabularRows(length: length, headers: headers, contextToken: keyToken, delimiter: delimiter)
            return .array(rows)
        case .colon:
            advance()
            if matchNewline() {
                if length == 0 {
                    if hasPendingIndent(), !options.lenientArrays {
                        throw ParserError.inlineArrayLengthMismatch(expected: length, actual: length + 1, line: keyToken.line, column: keyToken.column)
                    }
                    return .array([])
                }
                let indentLevel = try expectIndent()
                let values = try parseListArray(length: length, baseIndent: indentLevel, contextToken: keyToken)
                return .array(values)
            } else {
                let values = try readRowValues(delimiter: delimiter)
                if values.count != length && !options.lenientArrays {
                    throw ParserError.inlineArrayLengthMismatch(expected: length, actual: values.count, line: keyToken.line, column: keyToken.column)
                }
                return .array(values)
            }
        default:
            return nil
        }
    }

    private mutating func parseArraySignature(contextToken: Token) throws -> (length: Int, delimiter: ArrayDelimiter) {
        advance() // consume '['
        var lengthLiteral: String?
        var delimiter: ArrayDelimiter = .comma
        while let token = peekToken() {
            switch token.kind {
            case .number(let literal):
                lengthLiteral = literal
                advance()
            case .delimiterTab:
                delimiter = .tab
                advance()
            case .pipe:
                delimiter = .pipe
                advance()
            case .comma:
                delimiter = .comma
                advance()
            case .rightBracket:
                advance()
                guard let literal = lengthLiteral, let length = Int(literal) else {
                    throw ParserError.invalidNumberLiteral(lengthLiteral ?? "", line: contextToken.line, column: contextToken.column)
                }
                return (length, delimiter)
            default:
                advance()
            }
        }
        throw ParserError.unexpectedToken(line: contextToken.line, column: contextToken.column, expected: "] after array declaration")
    }

    private mutating func parseHeaders(delimiter: ArrayDelimiter) throws -> [String] {
        var headers: [String] = []
        while let token = peekToken() {
            switch token.kind {
            case .identifier(let field), .stringLiteral(let field):
                headers.append(field)
                advance()
                continue
            case .comma where delimiter == .comma:
                advance()
                continue
            case .delimiterTab where delimiter == .tab:
                advance()
                continue
            case .pipe where delimiter == .pipe:
                advance()
                continue
            case .rightBrace:
                advance()
                return headers
            default:
                advance()
            }
        }
        return headers
    }

    private mutating func parseTabularRows(length: Int, headers: [String], contextToken: Token, delimiter: ArrayDelimiter) throws -> [JSONValue] {
        var rows: [JSONValue] = []
        rows.reserveCapacity(length)
        for _ in 0..<length {
            let values = try readRowValues(delimiter: delimiter)
            let adjustedValues: [JSONValue]
            if values.count == headers.count {
                adjustedValues = values
            } else if options.lenientArrays {
                adjustedValues = normalizeRow(values, expected: headers.count)
            } else {
                throw ParserError.tabularRowFieldMismatch(expected: headers.count, actual: values.count, line: contextToken.line, column: contextToken.column)
            }
            var object = JSONObject()
            for (index, header) in headers.enumerated() {
                object[header] = adjustedValues[index]
            }
            rows.append(.object(object))
        }
        consumeNewlines()
        if let token = peekToken() {
            switch token.kind {
            case .dedent:
                advance()
            case .indent:
                throw ParserError.unexpectedToken(line: contextToken.line, column: contextToken.column, expected: "end of tabular rows")
            default:
                break
            }
        }
        return rows
    }

    private func normalizeRow(_ values: [JSONValue], expected: Int) -> [JSONValue] {
        if values.count >= expected {
            return Array(values.prefix(expected))
        }
        var padded = values
        for _ in values.count..<expected {
            padded.append(.null)
        }
        return padded
    }

    private mutating func parseListArray(length: Int, baseIndent: Int, contextToken: Token) throws -> [JSONValue] {
        let signpostID = PerformanceSignpost.begin("Parser.parseListArray")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.parseListArray) : nil
        defer {
            PerformanceSignpost.end("Parser.parseListArray", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.parseListArray, since: timer)
            }
        }
        var values: [JSONValue] = []
        values.reserveCapacity(length)

        while values.count < length {
            consumeNewlines()
            guard let token = peekToken() else {
                if options.lenientArrays {
                    values.append(contentsOf: Array(repeating: .null, count: length - values.count))
                    break
                }
                throw unexpectedToken(nil, expected: "list item '-'")
            }
            if token.kind != .dash {
                if options.lenientArrays {
                    values.append(contentsOf: Array(repeating: .null, count: length - values.count))
                    break
                }
                throw unexpectedToken(token, expected: "list item '-'")
            }

            advance()
            let item = try parseListArrayItem(baseIndent: baseIndent, contextToken: contextToken)
            values.append(item)
        }

        consumeNewlines()
        while let token = peekToken(), token.kind == .dash {
            if options.lenientArrays {
                advance()
                _ = try parseListArrayItem(baseIndent: baseIndent, contextToken: contextToken)
                continue
            }
            throw unexpectedToken(token, expected: "end of list items")
        }

        consumeNewlines()
        if let token = peekToken(), token.kind == .dash {
            throw unexpectedToken(token, expected: "end of list items")
        }

        return values
    }

    private mutating func parseListArrayItem(baseIndent: Int, contextToken: Token) throws -> JSONValue {
        if matchNewline() {
            if let token = peekToken(), case .indent = token.kind {
                let nestedIndent = try expectIndent()
                let object = try parseObject(currentIndent: nestedIndent)
                return .object(object)
            }
            return .object(JSONObject())
        }

        guard let next = peekToken() else {
            throw ParserError.unexpectedToken(line: contextToken.line, column: contextToken.column, expected: "value after '-'")
        }

        if next.kind == .leftBracket {
            if let nested = try parseArrayValue(keyToken: next, key: nil) {
                return nested
            }
        }

        if case .identifier = next.kind {
            if let upcoming = peekToken(offset: 1), upcoming.kind == .colon {
                let object = try parseObject(currentIndent: baseIndent)
                return .object(object)
            }
            if let bracket = peekToken(offset: 1), bracket.kind == .leftBracket {
                let object = try parseObject(currentIndent: baseIndent)
                return .object(object)
            }
        }

        if case .dedent = next.kind {
            return .object(JSONObject())
        }

        if let simple = try parseSimpleScalarValue() {
            return simple
        }

        return try parseValue()
    }

    private mutating func parseSimpleScalarValue() throws -> JSONValue? {
        guard let token = peekToken() else { return nil }
        switch token.kind {
        case .identifier, .number, .stringLiteral:
            advance()
            return try interpretSingleToken(token)
        default:
            return nil
        }
    }

    private mutating func readRowValues(delimiter: ArrayDelimiter) throws -> [JSONValue] {
        let signpostID = PerformanceSignpost.begin("Parser.readRowValues")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.readRowValues) : nil
        defer {
            PerformanceSignpost.end("Parser.readRowValues", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.readRowValues, since: timer)
            }
        }
        var values: [JSONValue] = []
        rowChunkBuffer.removeAll(keepingCapacity: true)

        func flushChunk() throws {
            guard !rowChunkBuffer.isEmpty else { return }
            guard let context = rowChunkBuffer.first else { return }
            let endIndex = rowChunkBuffer.last?.range.upperBound
            let value = try buildValue(from: rowChunkBuffer, contextToken: context, endIndex: endIndex)
            values.append(value)
            rowChunkBuffer.removeAll(keepingCapacity: true)
        }

        while let token = peekToken() {
            switch token.kind {
            case .newline:
                advance()
                try flushChunk()
                return values
            case .eof:
                try flushChunk()
                return values
            case .comma where delimiter == .comma:
                advance()
                try flushChunk()
            case .delimiterTab where delimiter == .tab:
                advance()
                try flushChunk()
            case .pipe where delimiter == .pipe:
                advance()
                try flushChunk()
            case .indent, .dedent:
                advance()
            default:
                rowChunkBuffer.append(token)
                advance()
            }
        }
        try flushChunk()
        return values
    }

    private mutating func parseInlineValue() throws -> JSONValue {
        chunkBuffer.removeAll(keepingCapacity: true)
        while let token = peekToken() {
            switch token.kind {
            case .newline, .eof, .dedent:
                guard let context = chunkBuffer.first else {
                    throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "value")
                }
                return try buildValue(from: chunkBuffer, contextToken: context, endIndex: token.range.lowerBound)
            default:
                chunkBuffer.append(token)
                advance()
            }
        }
        guard let context = chunkBuffer.first else {
            throw ParserError.unexpectedToken(line: 0, column: 0, expected: "value")
        }
        let endIndex = chunkBuffer.last?.range.upperBound
        return try buildValue(from: chunkBuffer, contextToken: context, endIndex: endIndex)
    }

    private mutating func parseSimpleStandaloneValue() throws -> JSONValue? {
        guard let first = peekToken() else { return nil }
        switch first.kind {
        case .identifier, .number, .stringLiteral:
            if let next = peekToken(offset: 1) {
                switch next.kind {
                case .newline, .eof, .dedent:
                    advance()
                    return try interpretSingleToken(first)
                default:
                    return nil
                }
            } else {
                advance()
                return try interpretSingleToken(first)
            }
        default:
            return nil
        }
    }

    private func buildValue(from tokens: [Token], contextToken: Token, endIndex: Int?) throws -> JSONValue {
        let signpostID = PerformanceSignpost.begin("Parser.buildValue")
        let timer = ParserPerformanceTracker.enabled ? ParserPerformanceTracker.begin(.buildValue) : nil
        defer {
            PerformanceSignpost.end("Parser.buildValue", id: signpostID)
            if ParserPerformanceTracker.enabled {
                ParserPerformanceTracker.end(.buildValue, since: timer)
            }
        }
        guard !tokens.isEmpty else {
            throw ParserError.unexpectedToken(line: contextToken.line, column: contextToken.column, expected: "value")
        }
        if tokens.count == 1 {
            return try interpretSingleToken(tokens[0])
        }
        guard let first = tokens.first else {
            return .string("")
        }
        let start = max(0, min(sourceBytes.count, first.range.lowerBound))
        let resolvedEnd = endIndex ?? tokens.last?.range.upperBound ?? start
        var end = max(start, min(sourceBytes.count, resolvedEnd))
        while end > start {
            let byte = sourceBytes[end - 1]
            if byte == 0x0A || byte == 0x0D {
                end -= 1
                continue
            }
            break
        }
        let slice = sourceBytes[start..<end]
        let string = String(decoding: slice, as: UTF8.self)
        return .string(string)
    }

    private func interpretSingleToken(_ token: Token) throws -> JSONValue {
        switch token.kind {
        case .stringLiteral(let value):
            return .string(value)
        case .number(let literal):
            guard let number = Double(literal) else {
                throw ParserError.invalidNumberLiteral(literal, line: token.line, column: token.column)
            }
            return .number(number)
        case .identifier(let word):
            if word == "true" {
                return .bool(true)
            } else if word == "false" {
                return .bool(false)
            } else if word == "null" {
                return .null
            } else {
                return .string(word)
            }
        default:
            return .string(literal(for: token))
        }
    }

    private func literal(for token: Token) -> String {
        switch token.kind {
        case .identifier(let value):
            return value
        case .number(let literal):
            return literal
        case .stringLiteral(let value):
            return value
        case .comma:
            return ","
        case .pipe:
            return "|"
        case .delimiterTab:
            return "\t"
        case .colon:
            return ":"
        case .dash:
            return "-"
        case .leftBracket:
            return "["
        case .rightBracket:
            return "]"
        case .leftBrace:
            return "{"
        case .rightBrace:
            return "}"
        default:
            return ""
        }
    }

    private mutating func expect(kind expected: TokenKind) throws {
        consumeNewlines()
        guard let token = peekToken(), token.kind == expected else {
            let token = peekToken()
            throw ParserError.unexpectedToken(line: token?.line ?? 0, column: token?.column ?? 0, expected: "\(expected)")
        }
        advance()
    }

    private mutating func expectIndent() throws -> Int {
        consumeNewlines()
        guard let token = peekToken(), case .indent(let level) = token.kind else {
            throw ParserError.unexpectedToken(line: peekToken()?.line ?? 0, column: peekToken()?.column ?? 0, expected: "indent")
        }
        advance()
        return level
    }

    @discardableResult
    private mutating func matchNewline() -> Bool {
        var matched = false
        while let token = peekToken(), token.kind == .newline {
            advance()
            matched = true
        }
        return matched
    }

    private mutating func consumeNewlines() {
        while let token = peekToken(), token.kind == .newline {
            advance()
        }
    }

    private func hasPendingIndent() -> Bool {
        guard let token = peekToken() else { return false }
        if case .indent = token.kind {
            return true
        }
        return false
    }

    private func unexpectedToken(_ token: Token?, expected: String) -> ParserError {
        ParserError.unexpectedToken(
            line: token?.line ?? 0,
            column: token?.column ?? 0,
            expected: expected
        )
    }

    private func peekToken(offset: Int = 0) -> Token? {
        let position = index + offset
        guard position < tokens.count else { return nil }
        return tokens[position]
    }

    private func peekToken() -> Token? {
        guard index < tokens.count else { return nil }
        return tokens[index]
    }

    private mutating func advance() {
        index += 1
    }
}
