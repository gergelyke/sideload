/// A thin accessor over a parsed `.pbxproj`'s flat `objects` table —
/// every PBX object is just a dictionary keyed by its 24-character ID,
/// cross-referencing other objects by ID.
struct PBXProjectFile {
    let objects: [String: PlistValue]
    let rootObjectID: String

    enum Error: Swift.Error, CustomStringConvertible {
        case missingObjectsTable
        case missingRootObject

        var description: String {
            switch self {
            case .missingObjectsTable: return "project.pbxproj has no 'objects' table"
            case .missingRootObject: return "project.pbxproj has no 'rootObject'"
            }
        }
    }

    init(text: String) throws {
        let root = try PBXPlistParser.parse(text)
        guard let objects = root["objects"]?.dictionaryValue else {
            throw Error.missingObjectsTable
        }
        guard let rootObjectID = root["rootObject"]?.stringValue else {
            throw Error.missingRootObject
        }
        self.objects = objects
        self.rootObjectID = rootObjectID
    }

    func object(_ id: String) -> PlistValue? {
        objects[id]
    }

    func isa(_ id: String) -> String? {
        objects[id]?["isa"]?.stringValue
    }

    /// `arrayValue` elements in a PBX object list are bare ID strings
    /// (Xcode writes a trailing `/* comment */` that the parser already
    /// discarded) — this just extracts them.
    func ids(_ value: PlistValue?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }
}
