import Foundation

/// Token produced by the TOON lexer.
public struct Token: Equatable {
    public let kind: TokenKind
    public let range: Range<Int>
    public let line: Int
    public let column: Int
}

/// Individual token kinds discovered during lexing.
public enum TokenKind: Equatable {
    case identifier(String)
    case number(String)
    case stringLiteral(String)
    case colon
    case comma
    case delimiterTab
    case pipe
    case dash
    case leftBracket
    case rightBracket
    case leftBrace
    case rightBrace
    case newline
    case indent(level: Int)
    case dedent(level: Int)
    case eof
}

public enum LexerError: Error, Equatable, LocalizedError {
    case invalidIndentation(line: Int, column: Int, description: String)
    case unexpectedCharacter(line: Int, column: Int, character: Character)
    case unterminatedString(line: Int, column: Int)

    public var errorDescription: String? {
        switch self {
        case let .invalidIndentation(line, column, description):
            return "Invalid indentation at \(line):\(column) – \(description)"
        case let .unexpectedCharacter(line, column, character):
            return "Unexpected character '\(character)' at \(line):\(column)"
        case let .unterminatedString(line, column):
            return "Unterminated string starting at \(line):\(column)"
        }
    }
}

/// Streaming lexer that produces indentation-aware tokens.
public struct Lexer {
    private let buffer: [UInt8]
    private var index: Int = 0
    private var line: Int = 1
    private var column: Int = 1
    private var lineStart = true
    private var indentStack: [Int] = [0]
    private var pendingIndentTokens: [Token] = []

    public init(input: String) {
        self.buffer = Array(input.utf8)
    }

    public static func tokenize(_ input: String) throws -> [Token] {
        var lexer = Lexer(input: input)
        var tokens: [Token] = []
        while true {
            let token = try lexer.nextToken()
            tokens.append(token)
            if token.kind == .eof { break }
        }
        return tokens
    }

private enum ASCII {
    static let newline = Character("\n").asciiValue!
    static let carriageReturn = Character("\r").asciiValue!
    static let colon = Character(":").asciiValue!
    static let comma = Character(",").asciiValue!
    static let leftBracket = Character("[").asciiValue!
    static let rightBracket = Character("]").asciiValue!
    static let leftBrace = Character("{").asciiValue!
    static let rightBrace = Character("}").asciiValue!
    static let pipe = Character("|").asciiValue!
    static let quote = Character("\"").asciiValue!
    static let backslash = Character("\\").asciiValue!
    static let space = Character(" ").asciiValue!
    static let tab = Character("\t").asciiValue!
    static let period = Character(".").asciiValue!
    static let dash = Character("-").asciiValue!
    static let letterN = Character("n").asciiValue!
    static let letterT = Character("t").asciiValue!
    static let letterR = Character("r").asciiValue!
}

private mutating func nextToken() throws -> Token {
        if !pendingIndentTokens.isEmpty {
            return pendingIndentTokens.removeFirst()
        }

        if index >= buffer.count {
            if indentStack.count > 1 {
                indentStack.removeLast()
                return makeZeroLengthToken(kind: .dedent(level: indentStack.last ?? 0))
            }
            return makeZeroLengthToken(kind: .eof)
        }

        if lineStart {
            try emitIndentationIfNeeded()
            if !pendingIndentTokens.isEmpty {
                lineStart = false
                return pendingIndentTokens.removeFirst()
            }
            if index < buffer.count, buffer[index] != ASCII.newline, buffer[index] != ASCII.carriageReturn {
                lineStart = false
            }
        }

        skipInlineWhitespace()
        if index >= buffer.count {
            return try nextToken()
        }

        let byte = buffer[index]
        switch byte {
        case ASCII.newline:
            advance()
            let token = makeZeroLengthToken(kind: .newline)
            line += 1
            column = 1
            lineStart = true
            return token
        case ASCII.carriageReturn:
            advance()
            return try nextToken()
        case ASCII.colon:
            advance()
            return makeZeroLengthToken(kind: .colon)
        case ASCII.comma:
            advance()
            return makeZeroLengthToken(kind: .comma)
        case ASCII.dash:
            if let next = peekByte(offset: 1), isDigit(next) {
                return lexNumber(startingWithMinus: true)
            } else {
                advance()
                return makeZeroLengthToken(kind: .dash)
            }
        case ASCII.leftBracket:
            advance()
            return makeZeroLengthToken(kind: .leftBracket)
        case ASCII.rightBracket:
            advance()
            return makeZeroLengthToken(kind: .rightBracket)
        case ASCII.leftBrace:
            advance()
            return makeZeroLengthToken(kind: .leftBrace)
        case ASCII.rightBrace:
            advance()
            return makeZeroLengthToken(kind: .rightBrace)
        case ASCII.pipe:
            advance()
            return makeZeroLengthToken(kind: .pipe)
        case ASCII.tab:
            advance()
            return makeZeroLengthToken(kind: .delimiterTab)
        case ASCII.quote:
            return try lexStringLiteral()
        default:
            if isDigit(byte) {
                return lexNumber()
            } else if isIdentifierStart(byte) {
                return lexIdentifier()
            } else if byte == ASCII.space {
                // Should not reach due to skipInlineWhitespace
                advance()
                return try nextToken()
            } else {
                let character = Character(UnicodeScalar(byte))
                throw LexerError.unexpectedCharacter(line: line, column: column, character: character)
            }
        }
    }

