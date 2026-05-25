#!/usr/bin/env xcrun swift
// 生成 LaunchDesk 占位图标 — 精致版本（带光晕 / 内阴影 / 高光）
// 用法：./scripts/make_icon.swift [outDir]
import AppKit

func makeIcon(size: CGFloat) -> NSImage {
    // 用 NSBitmapImageRep 创建严格 size×size 像素的画布（避免 Retina 自动放大）
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    ) else { fatalError("rep") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    // 1. 主背景渐变
    if let grad = NSGradient(colors: [
        NSColor(srgbRed: 0.48, green: 0.78, blue: 1.00, alpha: 1.0),
        NSColor(srgbRed: 0.18, green: 0.42, blue: 0.95, alpha: 1.0),
        NSColor(srgbRed: 0.08, green: 0.22, blue: 0.65, alpha: 1.0)
    ], atLocations: [0.0, 0.55, 1.0], colorSpace: .sRGB) {
        grad.draw(in: rect, angle: -90)
    }

    // 2. 顶部高光
    let highlightRect = NSRect(x: rect.width * 0.10,
                               y: rect.height * 0.55,
                               width: rect.width * 0.80,
                               height: rect.height * 0.40)
    if let hl = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.25),
        NSColor.white.withAlphaComponent(0.0)
    ]) {
        hl.draw(in: NSBezierPath(ovalIn: highlightRect), relativeCenterPosition: NSPoint(x: 0, y: 0))
    }

    // 3. 3x3 圆角格子
    let pad: CGFloat = size * 0.20
    let inner = rect.insetBy(dx: pad, dy: pad)
    let cellGap: CGFloat = inner.width * 0.10
    let cellSize: CGFloat = (inner.width - cellGap * 2) / 3
    let cellRadius: CGFloat = cellSize * 0.26

    for r in 0..<3 {
        for c in 0..<3 {
            let x = inner.minX + CGFloat(c) * (cellSize + cellGap)
            let y = inner.minY + CGFloat(r) * (cellSize + cellGap)
            let cell = NSRect(x: x, y: y, width: cellSize, height: cellSize)
            let p = NSBezierPath(roundedRect: cell, xRadius: cellRadius, yRadius: cellRadius)
            if let g = NSGradient(colors: [
                NSColor.white.withAlphaComponent(0.95),
                NSColor.white.withAlphaComponent(0.78)
            ]) {
                g.draw(in: p, angle: -90)
            }
        }
    }

    // 4. 内描边
    NSColor.white.withAlphaComponent(0.18).setStroke()
    let stroke = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                              xRadius: radius - 1, yRadius: radius - 1)
    stroke.lineWidth = 1
    stroke.stroke()

    let img = NSImage(size: NSSize(width: size, height: size))
    img.addRepresentation(rep)
    return img
}

func writePNG(_ img: NSImage, to path: String) throws {
    // 直接拿 rep（已经是固定像素），不再做二次转换
    guard let rep = img.representations.first as? NSBitmapImageRep,
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: -1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.dropFirst().first
    ?? "LaunchDesk/Resources/Assets.xcassets/AppIcon.appiconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

struct Spec { let name: String; let size: CGFloat }
let specs: [Spec] = [
    .init(name: "icon_16.png",      size: 16),
    .init(name: "icon_16@2x.png",   size: 32),
    .init(name: "icon_32.png",      size: 32),
    .init(name: "icon_32@2x.png",   size: 64),
    .init(name: "icon_128.png",     size: 128),
    .init(name: "icon_128@2x.png",  size: 256),
    .init(name: "icon_256.png",     size: 256),
    .init(name: "icon_256@2x.png",  size: 512),
    .init(name: "icon_512.png",     size: 512),
    .init(name: "icon_512@2x.png",  size: 1024),
]

for s in specs {
    let img = makeIcon(size: s.size)
    let p = (outDir as NSString).appendingPathComponent(s.name)
    try writePNG(img, to: p)
    print("✓ \(s.name) (\(Int(s.size))px)")
}

let contentsJSON = """
{
  "images" : [
    { "filename" : "icon_16.png",      "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",      "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",     "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",     "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",     "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contentsJSON.write(toFile: (outDir as NSString).appendingPathComponent("Contents.json"),
                       atomically: true, encoding: .utf8)
print("✓ Contents.json")
print("Done. Output: \(outDir)")
