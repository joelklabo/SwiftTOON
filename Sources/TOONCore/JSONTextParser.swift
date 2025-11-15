import Foundation

enum JSONTextParserError: Error, LocalizedError {
    case unexpectedCharacter(Character, Int, Int)
    case unexpectedEndOfInput
    case invalidEscape(Int, Int)
    case invalidNumber(String, Int, Int)

    var errorDescription: String? {
        switch self {
        case let .unexpectedCharacter(char, line, column):
            return "Unexpected character '\(char)' at \(line):\(column)."
        case .unexpectedEndOfInput:
            return "Unexpected end of JSON input."
        case let .invalidEscape(line, column):
            return "Invalid escape sequence at \(line):\(column)."
        case let .invalidNumber(literal, line, column):
            return "Invalid number literal \(literal) at \(line):\(column)."
        }
    }
}

struct JSONTextParser {
    private let text: String
    private var index: String.Index
    private var line: Int = 1
    private var column: Int = 1

    init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    mutating func parse() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        guard index == text.endIndex else {
            throw unexpectedCharacter()
        }
        return value
    }

    private mutating func parseValue() throws -> JSONValue {
        guard let char = currentCharacter() else { throw JSONTextParserError.unexpectedEndOfInput }
        switch char {
        case "{":
            return try parseObject()
        case "[":
            return try parseArray()
        case "\"":
            return .string(try parseString())
        case "t":
            try expectLiteral("true")
            return .bool(true)
        case "f":
            try expectLiteral("false")
            return .bool(false)
        case "n":
            try expectLiteral("null")
            return .null
        case "-", "0"..."9":
            return try parseNumber()
        default:
            throw unexpectedCharacter(char)
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        advance()
        skipWhitespace()
        var object = JSONObject()
        if consumeIf("}") {
            return .object(object)
        }
        while true {
            skipWhitespace()
            guard currentCharacter() == "\"" else { throw unexpectedCharacter() }
            let key = try parseString()
            skipWhitespace()
            guard consumeIf(":") else { throw unexpectedCharacter() }
            skipWhitespace()
            let value = try parseValue()
            object[key] = value
            skipWhitespace()
            if consumeIf("}") {
                break
            }
            guard consumeIf(",") else { throw unexpectedCharacter() }
        }
        return .object(object)
    }

    private mutating func parseArray() throws -> JSONValue {
        advance()
        skipWhitespace()
        var elements: [JSONValue] = []
        if consumeIf("]") {
            return .array(elements)
        }
        while true {
            skipWhitespace()
            let value = try parseValue()
            elements.append(value)
            skipWhitespace()
            if consumeIf("]") {
                break
            }
            guard consumeIf(",") else { throw unexpectedCharacter() }
        }
        return .array(elements)
    }

    private mutating func parseString() throws -> String {
        advance() // opening quote
        var result = String()
        while let char = currentCharacter() {
            if char == "\"" {
                advance()
                return result
            } else if char == "\\" {
                advance()
                guard let escaped = currentCharacter() else { throw JSONTextParserError.unexpectedEndOfInput }
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "b": result.append("\u{0008}")
                case "f": result.append("\u{000C}")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "u":
                    advance()
                    let scalar = try parseUnicodeScalar()
                    result.append(String(scalar))
                    continue
                default:
                    throw JSONTextParserError.invalidEscape(line, column)
                }
                advance()
            } else {
                result.append(char)
                advance()
            }
        }
        throw JSONTextParserError.unexpectedEndOfInput
    }

    private mutating func parseUnicodeScalar() throws -> UnicodeScalar {
        guard let start = indexOfCurrent else { throw JSONTextParserError.unexpectedEndOfInput }
        var value: UInt32 = 0
        var current = start
        for _ in 0..<4 {
            guard current < text.endIndex else { throw JSONTextParserError.unexpectedEndOfInput }
            let char = text[current]
            guard let digit = char.hexDigitValue else { throw JSONTextParserError.invalidEscape(line, column) }
            value = value * 16 + UInt32(digit)
            current = text.index(after: current)
        }
        index = current
        column += 4
        guard let scalar = UnicodeScalar(value) else { throw JSONTextParserError.invalidEscape(line, column) }
        return scalar
    }

    private mutating func parseNumber() throws -> JSONValue {
        let startIndex = index
        var hasDecimal = false
        if consumeIf("-") {
            // sign consumed
        }
        try consumeDigits()
        if consumeIf(".") {
            hasDecimal = true
            try consumeDigits()
        }
        if consumeIf("e") || consumeIf("E") {
            hasDecimal = true
            if consumeIf("+") || consumeIf("-") {}
            try consumeDigits()
        }
        let literal = String(text[startIndex..<index])
        guard let value = Double(literal) else {
            throw JSONTextParserError.invalidNumber(literal, line, column)
        }
        if !hasDecimal, let int = Int(literal) {
            return .number(Double(int))
        }
        return .number(value)
    }

    private mutating func consumeDigits() throws {
        guard let char = currentCharacter(), char.isNumber else {
            throw unexpectedCharacter()
        }
        while let char = currentCharacter(), char.isNumber {
            advance()
        }
    }

    private mutating func expectLiteral(_ literal: String) throws {
        for character in literal {
            guard currentCharacter() == character else { throw unexpectedCharacter() }
            advance()
        }
    }

    private mutating func skipWhitespace() {
        while let char = currentCharacter(), char.isWhitespace {
            advance()
        }
    }

    private func currentCharacter() -> Character? {
        guard index < text.endIndex else { return nil }
        return text[index]
    }

    private var indexOfCurrent: String.Index? {
        guard index < text.endIndex else { return nil }
        return index
    }

    @discardableResult
    private mutating func consumeIf(_ character: Character) -> Bool {
        guard currentCharacter() == character else { return false }
        advance()
        return true
    }

    private mutating func advance() {
        guard index < text.endIndex else { return }
        if text[index] == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        index = text.index(after: index)
    }

    private func unexpectedCharacter(_ char: Character? = nil) -> JSONTextParserError {
        .unexpectedCharacter(char ?? currentCharacter() ?? "\0", line, column)
    }
}
