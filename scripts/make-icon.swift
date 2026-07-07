#!/usr/bin/env swift
// Generates Resources/AppIcon.icns — a dark rounded tile with a mint `>_`
// terminal prompt. Run: swift scripts/make-icon.swift
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded-rect tile (macOS-style squircle proportions).
    let margin = size * 0.085
    let side = size - margin * 2
    let radius = side * 0.2237
    let tile = CGRect(x: margin, y: margin, width: side, height: side)
    let path = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.addPath(path)
    ctx.clip()
    let colors = [NSColor(srgbRed: 0.13, green: 0.15, blue: 0.18, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.08, green: 0.09, blue: 0.11, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.resetClip()

    // Subtle top highlight stroke.
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.06).cgColor)
    ctx.setLineWidth(size * 0.006)
    ctx.strokePath()

    let mint = NSColor(srgbRed: 0x6e / 255, green: 0xe7 / 255, blue: 0xb7 / 255, alpha: 1).cgColor
    let ox = tile.minX, oy = tile.minY, S = side

    // Chevron ">"
    ctx.setStrokeColor(mint)
    ctx.setLineWidth(S * 0.085)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: ox + 0.30 * S, y: oy + 0.66 * S))
    ctx.addLine(to: CGPoint(x: ox + 0.52 * S, y: oy + 0.50 * S))
    ctx.addLine(to: CGPoint(x: ox + 0.30 * S, y: oy + 0.34 * S))
    ctx.strokePath()

    // Cursor underscore "_"
    let bar = CGRect(x: ox + 0.575 * S, y: oy + 0.305 * S, width: S * 0.19, height: S * 0.075)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: bar.height / 2, cornerHeight: bar.height / 2, transform: nil))
    ctx.setFillColor(mint)
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments.first.map { ($0 as NSString).deletingLastPathComponent } ?? ".")
    .deletingLastPathComponent()  // project root (script is in scripts/)
let iconset = fm.temporaryDirectory.appendingPathComponent("Nexus.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for (name, size) in sizes {
    let png = draw(size: size).representation(using: .png, properties: [:])!
    try! png.write(to: iconset.appendingPathComponent("\(name).png"))
}

let resources = root.appendingPathComponent("Resources")
try? fm.createDirectory(at: resources, withIntermediateDirectories: true)
let icns = resources.appendingPathComponent("AppIcon.icns")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote \(icns.path)" : "iconutil failed")
