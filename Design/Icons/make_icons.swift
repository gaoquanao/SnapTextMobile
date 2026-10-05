import AppKit

// 拾文 App 图标生成器：1024x1024，无透明通道，全出血
final class IconRenderer {
    let size: CGFloat = 1024
    let cg: CGContext

    init() {
        cg = CGContext(
            data: nil, width: 1024, height: 1024,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // AppKit 绘制接口的包装（底部原点坐标系）
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    }

    func save(name: String, to dir: String) {
        NSGraphicsContext.restoreGraphicsState()
        let image = cg.makeImage()!
        let rep = NSBitmapImageRep(cgImage: image)
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: dir + "/" + name))
        print("wrote \(name)")
    }

    func background(_ top: NSColor, _ bottom: NSColor) {
        NSGradient(colors: [top, bottom])!.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
    }

    func radialGlow(center: CGPoint, radius: CGFloat, color: NSColor, peakAlpha: CGFloat) {
        let space = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(
            colorsSpace: space,
            colors: [color.withAlphaComponent(peakAlpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
            locations: [0, 1])!
        cg.saveGState()
        cg.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        cg.restoreGState()
    }

    func glyph(_ text: String, fontCandidates: [String], fontSize: CGFloat, color: NSColor, centerX: CGFloat, centerY: CGFloat, dy: CGFloat = 0) {
        let font = fontCandidates.lazy.compactMap { NSFont(name: $0, size: fontSize) }.first
        guard let font else { fatalError("all fonts missing: \(fontCandidates)") }
        let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let b = str.boundingRect(with: NSSize(width: 2000, height: 2000), options: [.usesLineFragmentOrigin])
        str.draw(at: NSPoint(x: centerX - b.width / 2, y: centerY - b.height / 2 + dy))
    }

    func glyph(_ text: String, fontName: String, fontSize: CGFloat, color: NSColor, centerX: CGFloat, centerY: CGFloat, dy: CGFloat = 0) {
        glyph(text, fontCandidates: [fontName], fontSize: fontSize, color: color, centerX: centerX, centerY: centerY, dy: dy)
    }

    func token(_ rect: CGRect, radius: CGFloat, rotation: CGFloat, color: NSColor) {
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: rotation * .pi / 180)
        let path = NSBezierPath(roundedRect: NSRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height),
                                xRadius: radius, yRadius: radius)
        color.setFill()
        path.fill()
        cg.restoreGState()
    }

    func roundedGradientRect(_ rect: CGRect, radius: CGFloat, top: NSColor, bottom: NSColor) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGradient(colors: [top, bottom])!.draw(in: path, angle: -90)
    }

    func strokeRoundedRect(_ rect: CGRect, radius: CGFloat, width: CGFloat, color: NSColor) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }
}

let outDir = "/Users/gaoquanao/ZCodeProject/Design/Icons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// MARK: - 风格 A：靛蓝渐变 + 白字 + 炸开词块点缀
do {
    let r = IconRenderer()
    r.background(NSColor(red: 0.30, green: 0.30, blue: 0.92, alpha: 1),
                 NSColor(red: 0.45, green: 0.25, blue: 0.88, alpha: 1))
    r.radialGlow(center: CGPoint(x: 512, y: 552), radius: 460, color: .white, peakAlpha: 0.12)
    let faint = NSColor.white.withAlphaComponent(0.10)
    r.token(CGRect(x: 120, y: 700, width: 180, height: 92), radius: 28, rotation: -8, color: faint)
    r.token(CGRect(x: 740, y: 760, width: 150, height: 84), radius: 26, rotation: 7, color: faint)
    r.token(CGRect(x: 90, y: 200, width: 140, height: 84), radius: 26, rotation: 5, color: faint)
    r.token(CGRect(x: 790, y: 170, width: 170, height: 88), radius: 27, rotation: -6, color: faint)
    r.token(CGRect(x: 690, y: 60, width: 96, height: 56), radius: 18, rotation: 4, color: NSColor.white.withAlphaComponent(0.07))
    r.glyph("拾", fontName: "PingFangSC-Semibold", fontSize: 620, color: .white, centerX: 512, centerY: 512, dy: -6)
    r.save(name: "A-indigo.png", to: outDir)
}

