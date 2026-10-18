import SwiftUI
import DSHProtocol

struct FileTypeIcon: View {
    let path: String
    var type = "file"
    var openable = true
    var expanded: Bool? = nil

    var body: some View {
        let kind = fileTypeKind(path: path, type: type)
        let color = openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3
        Group {
            if kind == "folder" {
                OfficialGlyph(
                    kind: (expanded ?? false) ? .folderOpen : .folderClose,
                    size: CGFloat(fileTreeFileIconSizePoints),
                    color: color
                )
            } else if kind == "warning" {
                OfficialGlyph(
                    kind: .warningOutline,
                    size: CGFloat(fileTreeFileIconSizePoints),
                    color: color
                )
            } else if fileTypeHasTraditionalGlyph(kind) {
                FileTypeGlyph(kind: kind, size: CGFloat(fileTreeFileIconSizePoints), fill: color)
            } else {
                Image(systemName: fileTypeSymbol(kind))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 20)
    }
}

/// Desktop `ui-primitives` `FileGlyph` 28×16 folded sheet + category mark.
/// Marks are `--dsw-static-neutral-00`; fold is muted `#a2a4a6` for `other`
/// else white at 70%. Language `CODE_FILE_ARTWORK` is not painted here.
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
