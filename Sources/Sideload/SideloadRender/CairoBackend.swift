import CCairo
import CFreeType

/// Draws a `RenderNode` tree with Cairo into an ARGB32 `Frame`, depth-first.
/// Glyph runs are drawn with `cairo_show_glyphs` at HarfBuzz-shaped
/// positions — never `cairo_show_text`, which would re-shape with Cairo's
/// own (unrelated) font fallback.
@MainActor
public final class CairoBackend: RenderBackend {
    private let fontLibrary: FontLibrary

    public init(fontLibrary: FontLibrary) {
        self.fontLibrary = fontLibrary
    }

    public func render(_ root: RenderNode, into frame: inout Frame) {
        frame.buffer.withUnsafeMutableBufferPointer { ptr in
            guard let surface = cairo_image_surface_create_for_data(
                ptr.baseAddress,
                CAIRO_FORMAT_ARGB32,
                Int32(frame.pixelWidth),
                Int32(frame.pixelHeight),
                Int32(frame.stride)
            ) else { return }
            defer { cairo_surface_destroy(surface) }
            guard let cr = cairo_create(surface) else { return }
            defer { cairo_destroy(cr) }

            cairo_scale(cr, frame.scale, frame.scale)

            // Clear to white.
            cairo_set_source_rgba(cr, 1, 1, 1, 1)
            cairo_paint(cr)

            draw(root, offset: Point(x: 0, y: 0), in: cr)
        }
    }

    private func draw(_ node: RenderNode, offset: Point, in cr: OpaquePointer) {
        switch node {
        case .group(let groupOffset, let children):
            let childOffset = Point(x: offset.x + groupOffset.x, y: offset.y + groupOffset.y)
            for child in children {
                draw(child, offset: childOffset, in: cr)
            }

        case .fillRect(let rect, let color):
            cairo_set_source_rgba(cr, color.red, color.green, color.blue, color.alpha)
            cairo_rectangle(cr, offset.x + rect.origin.x, offset.y + rect.origin.y, rect.size.width, rect.size.height)
            cairo_fill(cr)

        case .glyphRun(let run, let origin, let color, let font):
            drawGlyphRun(run, origin: Point(x: offset.x + origin.x, y: offset.y + origin.y), color: color, font: font, in: cr)

        case .path(let ops, let fill, let stroke, let style):
            drawPath(ops, offset: offset, fill: fill, stroke: stroke, style: style, in: cr)
        }
    }

    private func drawGlyphRun(_ run: ShapedRun, origin: Point, color: RGBA, font: FontSpec, in cr: OpaquePointer) {
        guard !run.glyphs.isEmpty else { return }
        guard let ftFace = try? fontLibrary.face(weight: font.weight, sizeInPoints: font.size) else { return }
        guard let cairoFace = cairo_ft_font_face_create_for_ft_face(ftFace, 0) else { return }
        defer { cairo_font_face_destroy(cairoFace) }

        cairo_set_font_face(cr, cairoFace)
        cairo_set_font_size(cr, font.size)
        cairo_set_source_rgba(cr, color.red, color.green, color.blue, color.alpha)

        var cairoGlyphs = run.glyphs.map { glyph in
            cairo_glyph_t(index: UInt(glyph.glyphID), x: origin.x + glyph.x, y: origin.y + glyph.y)
        }
        cairoGlyphs.withUnsafeMutableBufferPointer { buf in
            cairo_show_glyphs(cr, buf.baseAddress, Int32(buf.count))
        }
    }

    private func drawPath(_ ops: [PathOp], offset: Point, fill: RGBA?, stroke: RGBA?, style: StrokeStyle?, in cr: OpaquePointer) {
        cairo_new_path(cr)
        for op in ops {
            switch op {
            case .move(let p):
                cairo_move_to(cr, offset.x + p.x, offset.y + p.y)
            case .line(let p):
                cairo_line_to(cr, offset.x + p.x, offset.y + p.y)
            case .quad(let control, let end):
                // Cairo has no quadratic primitive; promote to the
                // equivalent cubic (both control points pulled 2/3 of the
                // way from the endpoints to the quadratic control point).
                var startX: Double = 0
                var startY: Double = 0
                cairo_get_current_point(cr, &startX, &startY)
                let controlX = offset.x + control.x
                let controlY = offset.y + control.y
                let endX = offset.x + end.x
                let endY = offset.y + end.y
                let c1x = startX + (controlX - startX) * 2 / 3
                let c1y = startY + (controlY - startY) * 2 / 3
                let c2x = endX + (controlX - endX) * 2 / 3
                let c2y = endY + (controlY - endY) * 2 / 3
                cairo_curve_to(cr, c1x, c1y, c2x, c2y, endX, endY)
            case .curve(let c1, let c2, let end):
                cairo_curve_to(
                    cr,
                    offset.x + c1.x, offset.y + c1.y,
                    offset.x + c2.x, offset.y + c2.y,
                    offset.x + end.x, offset.y + end.y
                )
            case .close:
                cairo_close_path(cr)
            }
        }

        if let fill {
            cairo_set_source_rgba(cr, fill.red, fill.green, fill.blue, fill.alpha)
            if stroke != nil { cairo_fill_preserve(cr) } else { cairo_fill(cr) }
        }
        if let stroke {
            cairo_set_source_rgba(cr, stroke.red, stroke.green, stroke.blue, stroke.alpha)
            if let style {
                cairo_set_line_width(cr, style.width)
                cairo_set_line_cap(cr, style.cap == .round ? CAIRO_LINE_CAP_ROUND : CAIRO_LINE_CAP_BUTT)
                cairo_set_line_join(cr, style.join == .round ? CAIRO_LINE_JOIN_ROUND : CAIRO_LINE_JOIN_MITER)
            }
            cairo_stroke(cr)
        }
    }
}
