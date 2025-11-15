import Foundation
import CoreFoundation

enum JSONValueConversionError: Error {
    case unsupportedValue
}

public extension JSONValue {
    func toAny() -> Any {
        switch self {
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = value.toAny()
            }
            return result
        case .array(let array):
            return array.map { $0.toAny() }
        case .string(let string):
            return string
        case .number(let double):
            return double
        case .bool(let bool):
            return bool
        case .null:
            return NSNull()
        }
    }

    init(jsonObject: Any) throws {
        switch jsonObject {
        case let dict as [String: Any]:
            var result: [String: JSONValue] = [:]
            for (key, value) in dict {
                result[key] = try JSONValue(jsonObject: value)
            }
            self = .object(result)
        case let array as [Any]:
            self = .array(try array.map { try JSONValue(jsonObject: $0) })
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case _ as NSNull:
            self = .null
        default:
            throw JSONValueConversionError.unsupportedValue
        }
    }
}
