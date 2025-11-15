import Foundation
import TOONCore

final class JSONValueEncoder {
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func encode<T>(_ value: T) throws -> JSONValue where T: Encodable {
        let box = JSONValueResultBox()
        let encoder = _JSONValueEncoder(codingPath: [], userInfo: userInfo, assign: { box.value = $0 })
        try value.encode(to: encoder)
        guard let result = box.value else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Value did not encode any output.")
            )
        }
        return result
    }
}

private final class JSONValueResultBox {
    var value: JSONValue?
}

private final class JSONObjectBox {
    var object = JSONObject()
}

private final class JSONArrayBox {
    var array: [JSONValue] = []
}

private final class _JSONValueEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    private let assign: (JSONValue) -> Void

    init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], assign: @escaping (JSONValue) -> Void) {
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.assign = assign
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let box = JSONObjectBox()
        assign(.object(box.object))
        let container = JSONObjectEncodingContainer<Key>(
            encoder: self,
            codingPath: codingPath,
            box: box,
            assign: assign
        )
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let box = JSONArrayBox()
        assign(.array(box.array))
        return JSONArrayEncodingContainer(encoder: self, codingPath: codingPath, box: box, assign: assign)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        JSONValueSingleEncodingContainer(encoder: self, codingPath: codingPath, assign: assign)
    }

    fileprivate func nestedEncoder(for key: CodingKey?, assign: @escaping (JSONValue) -> Void) -> _JSONValueEncoder {
        let nextPath = key.map { codingPath + [$0] } ?? codingPath
        return _JSONValueEncoder(codingPath: nextPath, userInfo: userInfo, assign: assign)
    }
}

private final class JSONObjectEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = Key

    private let encoder: _JSONValueEncoder
    private let box: JSONObjectBox
    var codingPath: [CodingKey]
    private let assign: (JSONValue) -> Void

    init(encoder: _JSONValueEncoder, codingPath: [CodingKey], box: JSONObjectBox, assign: @escaping (JSONValue) -> Void) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.box = box
        self.assign = assign
    }

    func encodeNil(forKey key: Key) throws { set(.null, for: key) }
    func encode(_ value: Bool, forKey key: Key) throws { set(.bool(value), for: key) }
    func encode(_ value: String, forKey key: Key) throws { set(.string(value), for: key) }
    func encode(_ value: Double, forKey key: Key) throws { set(.number(value), for: key) }
    func encode(_ value: Float, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: Int, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: Int8, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: Int16, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: Int32, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: Int64, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: UInt, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: UInt8, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { set(.number(Double(value)), for: key) }
    func encode(_ value: UInt64, forKey key: Key) throws { set(.number(Double(value)), for: key) }

    func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        let nested = encoder.nestedEncoder(for: key, assign: { newValue in
            self.box.object[key.stringValue] = newValue
            self.assign(.object(self.box.object))
        })
        try value.encode(to: nested)
    }

    func nestedContainer<N>(keyedBy type: N.Type, forKey key: Key) -> KeyedEncodingContainer<N> where N: CodingKey {
        let nestedBox = JSONObjectBox()
        box.object[key.stringValue] = .object(nestedBox.object)
        let container = JSONObjectEncodingContainer<N>(encoder: encoder, codingPath: codingPath + [key], box: nestedBox, assign: { value in
            self.box.object[key.stringValue] = value
            self.assign(.object(self.box.object))
        })
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let arrayBox = JSONArrayBox()
        box.object[key.stringValue] = .array(arrayBox.array)
        let container = JSONArrayEncodingContainer(encoder: encoder, codingPath: codingPath + [key], box: arrayBox, assign: { value in
            self.box.object[key.stringValue] = value
            self.assign(.object(self.box.object))
        })
        return container
    }

    func superEncoder() -> Encoder {
        return superEncoder(forKey: Key(stringValue: "super")!)
    }

    func superEncoder(forKey key: Key) -> Encoder {
        encoder.nestedEncoder(for: key, assign: { newValue in
            self.box.object[key.stringValue] = newValue
            self.assign(.object(self.box.object))
        })
    }

    private func set(_ value: JSONValue, for key: Key) {
        box.object[key.stringValue] = value
        assign(.object(box.object))
    }
}

