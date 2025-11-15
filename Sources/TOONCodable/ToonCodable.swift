import Foundation
import TOONCore

public struct ToonDecoder {
    public var jsonDecoder: JSONDecoder

    public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = jsonDecoder
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        let jsonValue = try parseJSONValue(from: data)
        let jsonData = try JSONSerialization.data(withJSONObject: jsonValue.toAny(), options: [])
        return try jsonDecoder.decode(T.self, from: jsonData)
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

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Input data is not valid UTF-8 TOON text."
        }
    }
}

public struct ToonEncoder {
    public init() {}

    public func encode<T>(_: T) throws -> Data where T: Encodable {
        throw ToonEncodingError.notImplemented
    }
}

public enum ToonEncodingError: Error {
    case notImplemented
}
