// Renders a SwiftBar menu (the plugin's real stdout) into a PNG for the README.
//
//   ./bin/app-updates menu | swift tools/preview.swift docs/menu.png
//
// This is a preview of the actual menu content, not a screen capture: it exists
// so the README can show what the plugin produces without a screenshot that goes
// stale on the next UI change.
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
    var red: Bool = false
    var orange: Bool = false
    var bold: Bool = false
    var checked: Bool = false
    var symbol: String?
    var symbolColor: NSColor?
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

func color(_ name: String?) -> NSColor? {
    switch name {
    case "red": return .systemRed
    case "orange": return .systemOrange
    case "gray": return NSColor(calibratedWhite: 0.5, alpha: 1)
    case "green": return .systemGreen
    default: return nil
    }
}

// Everything before the first separator is what SwiftBar shows in the menu bar.
var barTitle = ""
var rows: [Row] = []
var inBody = false

for line in raw.split(separator: "\n").map(String.init) where !line.isEmpty {
    if line == "---" {
        inBody = true
        rows.append(Row(kind: .separator))
        continue
    }
    if !inBody {
        barTitle = splitParams(line).title
        continue
    }

    var level = 0
    var body = line
    while body.hasPrefix("--") {
        level += 1
        body.removeFirst(2)
    }
    body = body.trimmingCharacters(in: .whitespaces)

    let (title, p) = splitParams(body)
    if p["alternate"] == "true" { continue }  // hidden until Option is held

    let clean = title.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
    rows.append(Row(kind: .item,
                    text: clean,
                    level: level,
                    secondary: p["size"] == "11",
                    red: p["color"] == "red",
                    orange: p["color"] == "orange",
                    bold: title.contains("**"),
                    checked: p["checked"] == "true",
                    symbol: p["sfimage"],
                    symbolColor: color(p["color"] ?? p["sfcolor"])))
}

let scale: CGFloat = 2
let panelWidth: CGFloat = 470
let barHeight: CGFloat = 30
let gap: CGFloat = 8
let insetX: CGFloat = 14
let symbolWidth: CGFloat = 20
let rowHeight: CGFloat = 22
let headerHeight: CGFloat = 20
let separatorHeight: CGFloat = 9
let padY: CGFloat = 10

var height = barHeight + gap + padY * 2
for row in rows {
    switch row.kind {
    case .separator: height += separatorHeight
    case .header: height += headerHeight
    case .item: height += rowHeight
    }
}

let pixelSize = NSSize(width: panelWidth * scale, height: height * scale)
let image = NSImage(size: pixelSize)
image.lockFocus()
NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

NSColor.white.setFill()
NSRect(x: 0, y: 0, width: panelWidth, height: height).fill()

// Menu bar strip with the plugin icon and count.
let barRect = NSRect(x: 0, y: height - barHeight, width: panelWidth, height: barHeight)
NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
barRect.fill()
NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
NSRect(x: 0, y: height - barHeight, width: panelWidth, height: 1).fill()

var barText = barTitle
var barSymbol = "arrow.down.circle.fill"
var barColor = NSColor.systemOrange
if barTitle.isEmpty {
    barSymbol = "arrow.down.circle"
    barColor = NSColor(calibratedWhite: 0.5, alpha: 1)
    barText = ""
}
let barAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                               .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1)]
let barString = NSAttributedString(string: barText, attributes: barAttrs)
let barTextSize = barString.size()
let barX = panelWidth - insetX - barTextSize.width - 18
barString.draw(at: NSPoint(x: barX, y: height - barHeight + 7))
let barPalette: [NSColor] = barSymbol.hasSuffix(".fill") ? [.white, barColor] : [barColor]
if let sym = NSImage(systemSymbolName: barSymbol, accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(paletteColors: barPalette)) {
    sym.draw(in: NSRect(x: barX + barTextSize.width + 3, y: height - barHeight + 8, width: 14, height: 14))
}

// Dropdown panel.
let panelBottom = gap
let panelHeight = height - barHeight - gap
let panel = NSBezierPath(roundedRect: NSRect(x: 0.5, y: panelBottom + 0.5, width: panelWidth - 1, height: panelHeight - 1),
                         xRadius: 10, yRadius: 10)
NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
panel.fill()
NSColor(calibratedWhite: 0.84, alpha: 1).setStroke()
panel.lineWidth = 1
panel.stroke()

func font(_ secondary: Bool, _ bold: Bool) -> NSFont {
    NSFont.systemFont(ofSize: secondary ? 11 : 13, weight: bold ? .semibold : .regular)
}

var y = height - barHeight - gap - padY
for row in rows {
    switch row.kind {
    case .separator:
        NSColor(calibratedWhite: 0.87, alpha: 1).setFill()
        NSRect(x: insetX, y: y - separatorHeight / 2, width: panelWidth - insetX * 2, height: 1).fill()
        y -= separatorHeight
    case .header:
        y -= headerHeight
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font(true, true),
            .foregroundColor: NSColor(calibratedWhite: 0.4, alpha: 1),
        ]
        NSAttributedString(string: row.text, attributes: attrs).draw(at: NSPoint(x: insetX, y: y + 4))
    case .item:
        y -= rowHeight
        let indent = insetX + CGFloat(row.level) * 12
        var textColor = NSColor(calibratedWhite: 0.13, alpha: 1)
        if row.secondary { textColor = NSColor(calibratedWhite: 0.45, alpha: 1) }
        if row.red { textColor = .systemRed }
        if row.orange { textColor = .systemOrange }

        var textX = indent
        if let name = row.symbol {
            let tint = row.symbolColor ?? textColor
            let palette: [NSColor] = name.hasSuffix(".fill") ? [.white, tint] : [tint]
            let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: palette))
            sym?.draw(in: NSRect(x: indent, y: y + 4, width: 14, height: 14))
            textX += symbolWidth
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font(row.secondary, row.bold),
            .foregroundColor: textColor,
        ]
        let text = row.checked ? "✓ " + row.text : row.text
        NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: textX, y: y + 4))
    }
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("preview: cannot render PNG".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath) (\(Int(panelWidth))x\(Int(height)) pt @\(Int(scale))x)")
