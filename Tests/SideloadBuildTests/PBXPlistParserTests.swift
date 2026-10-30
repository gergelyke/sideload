import Foundation
import Testing
@testable import SideloadBuild

@Suite struct PBXPlistParserTests {
    @Test func parsesBareAndQuotedStringsArraysAndNestedDictionaries() throws {
        let text = """
        // !$*UTF8*$!
        {
            a = bareWord;
            b = "quoted value with \\"escapes\\" and \\\\slashes";
            c = (
                1stItem,
                "second item",
            );
            nested = {
                inner = value;
            };
        }
        """
        let value = try PBXPlistParser.parse(text)
        #expect(value["a"]?.stringValue == "bareWord")
        #expect(value["b"]?.stringValue == "quoted value with \"escapes\" and \\slashes")
        #expect(value["c"]?.arrayValue?.count == 2)
        #expect(value["c"]?.arrayValue?[0].stringValue == "1stItem")
        #expect(value["nested"]?["inner"]?.stringValue == "value")
    }

    @Test func skipsLineAndBlockComments() throws {
        let text = """
        // leading comment
        { /* block
             comment */
            key = value; // trailing comment
        }
        """
        let value = try PBXPlistParser.parse(text)
        #expect(value["key"]?.stringValue == "value")
    }

    @Test func reportsLineNumberOnSyntaxError() {
        let text = """
        {
            key = value
            missingSemicolon = true;
        }
        """
        #expect(throws: PBXPlistParseError.self) {
            try PBXPlistParser.parse(text)
        }
        do {
            _ = try PBXPlistParser.parse(text)
            Issue.record("expected a parse error")
        } catch let error as PBXPlistParseError {
            #expect(error.line == 3)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func parsesTheSynchronizedFixtureFile() throws {
        let path = fixturesDirectory() + "/Synchronized.pbxproj"
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let value = try PBXPlistParser.parse(text)
        #expect(value["rootObject"]?.stringValue == "PROJ000000000000000000001")
        #expect(value["objects"]?["TGT000000000000000000001"]?["name"]?.stringValue == "HelloWorld")
    }

    @Test func parsesTheClassicFixtureFile() throws {
        let path = fixturesDirectory() + "/Classic.pbxproj"
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let value = try PBXPlistParser.parse(text)
        #expect(value["objects"]?["GRP100000000000000000002"]?["path"]?.stringValue == "Sub")
    }
}
