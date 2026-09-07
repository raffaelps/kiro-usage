import AppKit

let sourcePath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    fatalError("could not load \(sourcePath)")
}
guard let cgSource = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("could not get CGImage")
}

// Find the alpha bounding box so we trim the transparent margin ChatGPT left around the art.
func alphaBoundingBox(_ cgImage: CGImage) -> CGRect {
    let width = cgImage.width
    let height = cgImage.height
    guard let data = cgImage.dataProvider?.data,
          let ptr = CFDataGetBytePtr(data) else {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    let bytesPerRow = cgImage.bytesPerRow
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    // Figure out the alpha byte offset (assume alpha is last for typical RGBA/premultiplied layouts).
    let alphaInfo = cgImage.alphaInfo
    let alphaOffset: Int
    switch alphaInfo {
    case .premultipliedFirst, .first, .noneSkipFirst:
        alphaOffset = 0
    default:
        alphaOffset = bytesPerPixel - 1
    }

    var minX = width, minY = height, maxX = 0, maxY = 0
    let threshold: UInt8 = 5
    for y in 0..<height {
        let rowStart = y * bytesPerRow
        for x in 0..<width {
            let pixelStart = rowStart + x * bytesPerPixel
            let alpha = ptr[pixelStart + alphaOffset]
            if alpha > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
    }
    if minX > maxX || minY > maxY {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let bbox = alphaBoundingBox(cgSource)
print("alpha bbox: \(bbox)")

guard let cropped = cgSource.cropping(to: bbox) else {
    fatalError("could not crop")
}

// Compose onto a 1024x1024 squircle with a soft light background.
let canvasSize: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
canvas.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let radius: CGFloat = canvasSize * 0.2237
let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let clipPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(clipPath)
ctx.clip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(calibratedRed: 0.97, green: 0.95, blue: 1.0, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.90, green: 0.87, blue: 0.98, alpha: 1.0).cgColor
]
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: canvasSize),
    end: CGPoint(x: canvasSize, y: 0),
    options: []
)

// Fit the cropped artwork within a padded content box, preserving aspect ratio.
let paddingRatio: CGFloat = 0.09
let contentSize = canvasSize * (1 - paddingRatio * 2)
let artAspect = CGFloat(cropped.width) / CGFloat(cropped.height)
var drawWidth = contentSize
var drawHeight = contentSize / artAspect
if drawHeight > contentSize {
    drawHeight = contentSize
    drawWidth = contentSize * artAspect
}
let drawX = (canvasSize - drawWidth) / 2
let drawY = (canvasSize - drawHeight) / 2

ctx.draw(cropped, in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))

canvas.unlockFocus()

guard
    let tiff = canvas.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("could not encode png")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
