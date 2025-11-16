import Foundation
import TOONCore

public struct ToonSerializer {
    let options: ToonEncodingOptions
    let schema: ToonSchema?

    public init(options: ToonEncodingOptions = ToonEncodingOptions(), schema: ToonSchema? = nil) {
        self.options = options
        self.schema = schema
    }

    public func serialize(jsonValue: JSONValue) -> String {
        let renderer = Renderer(options: options, schema: schema)
        let lines = renderer.render(
            value: jsonValue,
            key: nil,
            indent: 0,
            listContext: false,
            remainingAdditionalSegments: renderer.initialAdditionalSegments,
            schema: renderer.rootSchema
        )
        return lines.joined(separator: "\n")
    }
}

private struct Renderer {
    let options: ToonEncodingOptions
    let rootSchema: ToonSchema?
    let initialAdditionalSegments: Int?

    private var indentWidth: Int { max(options.indentWidth, 0) }
    private var delimiter: Character { options.delimiter.symbol.first ?? "," }
    private var delimiterString: String { options.delimiter.symbol }
    private var delimiterSuffix: String { options.delimiter == .comma ? "" : options.delimiter.symbol }

    init(options: ToonEncodingOptions, schema: ToonSchema?) {
        self.options = options
        self.rootSchema = schema
        if let depth = options.flattenDepth {
            if depth <= 1 {
                initialAdditionalSegments = 0
            } else {
                initialAdditionalSegments = depth - 1
            }
        } else {
            initialAdditionalSegments = nil
        }
    }

    func render(
        value: JSONValue,
        key: String?,
        indent: Int,
        listContext: Bool = false,
        remainingAdditionalSegments: Int?,
        schema: ToonSchema?
    ) -> [String] {
        switch value {
        case .object(let dict):
            return renderObject(
                dict,
                key: key,
                indent: indent,
                listContext: listContext,
                remainingAdditionalSegments: remainingAdditionalSegments,
                schema: schema
            )
        case .array(let array):
            return renderArray(
                array,
                key: key,
                indent: indent,
                listContext: listContext,
                remainingAdditionalSegments: remainingAdditionalSegments,
                schema: schema
            )
        default:
            guard let scalar = scalarString(value) else { return [] }
            let prefix = indentString(indent)
            if let key {
                return ["\(prefix)\(ToonKeyQuoter.encode(key)): \(scalar)"]
            } else {
                return ["\(prefix)\(scalar)"]
            }
        }
    }

    private func renderObject(
        _ dict: JSONObject,
        key: String?,
        indent: Int,
        listContext: Bool,
        remainingAdditionalSegments: Int?,
        schema: ToonSchema?
    ) -> [String] {
        let entries = dict.orderedPairs()
        if entries.isEmpty {
            guard let key else { return [] }
            return ["\(indentString(indent))\(ToonKeyQuoter.encode(key)):"]
        }

        var result: [String] = []
        if let key {
            result.append("\(indentString(indent))\(ToonKeyQuoter.encode(key)):")
            result += renderEntries(
                entries,
                indent: indent + indentWidth,
                listContext: listContext,
                remainingAdditionalSegments: remainingAdditionalSegments,
                schema: schema
            )
        } else {
            result += renderEntries(
                entries,
                indent: indent,
                listContext: listContext,
                remainingAdditionalSegments: remainingAdditionalSegments,
                schema: schema
            )
        }
        return result
    }

    private func renderEntries(
        _ entries: [(String, JSONValue)],
        indent: Int,
        listContext: Bool = false,
        remainingAdditionalSegments: Int?,
        schema: ToonSchema?
    ) -> [String] {
        let processedEntries = foldEntriesIfNeeded(
            entries,
            schema: schema,
            remainingAdditionalSegments: remainingAdditionalSegments
        )
        var result: [String] = []
        for entry in processedEntries {
            let entrySchema = entry.childSchema
            switch entry.value {
            case .array(let array):
                result += renderArray(
                    array,
                    key: entry.key,
                    indent: indent,
                    listContext: listContext,
                    remainingAdditionalSegments: entry.childRemainingAdditionalSegments,
                    schema: entrySchema
                )
            case .object(let dict):
                result += renderObject(
                    dict,
                    key: entry.key,
                    indent: indent,
                    listContext: listContext,
                    remainingAdditionalSegments: entry.childRemainingAdditionalSegments,
                    schema: entrySchema
                )
            default:
                guard let scalar = scalarString(entry.value) else { continue }
                result.append("\(indentString(indent))\(ToonKeyQuoter.encode(entry.key)): \(scalar)")
            }
        }
        return result
    }