// MARK: - 风格 B：印章
func drawSeal(_ r: IconRenderer) {
    let sealRect = CGRect(x: 512 - 300, y: 512 - 300, width: 600, height: 600)
    r.roundedGradientRect(sealRect, radius: 128,
                          top: NSColor(red: 0.91, green: 0.33, blue: 0.28, alpha: 1),
                          bottom: NSColor(red: 0.76, green: 0.18, blue: 0.16, alpha: 1))
    r.strokeRoundedRect(sealRect.insetBy(dx: 44, dy: 44), radius: 96, width: 10,
                        color: NSColor.white.withAlphaComponent(0.55))
    r.glyph("拾", fontName: "PingFangSC-Semibold", fontSize: 380, color: .white, centerX: 512, centerY: 512, dy: -4)
}

do {
    let r = IconRenderer()
    r.background(NSColor(red: 0.965, green: 0.937, blue: 0.878, alpha: 1),
                 NSColor(red: 0.925, green: 0.886, blue: 0.800, alpha: 1))
    drawSeal(r)
    r.save(name: "B-seal-paper.png", to: outDir)
}
do {
    let r = IconRenderer()
    r.background(NSColor(red: 0.086, green: 0.094, blue: 0.125, alpha: 1),
                 NSColor(red: 0.145, green: 0.157, blue: 0.204, alpha: 1))
    r.radialGlow(center: CGPoint(x: 512, y: 512), radius: 500,
                 color: NSColor(red: 0.91, green: 0.33, blue: 0.28, alpha: 1), peakAlpha: 0.10)
    drawSeal(r)
    r.save(name: "B-seal-ink.png", to: outDir)
}

// MARK: - 风格 C：纸上墨字 + 角标小印
do {
    let r = IconRenderer()
    r.background(NSColor(red: 0.965, green: 0.945, blue: 0.898, alpha: 1),
                 NSColor(red: 0.906, green: 0.875, blue: 0.804, alpha: 1))
    r.glyph("拾", fontCandidates: ["STKaitiSC-Bold", "STSongti-SC-Bold", "Songti-SC-Bold", "PingFangSC-Semibold"], fontSize: 640,
            color: NSColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1),
            centerX: 512, centerY: 542, dy: -8)
    r.token(CGRect(x: 700, y: 150, width: 150, height: 150), radius: 34, rotation: 0,
            color: NSColor(red: 0.80, green: 0.25, blue: 0.22, alpha: 1))
    r.glyph("文", fontCandidates: ["STKaitiSC-Bold", "STSongti-SC-Bold", "PingFangSC-Semibold"], fontSize: 96, color: .white, centerX: 775, centerY: 225)
    r.save(name: "C-ink-paper.png", to: outDir)
}

// MARK: - Tinted（iOS 18 染色模式）：灰阶印章
do {
    let r = IconRenderer()
    let gray = NSColor(red: 0.557, green: 0.557, blue: 0.573, alpha: 1)
    r.background(gray, gray)
    let sealRect = CGRect(x: 512 - 300, y: 512 - 300, width: 600, height: 600)
    r.roundedGradientRect(sealRect, radius: 128,
                          top: NSColor(white: 0.96, alpha: 1),
                          bottom: NSColor(white: 0.88, alpha: 1))
    r.strokeRoundedRect(sealRect.insetBy(dx: 44, dy: 44), radius: 96, width: 10,
                        color: gray.withAlphaComponent(0.9))
    r.glyph("拾", fontName: "PingFangSC-Semibold", fontSize: 380, color: gray, centerX: 512, centerY: 512, dy: -4)
    r.save(name: "T-seal-tinted.png", to: outDir)
}
