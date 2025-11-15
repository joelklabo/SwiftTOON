import Foundation
import TOONCore

public struct ToonDecoder {
    public struct Options {
        public var schema: ToonSchema?

        public init(schema: ToonSchema? = nil) {
            self.schema = schema
        }
    }

    public var jsonDecoder: JSONDecoder
    public var options: Options

    public init(jsonDecoder: JSONDecoder = JSONDecoder(), options: Options = Options()) {
        self.jsonDecoder = jsonDecoder
        self.options = options
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        let jsonValue = try parseJSONValue(from: data)
        if let schema = options.schema {
            do {
                try schema.validate(jsonValue)
            } catch let error as ToonSchemaError {
                throw ToonDecodingError.schemaMismatch(error.localizedDescription)
            }
        }
        let valueDecoder = JSONValueDecoder()
        valueDecoder.userInfo = jsonDecoder.userInfo
        return try valueDecoder.decode(T.self, from: jsonValue)
    }

    public func decode<T>(_ type: T.Type, from stream: InputStream) throws -> T where T: Decodable {
        stream.open()
        defer { stream.close() }

        var buffer = Data()
        let chunkSize = 4096
        var localBuffer = [UInt8](repeating: 0, count: chunkSize)

        while stream.hasBytesAvailable {
            let read = stream.read(&localBuffer, maxLength: chunkSize)
            if read < 0 {
                throw stream.streamError ?? ToonDecodingError.invalidUTF8
            } else if read == 0 {
                break
            } else {
                buffer.append(localBuffer, count: read)
            }
        }

        return try decode(type, from: buffer)
    }

    public func decodeJSONValue(from data: Data) throws -> JSONValue {
        try parseJSONValue(from: data)
    }

    private func parseJSONValue(from data: Data) throws -> JSONValue {
        guard let string = String(data: data, encoding: .utf8) else {
            throw ToonDecodingError.invalidUTF8
        }
        var parser = try Parser(input: string)
        return try parser.parse()
    }
}

public enum ToonDecodingError: Error, LocalizedError {
    case invalidUTF8
    case schemaMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Input data is not valid UTF-8 TOON text."
        case let .schemaMismatch(message):
            return message
        }
    }
}

public struct ToonEncoder {
    public var jsonEncoder: JSONEncoder
    public var options: ToonEncodingOptions
    public var schema: ToonSchema?

    public init(
        jsonEncoder: JSONEncoder = JSONEncoder(),
        options: ToonEncodingOptions = ToonEncodingOptions(),
        schema: ToonSchema? = nil
    ) {
        self.jsonEncoder = jsonEncoder
        self.options = options
        self.schema = schema
    }

    public func encode<T>(_ value: T) throws -> Data where T: Encodable {
        let valueEncoder = JSONValueEncoder()
        valueEncoder.userInfo = jsonEncoder.userInfo
        let jsonValue = try valueEncoder.encode(value)
        if let schema {
            do {
                try schema.validate(jsonValue)
            } catch let error as ToonSchemaError {
                throw ToonEncodingError.schemaMismatch(error.localizedDescription)
            }
        }
        let serializer = ToonSerializer(options: options, schema: schema)
        let output = serializer.serialize(jsonValue: jsonValue)
        guard let data = output.data(using: .utf8) else {
            throw ToonEncodingError.encodingFailed
        }
        return data
    }
}

public enum ToonEncodingError: Error, LocalizedError {
    case notImplemented
    case unsupportedValue
    case encodingFailed
    case schemaMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Encoding is not yet implemented."
        case .unsupportedValue:
            return "Encountered a value that cannot be encoded into TOON."
        case .encodingFailed:
            return "Failed to emit TOON output."
        case let .schemaMismatch(message):
            return message
        }
    }
}
