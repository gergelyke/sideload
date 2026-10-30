/// A parsed OpenStep-style property list, the ASCII format Xcode still
/// writes `.pbxproj` files in (distinct from Apple's binary/XML plist
/// formats, which `PropertyListSerialization` reads but this one isn't).
public enum PlistValue: Equatable {
    case string(String)
    case array([PlistValue])
    case dictionary([String: PlistValue])

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [PlistValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var dictionaryValue: [String: PlistValue]? {
        if case .dictionary(let d) = self { return d }
        return nil
    }

    public subscript(key: String) -> PlistValue? {
        dictionaryValue?[key]
    }
}

public struct PBXPlistParseError: Error, CustomStringConvertible {
    public let line: Int
    public let message: String

    public var description: String { "line \(line): \(message)" }
}

/// Parses the OpenStep plist grammar Xcode writes: a root dictionary of
/// `key = value;` pairs, arrays `(a, b, c)`, quoted strings with
/// backslash escapes, bare (unquoted) identifier strings, `//` and
/// `/* */` comments, and a trailing comma before a closing `)` or `}`.
public enum PBXPlistParser {
    public static func parse(_ text: String) throws -> PlistValue {
        var scanner = Scanner(text)
        scanner.skipWhitespaceAndComments()
        let value = try scanner.parseValue()
        scanner.skipWhitespaceAndComments()
        return value
    }

    private struct Scanner {
        let characters: [Character]
        var index = 0
        var line = 1

        init(_ text: String) {
            self.characters = Array(text)
        }

        private var current: Character? {
            index < characters.count ? characters[index] : nil
        }

        private mutating func advance() -> Character? {
            guard index < characters.count else { return nil }
            let c = characters[index]
            index += 1
            if c == "\n" { line += 1 }
            return c
        }

        mutating func skipWhitespaceAndComments() {
            while let c = current {
                if c.isWhitespace {
                    _ = advance()
                } else if c == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                    while let c = current, c != "\n" { _ = advance() }
                } else if c == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                    _ = advance(); _ = advance()
                    while index < characters.count, !(current == "*" && index + 1 < characters.count && characters[index + 1] == "/") {
                        _ = advance()
                    }
                    _ = advance(); _ = advance() // closing */
                } else {
                    break
                }
            }
        }

        mutating func parseValue() throws -> PlistValue {
            skipWhitespaceAndComments()
            switch current {
            case "{": return try parseDictionary()
            case "(": return try parseArray()
            case "\"": return .string(try parseQuotedString())
            case .some(let c) where isBareStringCharacter(c):
                return .string(try parseBareString())
            default:
                throw PBXPlistParseError(line: line, message: "expected a value, found \(describeCurrent())")
            }
        }

        mutating func parseDictionary() throws -> PlistValue {
            try expect("{")
            var result: [String: PlistValue] = [:]
            skipWhitespaceAndComments()
            while current != "}" {
                guard let c = current else {
                    throw PBXPlistParseError(line: line, message: "unterminated dictionary")
                }
                let key: String
                if c == "\"" {
                    key = try parseQuotedString()
                } else if isBareStringCharacter(c) {
                    key = try parseBareString()
                } else {
                    throw PBXPlistParseError(line: line, message: "expected a dictionary key, found \(describeCurrent())")
                }
                skipWhitespaceAndComments()
                try expect("=")
                let value = try parseValue()
                skipWhitespaceAndComments()
                try expect(";")
                result[key] = value
                skipWhitespaceAndComments()
            }
            try expect("}")
            return .dictionary(result)
        }

        mutating func parseArray() throws -> PlistValue {
            try expect("(")
            var result: [PlistValue] = []
            skipWhitespaceAndComments()
            while current != ")" {
                let value = try parseValue()
                result.append(value)
                skipWhitespaceAndComments()
                if current == "," {
                    _ = advance()
                    skipWhitespaceAndComments()
                } else {
                    break
                }
            }
            try expect(")")
            return .array(result)
        }

        mutating func parseQuotedString() throws -> String {
            try expect("\"")
            var result = ""
            while let c = current, c != "\"" {
                if c == "\\" {
                    _ = advance()
                    guard let escaped = advance() else {
                        throw PBXPlistParseError(line: line, message: "unterminated escape sequence")
                    }
                    switch escaped {
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "\"": result.append("\"")
                    case "\\": result.append("\\")
                    default: result.append(escaped)
                    }
                } else {
                    result.append(c)
                    _ = advance()
                }
            }
            guard current == "\"" else {
                throw PBXPlistParseError(line: line, message: "unterminated quoted string")
            }
            _ = advance()
            return result
        }

        func isBareStringCharacter(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "." || c == "/" || c == "-"
        }

        mutating func parseBareString() throws -> String {
            var result = ""
            while let c = current, isBareStringCharacter(c) {
                result.append(c)
                _ = advance()
            }
            guard !result.isEmpty else {
                throw PBXPlistParseError(line: line, message: "expected an identifier, found \(describeCurrent())")
            }
            return result
        }

        mutating func expect(_ c: Character) throws {
            skipWhitespaceAndComments()
            guard current == c else {
                throw PBXPlistParseError(line: line, message: "expected '\(c)', found \(describeCurrent())")
            }
            _ = advance()
        }

        func describeCurrent() -> String {
            guard let c = current else { return "end of file" }
            return "'\(c)'"
        }
    }
}
