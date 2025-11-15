import Foundation
import TOONCodable
import TOONCore

struct EncodeFixture: Decodable {
    let name: String
    let input: JSONFixtureValue
    let expected: String
    let options: EncodeFixtureOptions?
}

struct EncodeFixtureFile: Decodable {
    let tests: [EncodeFixture]
}

struct EncodeFixtureOptions: Decodable {
    enum CodingKeys: String, CodingKey {
        case delimiter
        case indent
        case keyFolding
        case flattenDepth
    }

    enum KeyFoldingMode: String, Decodable {
        case off
        case safe
    }

    let delimiter: String?
    let indent: Int?
    let keyFolding: KeyFoldingMode?
    let flattenDepth: Int?
}

extension EncodeFixtureOptions {
    func encodingOptions(defaults: ToonEncodingOptions = ToonEncodingOptions()) -> ToonEncodingOptions {
        var resolved = defaults
        if let delimiterString = delimiter, let first = delimiterString.first {
            resolved.delimiter = ToonEncodingOptions.Delimiter(character: first)
        }
        if let indent {
            resolved.indentWidth = max(0, indent)
        }
        if let flattenDepth {
            resolved.flattenDepth = flattenDepth
        }
        if let keyFolding {
            switch keyFolding {
            case .off:
                resolved.keyFolding = .off
            case .safe:
                resolved.keyFolding = .safe
            }
        }
        return resolved
    }
}

struct JSONFixtureValue: Decodable {
    let value: JSONValue

    init(value: JSONValue) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object = JSONObject()
            for key in container.allKeys {
                let nested = try container.decode(JSONFixtureValue.self, forKey: key)
                object[key.stringValue] = nested.value
            }
            value = .object(object)
            return
        }
        if var arrayContainer = try? decoder.unkeyedContainer() {
            var elements: [JSONValue] = []
            while !arrayContainer.isAtEnd {
                let nested = try arrayContainer.decode(JSONFixtureValue.self)
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}
