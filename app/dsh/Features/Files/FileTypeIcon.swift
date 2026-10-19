import SwiftUI
import DSHProtocol

struct FileTypeIcon: View {
    let path: String
    var type = "file"
    var openable = true
    var expanded: Bool? = nil
    var size: CGFloat = CGFloat(fileTreeFileIconSizePoints)
    /// File-tree rows keep a 20pt column around the 16pt desktop glyph.
    var slotWidth: CGFloat = 20

    var body: some View {
        let kind = fileTypeKind(path: path, type: type)
        let color = openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3
        Group {
            if kind == "folder" {
                OfficialGlyph(
                    kind: (expanded ?? false) ? .folderOpen : .folderClose,
                    size: size,
                    color: color
                )
            } else if kind == "warning" {
                OfficialGlyph(
                    kind: .warningOutline,
                    size: size,
                    color: color
                )
            } else if fileTypeHasTraditionalGlyph(kind) {
                FileTypeGlyph(kind: kind, size: size, fill: color)
            } else if fileTypeHasCodeFileArtwork(kind) {
                CodeFileArtworkIcon(kind: kind, size: size)
            } else {
                FileTypeGlyph(kind: "other", size: size, fill: color)
            }
        }
        .frame(width: slotWidth, height: size)
    }
}

/// Desktop `ui-primitives` `CodeFileIcon`: 20×20 official markup rasterized
/// to a PDF vector asset at build time (text / clipPath / linearGradient /
/// nested svg). Full-color: never re-tinted.
struct CodeFileArtworkIcon: View {
    let kind: String
    var size: CGFloat = 16

    var body: some View {
        Image(fileTypeCodeFileAssetName(kind))
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .accessibilityIdentifier(fileTypeSymbol(kind))
    }
}

/// Desktop `ui-primitives` `FileGlyph` 28×16 folded sheet + category mark.
/// Marks are `--dsw-static-neutral-00`; fold is muted `#a2a4a6` for `other`
/// else white at 70%. Language `CODE_FILE_ARTWORK` is `CodeFileArtworkIcon`.
struct FileTypeGlyph: View {
    let kind: String
    var size: CGFloat = 16
    var fill: Color

    var body: some View {
        let fold: Color = kind == "other"
            ? Color(hex: fileGlyphMutedFoldHex)
            : Color.white.opacity(fileGlyphFoldWhiteOpacity)
        Canvas { context, canvas in
            let scale = min(canvas.width, canvas.height) / CGFloat(fileGlyphViewBox)
            var ctx = context
            ctx.scaleBy(x: scale, y: scale)
            ctx.fill(Path(SVGPath.cgPath(fileGlyphBodyPath)), with: .color(fill))
            ctx.fill(Path(SVGPath.cgPath(fileGlyphFoldPath)), with: .color(fold))
            guard kind != "other" else { return }
            var mark = ctx
            if fileTypeUsesLargeMark(kind) || fileTypeUsesCenteredMark(kind) {
                let factor = fileTypeUsesLargeMark(kind) ? fileGlyphLargeMarkScale : fileGlyphMarkScale
                mark.translateBy(x: 14, y: 16)
                mark.scaleBy(x: factor, y: factor)
                mark.translateBy(x: -14, y: -16)
            }
            paintMarks(&mark, kind: kind)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .accessibilityIdentifier(fileTypeSymbol(kind))
    }

    private func paintMarks(_ ctx: inout GraphicsContext, kind: String) {
        let white = Color.white
        switch kind {
        case "code":
            let stroke = StrokeStyle(
                lineWidth: CGFloat(fileGlyphCodeStrokeWidth),
                lineCap: .round,
                lineJoin: .round
            )
            ctx.stroke(Path(SVGPath.cgPath(fileGlyphCodeLeftPath)), with: .color(white), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(fileGlyphCodeRightPath)), with: .color(white), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(fileGlyphCodeSlashPath)), with: .color(white), style: stroke)
        case "excel":
            let stroke = StrokeStyle(
                lineWidth: CGFloat(fileGlyphExcelStrokeWidth),
                lineCap: .round,
                lineJoin: .round
            )
            ctx.stroke(Path(SVGPath.cgPath(fileGlyphExcelGridPath)), with: .color(white), style: stroke)
        case "html":
            ctx.fill(
                Path(SVGPath.cgPath(fileGlyphHtmlMarkPath)),
                with: .color(white),
                style: FillStyle(eoFill: true)
            )
        case "image":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphImagePeakPath)), with: .color(white))
            ctx.fill(Path(SVGPath.cgPath(fileGlyphImageHillPath)), with: .color(white))
            ctx.fill(Path(SVGPath.cgPath(fileGlyphImageSunPath)), with: .color(white))
        case "markdown":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphMarkdownMarkPath)), with: .color(white))
        case "pdf":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphPdfMarkPath)), with: .color(white))
        case "ppt":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphPptMarkPath)), with: .color(white))
        case "video":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphVideoMarkPath)), with: .color(white))
        case "word":
            ctx.fill(Path(SVGPath.cgPath(fileGlyphWordMarkPath)), with: .color(white))
        default:
            break
        }
    }
}
