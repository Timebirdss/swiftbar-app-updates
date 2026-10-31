// Renders the plugin's real menu output as a PNG preview for the README.
//
//   ./bin/app-updates menu | swift tools/preview.swift docs/menu.png
//
// Styling follows the macOS dark menu: translucent-looking rounded panel,
// 13 pt SF Pro Text, grey separators and template (monochrome) SF Symbols.
import AppKit
import Foundation

let args = CommandLine.arguments
let outputPath = args.count > 1 ? args[1] : "menu.png"
let raw = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""

struct Row {
    enum Kind { case header, item, separator }
    var kind: Kind
    var text: String = ""
    var level: Int = 0
    var secondary: Bool = false
    var title: Bool = false
    var red: Bool = false
    var orange: Bool = false
    var bold: Bool = false
    var checked: Bool = false
    var symbol: String?
    var symbolColor: String?
}

func splitParams(_ line: String) -> (title: String, params: [String: String]) {
    guard let bar = line.range(of: " | ") else { return (line, [:]) }
    let title = String(line[..<bar.lowerBound])
    var dict: [String: String] = [:]
    for token in line[bar.upperBound...].split(separator: " ") {
        guard let eq = token.firstIndex(of: "=") else { continue }
        dict[String(token[..<eq])] = String(token[token.index(after: eq)...])
    }
    return (title, dict)
}

var rows: [Row] = []
var inBody = false
for line in raw.split(separator: "\n").map(String.init) where !line.isEmpty {
    if line == "---" { inBody = true; rows.append(Row(kind: .separator)); continue }
    if !inBody { continue }  // the menu bar line stays out of the preview

    var level = 0
    var body = line
    while body.hasPrefix("--") { level += 1; body.removeFirst(2) }
    body = body.trimmingCharacters(in: .whitespaces)

    let (title, p) = splitParams(body)
    if p["alternate"] == "true" { continue }

    let clean = title.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
    rows.append(Row(kind: .item, text: clean, level: level,
                    secondary: p["size"] == "11" && !title.contains("**"),
                    title: title.contains("**"),
                    red: p["color"] == "red",
                    orange: p["color"] == "orange",
                    bold: title.contains("**"),
                    checked: p["checked"] == "true",
                    symbol: p["sfimage"],
                    symbolColor: p["sfcolor"]))
}
if rows.first?.kind == .separator { rows.removeFirst() }

let scale: CGFloat = 2
let width: CGFloat = 452
let insetX: CGFloat = 14
let symbolSlot: CGFloat = 21
let titleRowHeight: CGFloat = 27
let summaryHeight: CGFloat = 22
let itemHeight: CGFloat = 22
let groupHeight: CGFloat = 22
let separatorHeight: CGFloat = 9
let padY: CGFloat = 9

var height = padY * 2
for row in rows {
    switch row.kind {
    case .separator: height += separatorHeight
    case .header: height += groupHeight
    case .item:
        if row.title { height += titleRowHeight }
        else if row.secondary { height += summaryHeight }
        else { height += itemHeight }
    }
}

let image = NSImage(size: NSSize(width: width * scale, height: height * scale))
image.lockFocus()
NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

// Panel: solid stand-in for the system's blur, subtle light border.
let panelRect = NSRect(x: 0, y: 0, width: width, height: height)
let panel = NSBezierPath(roundedRect: panelRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
NSColor(calibratedRed: 0.137, green: 0.137, blue: 0.145, alpha: 1).setFill()
panel.fill()
NSColor(calibratedWhite: 1, alpha: 0.09).setStroke()
panel.lineWidth = 1
panel.stroke()

let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
let boldFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
let smallFont = NSFont.systemFont(ofSize: 11.5, weight: .regular)
let groupFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

let primary = NSColor(calibratedWhite: 0.94, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.62, alpha: 1)
let iconColor = NSColor(calibratedWhite: 0.72, alpha: 1)

func icon(_ name: String, color: NSColor) -> NSImage? {
    let palette: [NSColor] = name.hasSuffix(".fill") ? [.white, color] : [color]
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(paletteColors: palette))
}

var y = height - padY
for row in rows {
    switch row.kind {
    case .separator:
        NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
        NSRect(x: 0, y: y - separatorHeight / 2, width: width, height: 1).fill()
        y -= separatorHeight
    case .header:
        let attrs: [NSAttributedString.Key: Any] = [.font: groupFont, .foregroundColor: secondary]
        NSAttributedString(string: row.text, attributes: attrs)
            .draw(at: NSPoint(x: insetX, y: y - groupHeight + 5))
        y -= groupHeight
    case .item:
        let h: CGFloat = row.title ? titleRowHeight : (row.secondary ? summaryHeight : itemHeight)
        var color = primary
        if row.secondary { color = secondary }
        if row.red { color = .systemRed }
        if row.orange { color = .systemOrange }
        var textX = insetX
        if let name = row.symbol {
            let tint = row.symbolColor == nil ? iconColor : (color)
            if let sym = icon(name, color: tint) {
                sym.draw(in: NSRect(x: insetX, y: y - h + 4, width: 14, height: 14))
            }
            textX += symbolSlot
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: row.title ? boldFont : (row.secondary ? smallFont : bodyFont),
            .foregroundColor: color,
        ]
        let text = row.checked ? "✓ " + row.text : row.text
        NSAttributedString(string: text, attributes: attrs)
            .draw(at: NSPoint(x: textX, y: y - h + (row.title ? 7 : 4)))
        y -= h
    }
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("preview: cannot render PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath) (\(Int(width))x\(Int(height)) pt @\(Int(scale))x)")