private final class JSONArrayEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _JSONValueEncoder
    var codingPath: [CodingKey]
    private let box: JSONArrayBox
    var count: Int { box.array.count }
    private let assign: (JSONValue) -> Void

    init(encoder: _JSONValueEncoder, codingPath: [CodingKey], box: JSONArrayBox, assign: @escaping (JSONValue) -> Void) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.box = box
        self.assign = assign
    }

    func encodeNil() throws { append(.null) }
    func encode(_ value: Bool) throws { append(.bool(value)) }
    func encode(_ value: String) throws { append(.string(value)) }
    func encode(_ value: Double) throws { append(.number(value)) }
    func encode(_ value: Float) throws { append(.number(Double(value))) }
    func encode(_ value: Int) throws { append(.number(Double(value))) }
    func encode(_ value: Int8) throws { append(.number(Double(value))) }
    func encode(_ value: Int16) throws { append(.number(Double(value))) }
    func encode(_ value: Int32) throws { append(.number(Double(value))) }
    func encode(_ value: Int64) throws { append(.number(Double(value))) }
    func encode(_ value: UInt) throws { append(.number(Double(value))) }
    func encode(_ value: UInt8) throws { append(.number(Double(value))) }
    func encode(_ value: UInt16) throws { append(.number(Double(value))) }
    func encode(_ value: UInt32) throws { append(.number(Double(value))) }
    func encode(_ value: UInt64) throws { append(.number(Double(value))) }

    func encode<T>(_ value: T) throws where T: Encodable {
        let nestedKey = AnyCodingKey(index: box.array.count)
        let nested = encoder.nestedEncoder(for: nestedKey, assign: { newValue in
            self.box.array.append(newValue)
            self.assign(.array(self.box.array))
        })
        try value.encode(to: nested)
    }

    func nestedContainer<N>(keyedBy type: N.Type) -> KeyedEncodingContainer<N> where N: CodingKey {
        let nestedBox = JSONObjectBox()
        box.array.append(.object(nestedBox.object))
        let container = JSONObjectEncodingContainer<N>(
            encoder: encoder,
            codingPath: codingPath + [AnyCodingKey(index: box.array.count - 1)],
            box: nestedBox,
            assign: { value in
                self.box.array[self.box.array.count - 1] = value
                self.assign(.array(self.box.array))
            }
        )
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedBox = JSONArrayBox()
        box.array.append(.array(nestedBox.array))
        let container = JSONArrayEncodingContainer(
            encoder: encoder,
            codingPath: codingPath + [AnyCodingKey(index: box.array.count - 1)],
            box: nestedBox,
            assign: { value in
                self.box.array[self.box.array.count - 1] = value
                self.assign(.array(self.box.array))
            }
        )
        return container
    }

    func superEncoder() -> Encoder {
        encoder.nestedEncoder(for: AnyCodingKey(index: box.array.count), assign: { newValue in
            self.box.array.append(newValue)
            self.assign(.array(self.box.array))
        })
    }

    private func append(_ value: JSONValue) {
        box.array.append(value)
        assign(.array(box.array))
    }
}

private struct JSONValueSingleEncodingContainer: SingleValueEncodingContainer {
    let encoder: _JSONValueEncoder
    var codingPath: [CodingKey]
    private let assign: (JSONValue) -> Void

    init(encoder: _JSONValueEncoder, codingPath: [CodingKey], assign: @escaping (JSONValue) -> Void) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.assign = assign
    }

    mutating func encodeNil() throws { assign(.null) }
    mutating func encode(_ value: Bool) throws { assign(.bool(value)) }
    mutating func encode(_ value: String) throws { assign(.string(value)) }
    mutating func encode(_ value: Double) throws { assign(.number(value)) }
    mutating func encode(_ value: Float) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: Int) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: Int8) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: Int16) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: Int32) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: Int64) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: UInt) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: UInt8) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: UInt16) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: UInt32) throws { assign(.number(Double(value))) }
    mutating func encode(_ value: UInt64) throws { assign(.number(Double(value))) }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        let nested = encoder.nestedEncoder(for: nil, assign: assign)
        try value.encode(to: nested)
    }
}
