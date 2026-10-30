import CFreeType
import Foundation

public enum FontError: Error, Sendable {
    case libraryInitFailed
    case faceLoadFailed(String)
}

/// Loads the vendored Inter variable font and hands out an `FT_Face` set to
/// a requested weight along its `wght` axis. All FreeType calls happen on
/// the main actor; FreeType is not thread-safe.
@MainActor
public final class FontLibrary {
    private var library: FT_Library?
    private var face: FT_Face?
    private var wghtAxisIndex: Int?

    public init(resourcesDirectory: String) throws {
        var lib: FT_Library?
        guard FT_Init_FreeType(&lib) == 0, let lib else {
            throw FontError.libraryInitFailed
        }
        self.library = lib

        let fontPath = resourcesDirectory + "/Fonts/Inter/Inter-Variable.ttf"
        var loadedFace: FT_Face?
        let error = FT_New_Face(lib, fontPath, 0, &loadedFace)
        guard error == 0, let loadedFace else {
            throw FontError.faceLoadFailed("could not open \(fontPath) (FreeType error \(error))")
        }
        self.face = loadedFace
        self.wghtAxisIndex = Self.findWeightAxis(in: loadedFace, library: lib)
    }

    isolated deinit {
        if let face { FT_Done_Face(face) }
        if let library { FT_Done_FreeType(library) }
    }

    private static func findWeightAxis(in face: FT_Face, library: FT_Library) -> Int? {
        var mmVar: UnsafeMutablePointer<FT_MM_Var>?
        guard FT_Get_MM_Var(face, &mmVar) == 0, let mmVar else { return nil }
        defer { FT_Done_MM_Var(library, mmVar) }
        let axisCount = Int(mmVar.pointee.num_axis)
        for i in 0..<axisCount {
            let axis = mmVar.pointee.axis[i]
            // FreeType packs the 4-byte axis tag big-endian into a UInt32.
            if axis.tag == 0x77676874 { // 'wght'
                return i
            }
        }
        return nil
    }

    /// Returns a face configured at `weight`, at `sizeInPoints` and 72 dpi
    /// (so 1 font unit == 1 point, matching `HarfBuzzTextMeasurer`'s 26.6
    /// conversion).
    public func face(weight: FontWeight, sizeInPoints: Double) throws -> FT_Face {
        guard let face, let library else { throw FontError.faceLoadFailed("library not initialized") }
        if let wghtAxisIndex {
            var mmVar: UnsafeMutablePointer<FT_MM_Var>?
            if FT_Get_MM_Var(face, &mmVar) == 0, let mmVar {
                let axisCount = Int(mmVar.pointee.num_axis)
                var coords = [FT_Fixed](repeating: 0, count: axisCount)
                FT_Get_Var_Design_Coordinates(face, FT_UInt(axisCount), &coords)
                coords[wghtAxisIndex] = FT_Fixed(weight.rawValue) &* 65536
                _ = coords.withUnsafeMutableBufferPointer { buf in
                    FT_Set_Var_Design_Coordinates(face, FT_UInt(axisCount), buf.baseAddress)
                }
                FT_Done_MM_Var(library, mmVar)
            }
        }
        let sizeIn26_6 = FT_F26Dot6((sizeInPoints * 64).rounded())
        FT_Set_Char_Size(face, 0, sizeIn26_6, 72, 72)
        return face
    }
}
