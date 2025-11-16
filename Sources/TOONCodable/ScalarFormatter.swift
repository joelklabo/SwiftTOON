import Foundation
import TOONCore

struct ScalarFormatter {

    static func scalarString(_ value: JSONValue, delimiter: Character) -> String? {
        switch value {
        case .string(let string):
            return ToonQuoter.encode(string, delimiter: delimiter)
        case .number(let double):
            return format(number: double)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        default:
            return nil
        }
    }

    static func format(number: Double) -> String {
        if number.isNaN || number.isInfinite {
            return "null"
        }
        if number == 0 {
            return "0"
        }
        let posix = Locale(identifier: "en_US_POSIX")
        if number.rounded() == number {
            if number <= Double(Int.max) && number >= Double(Int.min) {
                return String(Int(number))
            } else {
                let fixed = String(format: "%.0f", locale: posix, number)
                return fixed
            }
        }
        let general = String(format: "%.*g", locale: posix, 16, number)
        if general.contains("e") || general.contains("E") {
            let fixed = String(format: "%.*f", locale: posix, 16, number)
            return trimTrailingZeros(from: fixed)
        } else {
            return general
        }
    }

    static func trimTrailingZeros(from string: String) -> String {
        var result = string
        if let dotIndex = result.firstIndex(of: ".") {
            var end = result.index(before: result.endIndex)
            while end > dotIndex && result[end] == "0" {
                result.remove(at: end)
                end = result.index(before: end)
            }
            if end == dotIndex {
                result.remove(at: dotIndex)
            }
        }
        return result
    }
}
