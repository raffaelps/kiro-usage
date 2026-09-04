import AppKit

// All layout math is in points, matching the Finder window's coordinate space
// (create-dmg's --window-size / --icon / --app-drop-link use these same point
// values), then scaled up for a crisp render.
let widthPt: CGFloat = 660
let heightPt: CGFloat = 400
let scale: CGFloat = 3

let pxWidth = widthPt * scale
let pxHeight = heightPt * scale

func toPx(_ pt: CGFloat) -> CGFloat { pt * scale }

let canvas = NSImage(size: NSSize(width: pxWidth, height: pxHeight))
canvas.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// Background gradient — soft lavender to white, matching the app's purple brand.
let bgColors = [
    NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.99, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1.0).cgColor
]
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: pxHeight),
    end: CGPoint(x: 0, y: 0),
    options: []
)

func attributedString(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    return NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

// Title — Finder Y measured from the top of the window.
let titleTopPt: CGFloat = 46
let title = attributedString(
    "Instalar Kiro Usage",
    font: NSFont.systemFont(ofSize: 28 * scale, weight: .bold),
    color: NSColor(calibratedWhite: 0.15, alpha: 1.0)
)
title.draw(in: NSRect(x: 0, y: pxHeight - toPx(titleTopPt + 40), width: pxWidth, height: toPx(40)))

let subtitle = attributedString(
    "Arraste o app para a pasta Applications",
    font: NSFont.systemFont(ofSize: 14 * scale, weight: .regular),
    color: NSColor(calibratedWhite: 0.42, alpha: 1.0)
)
subtitle.draw(in: NSRect(x: 0, y: pxHeight - toPx(titleTopPt + 76), width: pxWidth, height: toPx(24)))

// Arrow between the two icon slots. Icons themselves are real Finder icons,
// composited later by create-dmg at (170, 190) and (490, 190) — this only
// draws the connecting arrow between their edges.
let iconCenterYFromTop: CGFloat = 190
let iconCenterYBottom = heightPt - iconCenterYFromTop
let arrowStartXPt: CGFloat = 240
let arrowEndXPt: CGFloat = 420

let purple = NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.86, alpha: 1.0)
ctx.saveGState()
ctx.setStrokeColor(purple.cgColor)
ctx.setFillColor(purple.cgColor)
ctx.setLineWidth(toPx(3.5))
ctx.setLineCap(.round)

let shaftEndXPt = arrowEndXPt - 10
ctx.move(to: CGPoint(x: toPx(arrowStartXPt), y: toPx(iconCenterYBottom)))
ctx.addLine(to: CGPoint(x: toPx(shaftEndXPt), y: toPx(iconCenterYBottom)))
ctx.strokePath()

let arrowHeadHalfHeightPt: CGFloat = 7
let head = CGMutablePath()
head.move(to: CGPoint(x: toPx(arrowEndXPt), y: toPx(iconCenterYBottom)))
head.addLine(to: CGPoint(x: toPx(shaftEndXPt - 1), y: toPx(iconCenterYBottom + arrowHeadHalfHeightPt)))
head.addLine(to: CGPoint(x: toPx(shaftEndXPt - 1), y: toPx(iconCenterYBottom - arrowHeadHalfHeightPt)))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()
ctx.restoreGState()

canvas.unlockFocus()

guard
    let tiff = canvas.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("could not encode png")
}

let outputPath = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath) (\(Int(pxWidth))x\(Int(pxHeight)))")
