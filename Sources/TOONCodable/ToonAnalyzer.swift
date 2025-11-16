import Foundation
import TOONCore

public struct ToonAnalyzer {
    public enum ArrayRepresentation: Equatable {
        case empty
        case inline(values: [String])
        case tabular(headers: [String], rows: [[String]])
        case list
    }

    public static func analyzeArray(_ array: [JSONValue], schema: ToonSchema?, delimiterSymbol: String) -> ArrayRepresentation {
        if array.isEmpty {
            return .empty
        }
        if let schema {
            switch schema.arrayRepresentationHint {
            case .tabular(let headers):
                if let result = tabularRows(for: array, headers: headers, delimiterSymbol: delimiterSymbol) {
                    return .tabular(headers: result.headers, rows: result.rows)
                }
            case .list:
                return .list
            case .auto:
                break
            }
        }
        if let inline = inlineScalars(array, delimiterSymbol: delimiterSymbol) {
            return .inline(values: inline)
        }
        if let tabular = tabularRows(for: array, headers: nil, delimiterSymbol: delimiterSymbol) {
            return .tabular(headers: tabular.headers, rows: tabular.rows)
        }
        return .list
    }

    private static func inlineScalars(_ array: [JSONValue], delimiterSymbol: String) -> [String]? {
        var values: [String] = []
        values.reserveCapacity(array.count)
        for element in array {
            guard let scalar = scalarString(element, delimiterSymbol: delimiterSymbol) else {
                return nil
            }
            values.append(scalar)
        }
        return values
    }

    private static func tabularRows(for array: [JSONValue], headers: [String]?, delimiterSymbol: String) -> (headers: [String], rows: [[String]])? {
        let resolvedHeaders: [String]
        let requireExactFieldCount: Bool
        if let headers, !headers.isEmpty {
            resolvedHeaders = headers
            requireExactFieldCount = false
        } else {
            guard let first = array.first, case .object(let dict) = first else { return nil }
            resolvedHeaders = dict.orderedPairs().map { $0.0 }
            if resolvedHeaders.isEmpty {
                return nil
            }
            requireExactFieldCount = true
        }
        var rows: [[String]] = []
        rows.reserveCapacity(array.count)
        for element in array {
            guard case .object(let dict) = element else { return nil }
            if requireExactFieldCount && dict.count != resolvedHeaders.count {
                return nil
            }
            var row: [String] = []
            row.reserveCapacity(resolvedHeaders.count)
            for header in resolvedHeaders {
                guard let value = dict.value(forKey: header),
                      let scalar = scalarString(value, delimiterSymbol: delimiterSymbol) else {
                    return nil
                }
                row.append(scalar)
            }
            rows.append(row)
        }
        return (resolvedHeaders, rows)
    }

    private static func scalarString(_ value: JSONValue, delimiterSymbol: String) -> String? {
        let delimiterChar = delimiterSymbol.first ?? ","
        switch value {
        case .string(let string):
            return ToonQuoter.encode(string, delimiter: delimiterChar)
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

    private static func format(number: Double) -> String {
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

    private static func trimTrailingZeros(from string: String) -> String {
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
