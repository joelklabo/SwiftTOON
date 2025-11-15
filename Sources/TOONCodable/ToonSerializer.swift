import Foundation
import TOONCore

struct ToonSerializer {
    let indentWidth: Int = 2

    func serialize(jsonValue: JSONValue) -> String {
        var lines: [String] = []
        render(value: jsonValue, key: nil, indentLevel: 0, lines: &lines)
        return lines.joined(separator: "\n")
    }

    private func render(value: JSONValue, key: String?, indentLevel: Int, lines: inout [String]) {
        let indent = String(repeating: " ", count: indentLevel)
        switch value {
        case .object(let dict):
            let entries = dict.map { $0 }
            if let key {
                if entries.isEmpty {
                    lines.append("\(indent)\(key): {}")
                } else {
                    lines.append("\(indent)\(key):")
                    for entry in entries {
                        render(value: entry.value, key: entry.key, indentLevel: indentLevel + indentWidth, lines: &lines)
                    }
                }
            } else {
                if entries.isEmpty {
                    lines.append("{}")
                } else {
                    for entry in entries {
                        render(value: entry.value, key: entry.key, indentLevel: indentLevel, lines: &lines)
                    }
                }
            }
        case .array(let array):
            serializeArray(array, key: key, indentLevel: indentLevel, lines: &lines)
        case .string, .number, .bool, .null:
            guard let rendered = scalarString(value) else { return }
            if let key {
                lines.append("\(indent)\(key): \(rendered)")
            } else {
                lines.append("\(indent)\(rendered)")
            }
        }
    }

    private func serializeArray(_ array: [JSONValue], key: String?, indentLevel: Int, lines: inout [String]) {
        let indent = String(repeating: " ", count: indentLevel)
        let count = array.count
        let head: String
        if let key {
            head = "\(indent)\(key)[\(count)]"
        } else {
            head = "\(indent)[\(count)]"
        }

        if array.allSatisfy({ scalarString($0) != nil }) {
            let values = array.compactMap { scalarString($0) }
            lines.append("\(head): \(values.joined(separator: ","))")
            return
        }

        lines.append("\(head):")
        let itemIndent = String(repeating: " ", count: indentLevel + indentWidth)
        for element in array {
            if let scalar = scalarString(element) {
                lines.append("\(itemIndent)- \(scalar)")
            } else {
                lines.append("\(itemIndent)-")
                render(value: element, key: nil, indentLevel: indentLevel + indentWidth * 2, lines: &lines)
            }
        }
    }

    private func scalarString(_ value: JSONValue) -> String? {
        switch value {
        case .string(let string):
            return ToonQuoter.encode(string)
        case .number(let double):
            return format(number: double)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        default:
            return nil
        }
    }

    private func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }
        var string = String(number)
        if let dotIndex = string.firstIndex(of: ".") {
            var end = string.index(before: string.endIndex)
            while end > dotIndex && string[end] == "0" {
                string.remove(at: end)
                end = string.index(before: end)
            }
            if end == dotIndex {
                string.remove(at: dotIndex)
            }
        }
        return string
    }
}
