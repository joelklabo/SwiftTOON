import Foundation

enum ToonQuoter {
    static func encode(_ value: String, delimiter: Character = ",") -> String {
        if needsQuotes(value, delimiter: delimiter) {
            return "\"" + escape(value) + "\""
        } else {
            return value
        }
    }

    static func needsQuotes(_ value: String, delimiter: Character = ",") -> Bool {
        if value.isEmpty { return true }
        if value.first?.isWhitespace == true || value.last?.isWhitespace == true { return true }
        if looksLikeLiteral(value) { return true }
        if looksLikeNumber(value) { return true }
        if value.contains(delimiter) { return true }
        for scalar in value {
            switch scalar {
            case "\n", "\r", "\t", "\"", "\\", ":", "[", "]", "{", "}", ",":
                return true
            default:
                continue
            }
        }
        return false
    }

    private static func looksLikeLiteral(_ value: String) -> Bool {
        let lowercase = value.lowercased()
        return lowercase == "true" || lowercase == "false" || lowercase == "null"
    }

    private static func looksLikeNumber(_ value: String) -> Bool {
        var index = value.startIndex
        let end = value.endIndex
        if index == end { return false }
        if value[index] == "+" || value[index] == "-" {
            index = value.index(after: index)
            if index == end { return false }
        }
        var digits = 0
        while index < end, value[index].isWholeNumber {
            digits += 1
            index = value.index(after: index)
        }
        var hasFraction = false
        if index < end, value[index] == "." {
            hasFraction = true
            index = value.index(after: index)
            var fractionDigits = 0
            while index < end, value[index].isWholeNumber {
                fractionDigits += 1
                index = value.index(after: index)
            }
            if fractionDigits == 0 { return false }
            digits += fractionDigits
        }
        if digits == 0 { return false }
        if index < end, value[index] == "e" || value[index] == "E" {
            index = value.index(after: index)
            if index < end, value[index] == "+" || value[index] == "-" {
                index = value.index(after: index)
            }
            var expDigits = 0
            while index < end, value[index].isWholeNumber {
                expDigits += 1
                index = value.index(after: index)
            }
            if expDigits == 0 { return false }
        }
        return index == end
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
