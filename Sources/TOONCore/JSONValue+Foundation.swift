import Foundation

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
}
