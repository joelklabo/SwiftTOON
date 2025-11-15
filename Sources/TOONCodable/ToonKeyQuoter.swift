import Foundation

enum ToonKeyQuoter {
    static func encode(_ key: String) -> String {
        if needsQuotes(key) {
            return "\"" + escape(key) + "\""
        } else {
            return key
        }
    }

    static func needsQuotes(_ key: String) -> Bool {
        if key.isEmpty { return true }
        if key.first?.isWhitespace == true || key.last?.isWhitespace == true { return true }
        if key.first?.isNumber == true { return true }
        if key.first == "-" { return true }
        for scalar in key {
            switch scalar {
            case " ", "\t", "\n", ":", ",", "{", "}", "[", "]", "\"", "-":
                return true
            default:
                continue
            }
        }
        return false
    }

    private static func escape(_ value: String) -> String {
        var result = String()
        result.reserveCapacity(value.count)
        for scalar in value {
            switch scalar {
            case "\\":
                result.append("\\\\")
            case "\"":
                result.append("\\\"")
            case "\n":
                result.append("\\n")
            case "\r":
                result.append("\\r")
            case "\t":
                result.append("\\t")
            default:
                result.append(scalar)
            }
        }
        return result
    }
}