    private mutating func emitIndentationIfNeeded() throws {
        var spaces = 0
        var localIndex = index
        while localIndex < buffer.count {
            let byte = buffer[localIndex]
            if byte == ASCII.space {
                spaces += 1
                localIndex += 1
            } else if byte == ASCII.tab {
                throw LexerError.invalidIndentation(line: line, column: column + spaces, description: "Tabs are not permitted")
            } else if byte == ASCII.newline || byte == ASCII.carriageReturn {
                // blank line
                index = localIndex
                return
            } else {
                break
            }
        }

        if spaces == (indentStack.last ?? 0) {
            index = localIndex
            column = spaces + 1
            return
        } else if spaces > (indentStack.last ?? 0) {
            indentStack.append(spaces)
            index = localIndex
            column = spaces + 1
            pendingIndentTokens.append(makeZeroLengthToken(kind: .indent(level: spaces)))
            return
        } else {
            // dedent(s)
            index = localIndex
            column = spaces + 1
            while let last = indentStack.last, spaces < last {
                indentStack.removeLast()
                pendingIndentTokens.append(makeZeroLengthToken(kind: .dedent(level: indentStack.last ?? 0)))
            }
            if indentStack.last != spaces {
                throw LexerError.invalidIndentation(line: line, column: column, description: "Mismatched dedent")
            }
        }
    }

    private mutating func lexIdentifier() -> Token {
        let start = index
        let startColumn = column
        advance()
        while index < buffer.count {
            let byte = buffer[index]
            if isIdentifierContinuation(byte) {
                advance()
            } else {
                break
            }
        }
        let end = index
        let substring = String(decoding: buffer[start..<end], as: UTF8.self)
        return Token(kind: .identifier(substring), range: start..<end, line: line, column: startColumn)
    }

    private mutating func lexNumber(startingWithMinus: Bool = false) -> Token {
        let start = index
        let startColumn = column
        if startingWithMinus {
            advance()
        }
        while index < buffer.count, isDigit(buffer[index]) {
            advance()
        }
        if index < buffer.count, buffer[index] == ASCII.period {
            advance()
            while index < buffer.count, isDigit(buffer[index]) {
                advance()
            }
        }
        let end = index
        let substring = String(decoding: buffer[start..<end], as: UTF8.self)
        return Token(kind: .number(substring), range: start..<end, line: line, column: startColumn)
    }

    private mutating func lexStringLiteral() throws -> Token {
        let start = index
        let startColumn = column
        advance() // opening quote
        var scalars: [UInt8] = []
        while index < buffer.count {
            let byte = buffer[index]
            if byte == ASCII.quote {
                advance()
                let string = String(decoding: scalars, as: UTF8.self)
                return Token(kind: .stringLiteral(string), range: start..<index, line: line, column: startColumn)
            } else if byte == ASCII.backslash {
                advance()
                guard index < buffer.count else {
                    throw LexerError.unterminatedString(line: line, column: column)
                }
                let escape = buffer[index]
                let escaped: UInt8
                switch escape {
                case ASCII.quote: escaped = ASCII.quote
                case ASCII.backslash: escaped = ASCII.backslash
                case ASCII.letterN: escaped = ASCII.newline
                case ASCII.letterT: escaped = ASCII.tab
                case ASCII.letterR: escaped = ASCII.carriageReturn
                default:
                    escaped = escape
                }
                scalars.append(escaped)
                advance()
            } else {
                scalars.append(byte)
                advance()
            }
        }
        throw LexerError.unterminatedString(line: line, column: startColumn)
    }

    private mutating func skipInlineWhitespace() {
        while index < buffer.count {
            let byte = buffer[index]
            if byte == ASCII.space {
                advance()
            } else {
                break
            }
        }
    }

    private mutating func advance() {
        index += 1
        column += 1
    }

    private func makeZeroLengthToken(kind: TokenKind) -> Token {
        Token(kind: kind, range: index..<index, line: line, column: column)
    }

    private func isIdentifierStart(_ byte: UInt8) -> Bool {
        if byte >= 0x80 {
            return true
        }
        return (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || byte == UInt8(ascii: "_")
    }

    private func isIdentifierContinuation(_ byte: UInt8) -> Bool {
        if byte >= 0x80 {
            return true
        }
        return isIdentifierStart(byte)
            || isDigit(byte)
            || byte == ASCII.dash
            || byte == ASCII.period
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    private func peekByte(offset: Int = 0) -> UInt8? {
        let position = index + offset
        guard position < buffer.count else { return nil }
        return buffer[position]
    }
}
