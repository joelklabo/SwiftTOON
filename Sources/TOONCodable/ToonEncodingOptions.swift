import Foundation

public struct ToonEncodingOptions: Equatable {
    public enum Delimiter: Equatable {
        case comma
        case tab
        case pipe

        public init(character: Character) {
            switch character {
            case "\t":
                self = .tab
            case "|":
                self = .pipe
            default:
                self = .comma
            }
        }

        public var symbol: String {
            switch self {
            case .comma:
                return ","
            case .tab:
                return "\t"
            case .pipe:
                return "|"
            }
        }
    }

    public enum KeyFoldingMode: Equatable {
        case off
        case safe
    }

    public var delimiter: Delimiter
    public var indentWidth: Int
    public var keyFolding: KeyFoldingMode
    /// Maximum number of folded segments (nil means unlimited)
    public var flattenDepth: Int?

    public init(
        delimiter: Delimiter = .comma,
        indentWidth: Int = 2,
        keyFolding: KeyFoldingMode = .off,
        flattenDepth: Int? = nil
    ) {
        self.delimiter = delimiter
        self.indentWidth = max(0, indentWidth)
        self.keyFolding = keyFolding
        self.flattenDepth = flattenDepth
    }
}
