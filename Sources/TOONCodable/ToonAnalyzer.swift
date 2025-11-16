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
        return ScalarFormatter.scalarString(value, delimiter: delimiterChar)
    }
}
