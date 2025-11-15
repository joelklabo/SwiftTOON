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
            return "Inline array declared with \(expected) values but found \(actual) at \(line):\(column)."
        case let .tabularRowFieldMismatch(expected, actual, line, column):
            return "Tabular row expected \(expected) fields but found \(actual) at \(line):\(column)."
        }
    }
}

public struct Parser {
    private var tokens: [Token]
    private var index: Int = 0
    private let sourceBytes: [UInt8]
    private enum ArrayDelimiter {
        case comma
        case tab
        case pipe
    }

    public init(input: String) throws {
        self.tokens = try Lexer.tokenize(input)
        self.sourceBytes = Array(input.utf8)
    }

    public mutating func parse() throws -> JSONValue {
        consumeNewlines()
        guard let token = peekToken() else { return .object([:]) }
        if token.kind == .eof {
            return .object([:])
        }
        if token.kind == .leftBracket {
            guard let array = try parseArrayValue(keyToken: token, key: nil) else {
                throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "array")
            }
            return array
        }
        if isObjectStart(token: token) {
            return .object(try parseObject())
        }
        return try parseValue()
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

    private mutating func parseObject() throws -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
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
                    if let _ = try? expectIndent() {
                        let nested = try parseObject()
                        result[key] = .object(nested)
                    } else {
                        result[key] = .object([:])
                    }
                } else {
                    if let next = peekToken(), next.kind == .eof {
                        result[key] = .object([:])
                    } else {
                        let value = try parseInlineValue()
                        result[key] = value
                    }
                }
            case .dedent:
                advance()
                return result
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
        var chunk: [Token] = []
        while let token = peekToken() {
            switch token.kind {
            case .newline, .eof, .dedent:
                guard let context = chunk.first else {
                    throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "value")
                }
                return try buildValue(from: chunk, contextToken: context, endIndex: token.range.lowerBound)
            default:
                chunk.append(token)
                advance()
            }
        }
        guard let context = chunk.first else {
            throw ParserError.unexpectedToken(line: 0, column: 0, expected: "value")
        }
        let endIndex = chunk.last?.range.upperBound
        return try buildValue(from: chunk, contextToken: context, endIndex: endIndex)
    }

    private mutating func parseArrayValue(keyToken: Token, key: String?) throws -> JSONValue? {
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
                return .array([])
            }
            _ = try expectIndent()
            let rows = try parseTabularRows(length: length, headers: headers, contextToken: keyToken, delimiter: delimiter)
            return .array(rows)
        case .colon:
            advance()
            if matchNewline() {
                if length == 0 {
                    return .array([])
                }
                let indentLevel = try expectIndent()
                let values = try parseListArray(length: length, baseIndent: indentLevel, contextToken: keyToken)
                return .array(values)
            } else {
                let values = try readRowValues(delimiter: delimiter)
                guard values.count == length else {
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
        for _ in 0..<length {
            let values = try readRowValues(delimiter: delimiter)
            guard values.count == headers.count else {
                throw ParserError.tabularRowFieldMismatch(expected: headers.count, actual: values.count, line: contextToken.line, column: contextToken.column)
            }
            var object: [String: JSONValue] = [:]
            for (index, header) in headers.enumerated() {
                object[header] = values[index]
            }
            rows.append(.object(object))
        }
        if let token = peekToken(), case .dedent = token.kind {
            advance()
        }
        return rows
    }

    private mutating func parseListArray(length: Int, baseIndent: Int, contextToken: Token) throws -> [JSONValue] {
        var values: [JSONValue] = []
        for _ in 0..<length {
            consumeNewlines()
            guard let dashToken = peekToken(), dashToken.kind == .dash else {
                let line = peekToken()?.line ?? contextToken.line
                let column = peekToken()?.column ?? contextToken.column
                throw ParserError.unexpectedToken(line: line, column: column, expected: "list item '-'")
            }
            advance()

            if matchNewline() {
                if let token = peekToken(), case .indent = token.kind {
                    _ = try expectIndent()
                    let object = try parseObject()
                    values.append(.object(object))
                } else {
                    values.append(.object([:]))
                }
                continue
            }

            guard let next = peekToken() else {
                throw ParserError.unexpectedToken(line: contextToken.line, column: contextToken.column, expected: "value after '-'")
            }

            if next.kind == .leftBracket {
                if let nested = try parseArrayValue(keyToken: next, key: nil) {
                    values.append(nested)
                    continue
                }
            }

            if case .identifier = next.kind {
                if let upcoming = peekToken(offset: 1), upcoming.kind == .colon {
                    let object = try parseObject()
                    values.append(.object(object))
                    continue
                }
                if let bracket = peekToken(offset: 1), bracket.kind == .leftBracket {
                    let object = try parseObject()
                    values.append(.object(object))
                    continue
                }
            }

            if case .dedent = next.kind {
                values.append(.object([:]))
                continue
            }

            let value = try parseValue()
            values.append(value)
        }

        if let token = peekToken(), case .dedent = token.kind {
            advance()
        }

        return values
    }

    private mutating func readRowValues(delimiter: ArrayDelimiter) throws -> [JSONValue] {
        var values: [JSONValue] = []
        var chunk: [Token] = []

        func flushChunk() throws {
            guard !chunk.isEmpty else { return }
            guard let context = chunk.first else { return }
            let endIndex = chunk.last?.range.upperBound
            let value = try buildValue(from: chunk, contextToken: context, endIndex: endIndex)
            values.append(value)
            chunk.removeAll(keepingCapacity: true)
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
                chunk.append(token)
                advance()
            }
        }
        try flushChunk()
        return values
    }

    private mutating func parseInlineValue() throws -> JSONValue {
        var chunk: [Token] = []
        while let token = peekToken() {
            switch token.kind {
            case .newline, .eof, .dedent:
                guard let context = chunk.first else {
                    throw ParserError.unexpectedToken(line: token.line, column: token.column, expected: "value")
                }
                return try buildValue(from: chunk, contextToken: context, endIndex: token.range.lowerBound)
            default:
                chunk.append(token)
                advance()
            }
        }
        guard let context = chunk.first else {
            throw ParserError.unexpectedToken(line: 0, column: 0, expected: "value")
        }
        let endIndex = chunk.last?.range.upperBound
        return try buildValue(from: chunk, contextToken: context, endIndex: endIndex)
    }

    private func buildValue(from tokens: [Token], contextToken: Token, endIndex: Int?) throws -> JSONValue {
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
        let end = max(start, min(sourceBytes.count, resolvedEnd))
        let slice = sourceBytes[start..<end]
        var string = String(decoding: slice, as: UTF8.self)
        if string.hasSuffix("\n") {
            string.removeLast()
            if string.hasSuffix("\r") {
                string.removeLast()
            }
        }
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
