import Foundation
import TOONCore

struct MalformedTOONCase {
    enum Expectation: CustomStringConvertible {
        enum LexerKind: CustomStringConvertible {
            case invalidIndentation
            case unterminatedString

            var description: String {
                switch self {
                case .invalidIndentation:
                    return "LexerError.invalidIndentation"
                case .unterminatedString:
                    return "LexerError.unterminatedString"
                }
            }

            func matches(_ error: LexerError) -> Bool {
                switch (self, error) {
                case (.invalidIndentation, .invalidIndentation(_, _, _)):
                    return true
                case (.unterminatedString, .unterminatedString(_, _)):
                    return true
                default:
                    return false
                }
            }
        }

        enum ParserKind: CustomStringConvertible {
            case inlineArrayLengthMismatch

            var description: String {
                switch self {
                case .inlineArrayLengthMismatch:
                    return "ParserError.inlineArrayLengthMismatch"
                }
            }

            func matches(_ error: ParserError) -> Bool {
                switch (self, error) {
                case (.inlineArrayLengthMismatch, .inlineArrayLengthMismatch(_, _, _, _)):
                    return true
                default:
                    return false
                }
            }
        }

        case lexer(LexerKind)
        case parser(ParserKind)

        var description: String {
            switch self {
            case .lexer(let kind):
                return kind.description
            case .parser(let kind):
                return kind.description
            }
        }

        func matches(_ error: Error) -> Bool {
            switch self {
            case .lexer(let kind):
                guard let lexerError = error as? LexerError else { return false }
                return kind.matches(lexerError)
            case .parser(let kind):
                guard let parserError = error as? ParserError else { return false }
                return kind.matches(parserError)
            }
        }
    }

    let toon: String
    let expectation: Expectation
}

struct MalformedTOONGenerator {
    private enum Scenario: CaseIterable {
        case zeroLengthListWithValues
        case zeroLengthTabularWithRows
        case invalidIndentation
        case unterminatedString
    }

    private var rng: LCG
    private var scenarioIndex: Int = 0
    private let keys = ["items", "data", "records", "payload", "values"]

    init(seed: UInt64) {
        self.rng = LCG(state: seed)
    }

    mutating func nextCase() -> MalformedTOONCase {
        let scenario = Scenario.allCases[scenarioIndex % Scenario.allCases.count]
        scenarioIndex += 1
        switch scenario {
        case .zeroLengthListWithValues:
            return zeroLengthListCase()
        case .zeroLengthTabularWithRows:
            return zeroLengthTabularCase()
        case .invalidIndentation:
            return invalidIndentationCase()
        case .unterminatedString:
            return unterminatedStringCase()
        }
    }

    private mutating func zeroLengthListCase() -> MalformedTOONCase {
        let indent = String(repeating: " ", count: rng.nextBool() ? 2 : 4)
        let rows = Int(rng.nextInt(max: 3) + 1)
        var text = "\(randomKey())[0]:\n"
        for index in 0..<rows {
            text += "\(indent)- value\(index): \(rng.nextInt(max: 10))\n"
        }
        return MalformedTOONCase(toon: text, expectation: .parser(.inlineArrayLengthMismatch))
    }

    private mutating func zeroLengthTabularCase() -> MalformedTOONCase {
        let indent = String(repeating: " ", count: rng.nextBool() ? 2 : 4)
        let headers = randomHeaders()
        let literal = headers.map { header -> String in
            if header == "name" {
                return "\(randomName())"
            } else {
                return String(rng.nextInt(max: 50))
            }
        }.joined(separator: ",")
        var text = "\(randomKey())[0]{\(headers.joined(separator: ","))}:\n"
        text += "\(indent)\(literal)\n"
        return MalformedTOONCase(toon: text, expectation: .parser(.inlineArrayLengthMismatch))
    }

    private mutating func invalidIndentationCase() -> MalformedTOONCase {
        let tabIndent = "\t" + String(repeating: " ", count: Int(rng.nextInt(max: 3)))
        let text = """
        root:
        \(tabIndent)child: true
        """
        return MalformedTOONCase(toon: text, expectation: .lexer(.invalidIndentation))
    }

    private mutating func unterminatedStringCase() -> MalformedTOONCase {
        let value = randomName()
        let text = "title: \"\(value)"
        return MalformedTOONCase(toon: text, expectation: .lexer(.unterminatedString))
    }

    private mutating func randomKey() -> String {
        let base = keys[Int(rng.nextInt(max: keys.count))]
        return rng.nextBool() ? base : "\(base)_\(rng.nextInt(max: 100))"
    }

    private mutating func randomHeaders() -> [String] {
        let pool = ["id", "name", "score", "count", "flag"]
        var headers = pool.shuffled(using: &rng)
        headers = Array(headers.prefix(Int(rng.nextInt(max: 3) + 2)))
        return headers
    }

    private mutating func randomName() -> String {
        let names = ["Ada", "Lin", "Omar", "Ryu", "Ivy", "Zoe"]
        return names[Int(rng.nextInt(max: names.count))]
    }
}

private struct LCG: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }

    mutating func nextInt(max: Int) -> UInt64 {
        precondition(max > 0)
        return next() % UInt64(max)
    }

    mutating func nextBool() -> Bool {
        return (next() & 1) == 0
    }

}
