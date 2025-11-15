import Foundation
import TOONCore

public struct ToonSchemaField: Equatable {
    public var name: String
    public var schema: ToonSchema

    public init(_ name: String, _ schema: ToonSchema) {
        self.name = name
        self.schema = schema
    }
}

public enum ToonSchemaArrayRepresentation: Equatable {
    case auto
    case tabular(headers: [String])
    case list
}

public indirect enum ToonSchema: Equatable {
    case any
    case string
    case number
    case bool
    case null
    case object(fields: [ToonSchemaField], allowAdditionalKeys: Bool = true)
    case array(element: ToonSchema, representation: ToonSchemaArrayRepresentation = .auto)

    public static func field(_ name: String, _ schema: ToonSchema) -> ToonSchemaField {
        ToonSchemaField(name, schema)
    }
}

public enum ToonSchemaError: Error, LocalizedError {
    case typeMismatch(expected: String, actual: String, path: String)
    case missingField(_ path: String)
    case unexpectedField(_ path: String)

    public var errorDescription: String? {
        switch self {
        case let .typeMismatch(expected, actual, path):
            return "Expected \(expected) at \(path), found \(actual)."
        case let .missingField(path):
            return "Missing expected field at \(path)."
        case let .unexpectedField(path):
            return "Unexpected field at \(path)."
        }
    }
}

public extension ToonSchema {
    func validate(_ value: JSONValue, path: [String] = []) throws {
        switch self {
        case .any:
            return
        case .string:
            guard case .string = value else { throw ToonSchemaError.typeMismatch(expected: "string", actual: value.typeDescription, path: path.render()) }
        case .number:
            guard case .number = value else { throw ToonSchemaError.typeMismatch(expected: "number", actual: value.typeDescription, path: path.render()) }
        case .bool:
            guard case .bool = value else { throw ToonSchemaError.typeMismatch(expected: "bool", actual: value.typeDescription, path: path.render()) }
        case .null:
            guard case .null = value else { throw ToonSchemaError.typeMismatch(expected: "null", actual: value.typeDescription, path: path.render()) }
        case let .object(fields, allowAdditional):
            guard case .object(let object) = value else {
                throw ToonSchemaError.typeMismatch(expected: "object", actual: value.typeDescription, path: path.render())
            }
            var seen = Set<String>()
            for field in fields {
                guard let child = object.value(forKey: field.name) else {
                    throw ToonSchemaError.missingField((path + [field.name]).render())
                }
                try field.schema.validate(child, path: path + [field.name])
                seen.insert(field.name)
            }
            if !allowAdditional {
                for entry in object.orderedPairs() {
                    if !seen.contains(entry.0) {
                        throw ToonSchemaError.unexpectedField((path + [entry.0]).render())
                    }
                }
            }
        case let .array(element, _):
            guard case .array(let array) = value else {
                throw ToonSchemaError.typeMismatch(expected: "array", actual: value.typeDescription, path: path.render())
            }
            for (index, child) in array.enumerated() {
                try element.validate(child, path: path + ["[\(index)]"])
            }
        }
    }

    func schema(forField name: String) -> ToonSchema? {
        guard case .object(let fields, _) = self else { return nil }
        return fields.first(where: { $0.name == name })?.schema
    }

    var arrayElementSchema: ToonSchema? {
        guard case .array(let element, _) = self else { return nil }
        return element
    }

    var arrayRepresentationHint: ToonSchemaArrayRepresentation {
        guard case .array(_, let representation) = self else { return .auto }
        return representation
    }

    var allowsAdditionalKeys: Bool {
        guard case .object(_, let allow) = self else { return true }
        return allow
    }
}

private extension Array where Element == String {
    func render() -> String {
        if isEmpty { return "$" }
        return "$" + map { $0 }.joined(separator: ".")
    }
}

private extension JSONValue {
    var typeDescription: String {
        switch self {
        case .object:
            return "object"
        case .array:
            return "array"
        case .string:
            return "string"
        case .number:
            return "number"
        case .bool:
            return "bool"
        case .null:
            return "null"
        }
    }
}
