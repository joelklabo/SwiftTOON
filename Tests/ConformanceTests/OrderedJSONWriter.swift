import Foundation
import TOONCore

enum OrderedJSONEncodingError: Error {
    case invalidUTF8
    case invalidPrimitive
}

extension JSONValue {
    func orderedJSONData() throws -> Data {
        var writer = OrderedJSONWriter()
        try writer.append(value: self)
        return try writer.makeData()
    }
}

private struct OrderedJSONWriter {
    private var output = String()

    mutating func append(value: JSONValue) throws {
        switch value {
        case .object(let object):
            output.append("{")
            let pairs = object.orderedPairs()
            for index in pairs.indices {
                if index > 0 {
                    output.append(",")
                }
                let entry = pairs[index]
                try appendPrimitive(entry.0)
                output.append(":")
                try append(value: entry.1)
            }
            output.append("}")
        case .array(let array):
            output.append("[")
            for index in array.indices {
                if index > 0 {
                    output.append(",")
                }
                try append(value: array[index])
            }
            output.append("]")
        case .string(let string):
            try appendPrimitive(string)
        case .number(let double):
            try appendPrimitive(double)
        case .bool(let bool):
            try appendPrimitive(bool)
        case .null:
            try appendPrimitive(NSNull())
        }
    }

    func makeData() throws -> Data {
        guard let data = output.data(using: .utf8) else {
            throw OrderedJSONEncodingError.invalidUTF8
        }
        return data
    }

    private mutating func appendPrimitive(_ primitive: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: [primitive], options: [])
        guard var string = String(data: data, encoding: .utf8) else {
            throw OrderedJSONEncodingError.invalidPrimitive
        }
        string.removeFirst()
        string.removeLast()
        output.append(string)
    }
}