    private struct FoldedEntry {
        let key: String
        let value: JSONValue
        let childSchema: ToonSchema?
        let childRemainingAdditionalSegments: Int?
    }

    private func foldEntriesIfNeeded(
        _ entries: [(String, JSONValue)],
        schema: ToonSchema?,
        remainingAdditionalSegments: Int?
    ) -> [FoldedEntry] {
        guard options.keyFolding == .safe else {
            return entries.map {
                FoldedEntry(
                    key: $0.0,
                    value: $0.1,
                    childSchema: schema?.schema(forField: $0.0),
                    childRemainingAdditionalSegments: remainingAdditionalSegments
                )
            }
        }
        let allowedAdditional = remainingAdditionalSegments
        if let allowed = allowedAdditional, allowed <= 0 {
            return entries.map {
                FoldedEntry(
                    key: $0.0,
                    value: $0.1,
                    childSchema: schema?.schema(forField: $0.0),
                    childRemainingAdditionalSegments: allowedAdditional
                )
            }
        }

        let literalKeys = Set(entries.map { $0.0 })
        let blockedKeys = Set(entries.compactMap { entry -> String? in
            let key = entry.0
            for literal in literalKeys {
                if literal != key, literal.hasPrefix("\(key).") {
                    return key
                }
            }
            return nil
        })

        return entries.map { pair in
            if blockedKeys.contains(pair.0) {
                return FoldedEntry(
                    key: pair.0,
                    value: pair.1,
                    childSchema: schema?.schema(forField: pair.0),
                    childRemainingAdditionalSegments: 0
                )
            }
            if let (foldedKey, foldedValue, childRemaining) = foldChain(
                initialKey: pair.0,
                value: pair.1,
                literalKeys: literalKeys,
                remainingAdditionalSegments: allowedAdditional
            ) {
                return FoldedEntry(
                    key: foldedKey,
                    value: foldedValue,
                    childSchema: nil,
                    childRemainingAdditionalSegments: childRemaining
                )
            } else {
                return FoldedEntry(
                    key: pair.0,
                    value: pair.1,
                    childSchema: schema?.schema(forField: pair.0),
                    childRemainingAdditionalSegments: remainingAdditionalSegments
                )
            }
        }
    }

    private func foldChain(
        initialKey: String,
        value: JSONValue,
        literalKeys: Set<String>,
        remainingAdditionalSegments: Int?
    ) -> (String, JSONValue, Int?)? {
        guard !ToonKeyQuoter.needsQuotes(initialKey) else { return nil }

        let maxAdditional = remainingAdditionalSegments ?? Int.max
        if maxAdditional <= 0 {
            return nil
        }

        var segments = [initialKey]
        var currentValue = value
        var additionalUsed = 0

        while additionalUsed < maxAdditional {
            guard case .object(let object) = currentValue, object.count == 1 else {
                break
            }
            guard let (nextKey, nextValue) = object.orderedPairs().first else {
                break
            }
            guard !ToonKeyQuoter.needsQuotes(nextKey) else {
                break
            }
            let candidate = (segments + [nextKey]).joined(separator: ".")
            if literalKeys.contains(candidate) {
                return nil
            }
            segments.append(nextKey)
            currentValue = nextValue
            additionalUsed += 1
        }

        guard segments.count > 1 else { return nil }
        let foldedKey = segments.joined(separator: ".")
        let childRemaining: Int?
        if let remaining = remainingAdditionalSegments {
            childRemaining = max(0, remaining - additionalUsed)
        } else {
            childRemaining = nil
        }
        return (foldedKey, currentValue, childRemaining)
    }

