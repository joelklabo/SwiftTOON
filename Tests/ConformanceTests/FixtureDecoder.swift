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
            if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
                var object = JSONObject()
                for key in container.allKeys {
                    let nested = try container.decode(JSONValueWrapper.self, forKey: key)
                    object[key.stringValue] = nested.value
                }
                value = .object(object)
                return
            }
            if var arrayContainer = try? decoder.unkeyedContainer() {
                var elements: [JSONValue] = []
                while !arrayContainer.isAtEnd {
                    let nested = try arrayContainer.decode(JSONValueWrapper.self)
                    elements.append(nested.value)
                }
                value = .array(elements)
                return
            }
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
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

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
