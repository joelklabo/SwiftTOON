public struct JSONObject: Equatable, ExpressibleByDictionaryLiteral {
    public struct Entry: Equatable {
        public var key: String
        public var value: JSONValue
    }

    private var entries: [Entry]
    private var indexByKey: [String: Int]

    public init() {
        self.entries = []
        self.indexByKey = [:]
    }

    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    public subscript(key: String) -> JSONValue? {
        get {
            guard let index = indexByKey[key] else { return nil }
            return entries[index].value
        }
        set {
            if let value = newValue {
                if let index = indexByKey[key] {
                    entries[index].value = value
                } else {
                    indexByKey[key] = entries.count
                    entries.append(Entry(key: key, value: value))
                }
            } else {
                removeValue(forKey: key)
            }
        }
    }

    @discardableResult
    public mutating func updateValue(_ value: JSONValue, forKey key: String) -> JSONValue? {
        let previous = self[key]
        self[key] = value
        return previous
    }

    @discardableResult
    public mutating func removeValue(forKey key: String) -> JSONValue? {
        guard let index = indexByKey[key] else { return nil }
        indexByKey.removeValue(forKey: key)
        let removed = entries.remove(at: index)
        for i in index..<entries.count {
            indexByKey[entries[i].key] = i
        }
        return removed.value
    }

    public func orderedPairs() -> [(String, JSONValue)] {
        entries.map { ($0.key, $0.value) }
    }

    public func toDictionary() -> [String: JSONValue] {
        var dictionary: [String: JSONValue] = [:]
        for entry in entries {
            dictionary[entry.key] = entry.value
        }
        return dictionary
    }

    public static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        if lhs.entries.count != rhs.entries.count { return false }
        for entry in lhs.entries {
            guard let value = rhs[entry.key], value == entry.value else {
                return false
            }
        }
        return true
    }

    public func value(forKey key: String) -> JSONValue? {
        guard let index = indexByKey[key] else { return nil }
        return entries[index].value
    }

    public mutating func reserveCapacity(_ capacity: Int) {
        entries.reserveCapacity(capacity)
        indexByKey.reserveCapacity(capacity)
    }
}

extension JSONObject: Sequence {
    public typealias Element = Entry

    public func makeIterator() -> IndexingIterator<[Entry]> {
        entries.makeIterator()
    }
}