    private func renderArray(
        _ array: [JSONValue],
        key: String?,
        indent: Int,
        listContext: Bool,
        remainingAdditionalSegments: Int?,
        schema: ToonSchema?
    ) -> [String] {
        let format = ToonAnalyzer.analyzeArray(array, schema: schema, delimiterSymbol: delimiterString)
        let prefix = indentString(indent)
        switch format {
        case .empty:
            return ["\(prefix)\(arrayHeader(count: array.count, key: key)):"]
        case .inline(let values):
            let joined = values.joined(separator: delimiterString)
            return ["\(prefix)\(arrayHeader(count: array.count, key: key)): \(joined)"]
        case .tabular(let headers, let rows):
            let headerLine = arrayHeader(count: array.count, key: key, tabularHeaders: headers)
            var lines: [String] = []
            lines.append("\(prefix)\(headerLine):")
            let rowIndentLevel = listContext ? indent : indent + indentWidth
            let rowIndent = indentString(rowIndentLevel)
            for row in rows {
                lines.append("\(rowIndent)\(row.joined(separator: delimiterString))")
            }
            return lines
        case .list:
            var result: [String] = []
            result.append("\(prefix)\(arrayHeader(count: array.count, key: key)):")
            result += renderList(
                array,
                indent: indent,
                listContext: listContext,
                remainingAdditionalSegments: remainingAdditionalSegments,
                elementSchema: schema?.arrayElementSchema
            )
            return result
        }
    }

    private enum ArrayFormat {
        case empty
        case inline([String])
        case tabular(headers: [String], rows: [[String]])
        case list
    }

    private func renderList(
        _ array: [JSONValue],
        indent: Int,
        listContext: Bool = false,
        remainingAdditionalSegments: Int?,
        elementSchema: ToonSchema?
    ) -> [String] {
        var result: [String] = []
        let hyphenIndent = listContext ? indent : indent + indentWidth
        let childIndent = hyphenIndent + indentWidth

        for element in array {
            let rendered = render(
                value: element,
                key: nil,
                indent: childIndent,
                listContext: true,
                remainingAdditionalSegments: remainingAdditionalSegments,
                schema: elementSchema
            )
            if rendered.isEmpty {
                result.append("\(indentString(hyphenIndent))-")
                continue
            }
            var lines = rendered
            let first = lines.removeFirst()
            let trimmed = stripIndent(first, count: childIndent)
            result.append("\(indentString(hyphenIndent))- \(trimmed)")
            for line in lines {
                let trimmedLine = stripIndent(line, count: childIndent)
                if trimmedLine.isEmpty {
                    continue
                }
                result.append("\(indentString(childIndent))\(trimmedLine)")
            }
        }
        return result
    }

    private func arrayHeader(count: Int, key: String?, tabularHeaders: [String]? = nil) -> String {
        let body = options.delimiter == .comma ? "[\(count)]" : "[\(count)\(delimiterSuffix)]"
        let head: String
        if let key {
            head = "\(ToonKeyQuoter.encode(key))\(body)"
        } else {
            head = body
        }
        if let headers = tabularHeaders {
            let formatted = headers.map { ToonKeyQuoter.encode($0) }.joined(separator: delimiterString)
            return "\(head){\(formatted)}"
        }
        return head
    }

    private func scalarString(_ value: JSONValue) -> String? {
        ScalarFormatter.scalarString(value, delimiter: delimiter)
    }

    private func indentString(_ indent: Int) -> String {
        guard indent > 0 else { return "" }
        return String(repeating: " ", count: indent)
    }

    private func stripIndent(_ line: String, count: Int) -> String {
        guard count > 0 else { return line }
        var remaining = count
        var index = line.startIndex
        while remaining > 0 && index < line.endIndex && line[index] == " " {
            index = line.index(after: index)
            remaining -= 1
        }
        return String(line[index...])
    }
}
