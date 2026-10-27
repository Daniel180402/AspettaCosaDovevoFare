// Genera le immagini di AppIcon.appiconset disegnandole in vettoriale a ogni dimensione.
// Uso: swift Support/MakeAppIcon.swift <cartella AppIcon.appiconset>
import AppKit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let fare = rgb(0x3550D6)
let fareDeep = rgb(0x1F2C8F)
let fareLight = rgb(0x6F86FF)
let attesa = rgb(0xE3A73A)
let attesaDeep = rgb(0xC8860E)
let ink = rgb(0x1C2340)

/// Disegna l'icona in uno spazio di 1024 punti (griglia delle icone macOS: forma di 824 con margine 100).
func drawIcon(in ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Forma di base con ombra.
    let base = CGRect(x: 100, y: 100, width: 824, height: 824)
    let basePath = CGPath(roundedRect: base, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(basePath)
    ctx.setFillColor(fare)
    ctx.fillPath()
    ctx.restoreGState()

    // Sfondo: gradiente blu in diagonale più un alone chiaro in alto.
    ctx.saveGState()
    ctx.addPath(basePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [fareLight, fare, fareDeep] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 180, y: 924), end: CGPoint(x: 844, y: 100), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 860), startRadius: 0,
                           endCenter: CGPoint(x: 330, y: 860), endRadius: 560, options: [])
    ctx.restoreGState()

    // Scheda bianca leggermente ruotata.
    ctx.saveGState()
    ctx.translateBy(x: 488, y: 478)
    ctx.rotate(by: 5 * .pi / 180)
    let card = CGRect(x: -250, y: -285, width: 500, height: 570)
    let cardPath = CGPath(roundedRect: card, cornerWidth: 64, cornerHeight: 64, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x0B1250, 0.45))
    ctx.addPath(cardPath)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(cardPath)
    ctx.clip()
    let paper = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF), rgb(0xEEF1FB)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(paper, start: CGPoint(x: 0, y: 285), end: CGPoint(x: 0, y: -285), options: [])

    // Righe: fatto (blu), in attesa (ambra), da fare (vuota).
    let rowY: [CGFloat] = [150, 0, -150]
    let markX: CGFloat = -150
    let r: CGFloat = 46

    // 1. Spunta piena.
    ctx.setFillColor(fare)
    ctx.fillEllipse(in: CGRect(x: markX - r, y: rowY[0] - r, width: 2 * r, height: 2 * r))
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(15)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: markX - 20, y: rowY[0] + 1))
    ctx.addLine(to: CGPoint(x: markX - 4, y: rowY[0] - 16))
    ctx.addLine(to: CGPoint(x: markX + 22, y: rowY[0] + 16))
    ctx.strokePath()

    // 2. Orologio ambra: aspetto da altri.
    ctx.setFillColor(attesa)
    ctx.fillEllipse(in: CGRect(x: markX - r, y: rowY[1] - r, width: 2 * r, height: 2 * r))
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(12)
    ctx.move(to: CGPoint(x: markX, y: rowY[1] + 24))
    ctx.addLine(to: CGPoint(x: markX, y: rowY[1]))
    ctx.addLine(to: CGPoint(x: markX + 18, y: rowY[1] - 12))
    ctx.strokePath()

    // 3. Cerchio vuoto.
    ctx.setStrokeColor(rgb(0xB9C1DE))
    ctx.setLineWidth(11)
    ctx.strokeEllipse(in: CGRect(x: markX - r + 6, y: rowY[2] - r + 6, width: 2 * r - 12, height: 2 * r - 12))

    // Linee di testo.
    let lineX = markX + r + 34
    let lines: [(CGFloat, CGFloat, CGColor)] = [
        (rowY[0], 230, rgb(0xC9D0EA)),
        (rowY[1], 260, ink.copy(alpha: 0.85)!),
        (rowY[2], 190, rgb(0xC9D0EA)),
    ]
    for (y, width, color) in lines {
        let bar = CGRect(x: lineX, y: y - 14, width: width, height: 28)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
    }
    ctx.restoreGState()

    // Badge "?" in alto a destra.
    let center = CGPoint(x: 735, y: 735)
    let badgeR: CGFloat = 132
    let badge = CGRect(x: center.x - badgeR, y: center.y - badgeR, width: 2 * badgeR, height: 2 * badgeR)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: rgb(0x0B1250, 0.45))
    ctx.setFillColor(attesa)
    ctx.fillEllipse(in: badge)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addEllipse(in: badge)
    ctx.clip()
    let amber = CGGradient(colorsSpace: space, colors: [rgb(0xF6C35E), attesa, attesaDeep] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(amber, start: CGPoint(x: center.x - 80, y: center.y + badgeR),
                           end: CGPoint(x: center.x + 80, y: center.y - badgeR), options: [])
    ctx.restoreGState()
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(14)
    ctx.strokeEllipse(in: badge.insetBy(dx: 7, dy: 7))

    let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 190, weight: .black)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 190) ?? base
    }()
    let text = NSAttributedString(string: "?", attributes: [.font: font, .foregroundColor: NSColor.white])
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, ctx)
}

func render(pixels: Int) -> Data {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Icona scritta in \(output.path)")
