import Foundation

/// A complete, executable Python report generator, not a title-only preview fixture.
/// CRLF, tabs, Unicode separators and HTML-looking source exercise the JS argument boundary.
enum CodePreviewFixture {
    static let path = "skills/market-insight-report/scripts/generate_report.py"
    static let longLine = "# CODE_PREVIEW_WRAP: " + String(repeating: "市场报告 <section> & 数据 \"quoted\" 日本語 café λ — ", count: 12)

    static var python: String {
        let records = (1...96).map { index in
            "    Observation(region=\"区域\(index)\", revenue=\(index * 137), note=\"市场增长 & 技术创新\"),"
        }.joined(separator: "\n")
        let script = #"""
        #!/usr/bin/env python3
        # CODE_PREVIEW_BEGIN: 地面洞察报告生成 CLI
        \#(longLine)
        """Generate an offline report from typed market observations."""
        from __future__ import annotations

        import argparse
        import html
        from dataclasses import dataclass
        from pathlib import Path

        # CODE_PREVIEW_LITERAL: </script><img src=x onerror=alert(1)> & "引号"
        # CODE_PREVIEW_UNICODE: 日本語 café λ — 中文
        SEPARATORS = "\#("\u{2028}\u{2029}")"
        HTML_EXAMPLE = '<script>window.sourceExecuted = true</script>'
        WINDOWS_PATH = r"C:\reports\市场洞察\report.html"

        @dataclass(frozen=True)
        class Observation:
            region: str
            revenue: int
            note: str

        OBSERVATIONS = [
        \#(records)
        ]

        def totals(rows: list[Observation]) -> dict[str, int]:
            result: dict[str, int] = {}
            for row in rows:
                result[row.region] = result.get(row.region, 0) + row.revenue
            return result

        def render(rows: list[Observation], title: str) -> str:
            sections = []
            for region, revenue in sorted(totals(rows).items()):
                sections.append(
                    f"<section><h2>{html.escape(region)}</h2>"
                    f"<p>收入: {revenue:,}</p></section>"
                )
            return (
                '<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
                f"<title>{html.escape(title)}</title>"
                f"<h1>{html.escape(title)}</h1>"
                + "\n".join(sections)
                + "</html>"
            )

        def main() -> None:
            parser = argparse.ArgumentParser(description="离线市场洞察报告")
            parser.add_argument("--out", type=Path, default=Path("report.html"))
            parser.add_argument("--title", default="全球市场洞察")
            args = parser.parse_args()
            args.out.write_text(render(OBSERVATIONS, args.title), encoding="utf-8")
            print(f"报告已生成: {args.out}")

        if __name__ == "__main__":
        \#("\t")main()
        # CODE_PREVIEW_END: 完整源文件结束
        """#
        return script.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n"
    }
}
