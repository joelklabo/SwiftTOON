import Foundation
import TOONCore

struct FixtureTest: Decodable {
    let name: String
    let input: String
    let expected: JSONValueWrapper
    let specSection: String?

    struct JSONValueWrapper: Decodable, Equatable {
        let value: JSONValue

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let dict = try? container.decode([String: JSONValueWrapper].self) {
                value = .object(dict.mapValues(\.value))
            } else if let array = try? container.decode([JSONValueWrapper].self) {
                value = .array(array.map(\.value))
            } else if let string = try? container.decode(String.self) {
                value = .string(string)
            } else if let number = try? container.decode(Double.self) {
                value = .number(number)
            } else if let bool = try? container.decode(Bool.self) {
                value = .bool(bool)
            } else if container.decodeNil() {
                value = .null
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON Value")
            }
        }
    }
}
