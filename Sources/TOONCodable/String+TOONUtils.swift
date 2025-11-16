import Foundation

extension String {
    func indentString(count indent: Int) -> String {
        guard indent > 0 else { return "" }
        return String(repeating: " ", count: indent)
    }

    func stripIndent(count: Int) -> String {
        guard count > 0 else { return self }
        var remaining = count
        var index = self.startIndex
        while remaining > 0 && index < self.endIndex && self[index] == " " {
            index = self.index(after: index)
            remaining -= 1
        }
        return String(self[index...])
    }
}
