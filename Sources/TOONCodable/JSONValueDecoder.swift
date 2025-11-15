import Foundation
import TOONCore

final class JSONValueDecoder {
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func decode<T>(_ type: T.Type, from value: JSONValue) throws -> T where T: Decodable {
        let decoder = _JSONValueDecoder(value: value, codingPath: [], userInfo: userInfo)
        return try T(from: decoder)
    }
}

private final class _JSONValueDecoder: Decoder {
    let value: JSONValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]

    init(value: JSONValue, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.value = value
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .object(let object) = value else {
            throw DecodingError.typeMismatch([String: JSONValue].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected object"))
        }
        let container = JSONObjectDecodingContainer<Key>(decoder: self, codingPath: codingPath, object: object)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let array) = value else {
            throw DecodingError.typeMismatch([JSONValue].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected array"))
        }
        return JSONArrayDecodingContainer(decoder: self, codingPath: codingPath, array: array)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        JSONValueSingleDecodingContainer(decoder: self, codingPath: codingPath, value: value)
    }

    fileprivate func nestedDecoder(for key: CodingKey?) -> _JSONValueDecoder {
        let newPath = key.map { codingPath + [$0] } ?? codingPath
        return _JSONValueDecoder(value: value, codingPath: newPath, userInfo: userInfo)
    }
}

private struct JSONObjectDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = Key

    let decoder: _JSONValueDecoder
    var codingPath: [CodingKey]
    let object: JSONObject

    var allKeys: [Key] {
        object.orderedPairs().compactMap { Key(stringValue: $0.0) }
    }

    func contains(_ key: Key) -> Bool {
        object.value(forKey: key.stringValue) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = object.value(forKey: key.stringValue) else { return true }
        return value == .null
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try value(for: key, as: Bool.self) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try value(for: key, as: String.self) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try value(for: key, as: Double.self) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { Float(try decode(Double.self, forKey: key)) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try convertNumber(try decode(Double.self, forKey: key), codingPath: codingPath + [key]) }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let childValue = try value(for: key)
        let decoder = _JSONValueDecoder(value: childValue, codingPath: codingPath + [key], userInfo: self.decoder.userInfo)
        return try T(from: decoder)
    }

    func nestedContainer<N>(keyedBy type: N.Type, forKey key: Key) throws -> KeyedDecodingContainer<N> where N: CodingKey {
        let decoder = _JSONValueDecoder(value: try value(for: key), codingPath: codingPath + [key], userInfo: self.decoder.userInfo)
        return try decoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let decoder = _JSONValueDecoder(value: try value(for: key), codingPath: codingPath + [key], userInfo: self.decoder.userInfo)
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return try superDecoder(forKey: Key(stringValue: "super")!)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let childValue = try value(for: key)
        return _JSONValueDecoder(value: childValue, codingPath: codingPath + [key], userInfo: decoder.userInfo)
    }

    private func value(for key: Key) throws -> JSONValue {
        guard let value = object.value(forKey: key.stringValue) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "Missing key"))
        }
        return value
    }

    private func value<T>(for key: Key, as type: T.Type) throws -> T {
        let value = try self.value(for: key)
        return try JSONValueSingleDecodingContainer.extract(type: type, from: value, codingPath: codingPath + [key])
    }
}

private struct JSONArrayDecodingContainer: UnkeyedDecodingContainer {
    let decoder: _JSONValueDecoder
    var codingPath: [CodingKey]
    let array: [JSONValue]
    var currentIndex: Int = 0

    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if array[currentIndex] == .null {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try decodeScalar(type) }
    mutating func decode(_ type: String.Type) throws -> String { try decodeScalar(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try decodeScalar(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }
    mutating func decode(_ type: Int.Type) throws -> Int { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try convertNumber(try decode(Double.self), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)]) }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let value = try nextValue()
        let decoder = _JSONValueDecoder(value: value, codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)], userInfo: self.decoder.userInfo)
        return try T(from: decoder)
    }

    mutating func nestedContainer<N>(keyedBy type: N.Type) throws -> KeyedDecodingContainer<N> where N: CodingKey {
        let decoder = _JSONValueDecoder(value: try nextValue(), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)], userInfo: self.decoder.userInfo)
        return try decoder.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let decoder = _JSONValueDecoder(value: try nextValue(), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)], userInfo: self.decoder.userInfo)
        return try decoder.unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        return _JSONValueDecoder(value: try nextValue(), codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)], userInfo: decoder.userInfo)
    }

    private mutating func nextValue() throws -> JSONValue {
        guard currentIndex < array.count else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: codingPath + [AnyCodingKey(index: currentIndex)], debugDescription: "Unkeyed container is at end")
            )
        }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    private mutating func decodeScalar<T>(_ type: T.Type) throws -> T {
        let value = try nextValue()
        return try JSONValueSingleDecodingContainer.extract(type: type, from: value, codingPath: codingPath + [AnyCodingKey(index: currentIndex - 1)])
    }
}

private struct JSONValueSingleDecodingContainer: SingleValueDecodingContainer {
    let decoder: _JSONValueDecoder
    var codingPath: [CodingKey]
    let value: JSONValue

    func decodeNil() -> Bool {
        value == .null
    }

    func decode(_ type: Bool.Type) throws -> Bool { try Self.extract(type: type, from: value, codingPath: codingPath) }
    func decode(_ type: String.Type) throws -> String { try Self.extract(type: type, from: value, codingPath: codingPath) }
    func decode(_ type: Double.Type) throws -> Double { try Self.extract(type: type, from: value, codingPath: codingPath) }
    func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }
    func decode(_ type: Int.Type) throws -> Int { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try convertNumber(try decode(Double.self), codingPath: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try convertNumber(try decode(Double.self), codingPath: codingPath) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let decoder = _JSONValueDecoder(value: value, codingPath: codingPath, userInfo: self.decoder.userInfo)
        return try T(from: decoder)
    }

    static func extract<T>(type: T.Type, from value: JSONValue, codingPath: [CodingKey]) throws -> T {
        switch (value, T.self) {
        case (.bool(let bool), is Bool.Type):
            return bool as! T
        case (.string(let string), is String.Type):
            return string as! T
        case (.number(let double), is Double.Type):
            return double as! T
        default:
            throw DecodingError.typeMismatch(
                T.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Type mismatch: found \(value)")
            )
        }
    }
}

private func convertNumber<T: BinaryInteger>(_ value: Double, codingPath: [CodingKey]) throws -> T {
    guard value.rounded() == value, let result = T(exactly: value) else {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Value not representable as \(T.self)"))
    }
    return result
}
