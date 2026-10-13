import AppKit

/// Funny per-plant fruit/flower variant, derived deterministically from a persisted seed
struct Variant {
    var shape = 0, face = 0, deco = 0, color = 0, rarity = 0   // rarity 0 common, 1 rare, 2 legendary
    let speciesId: String

    init(seed: Int, speciesId: String) {
        self.speciesId = speciesId
        var x = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
        func next() -> Double { x = x &+ 0x9E3779B97F4A7C15; var z = x; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; z ^= z >> 31; return Double(z >> 11) / Double(1 << 53) }
        func pick(_ a: [Int]) -> Int { a[min(a.count - 1, Int(next() * Double(a.count)))] }
        let r = next(); rarity = r < 0.05 ? 2 : r < 0.27 ? 1 : 0
        let shapes: [String: [Int]] = ["tomato": [0, 1, 2, 3, 4, 5, 6], "sunflower": [0, 1, 2, 4], "rose": [0, 1], "lettuce": [7], "basil": [1], "echeveria": [0]]
        let hasFace = ["tomato", "sunflower", "lettuce", "echeveria"].contains(speciesId)
        let canDeco = ["tomato", "sunflower", "lettuce"].contains(speciesId)
        shape = pick(shapes[speciesId] ?? [0])
        if hasFace && next() < 0.65 { face = pick([1, 2, 3]) }
        if speciesId == "tomato" && shape == 0 && face == 0 { shape = pick([1, 2, 3, 6]) }
        switch rarity {
        case 1:
            if canDeco && next() < 0.5 { deco = pick([1, 2]) } else { color = pick(speciesId == "rose" ? [2, 4, 5, 6] : [1, 2, 4, 5, 6]) }
            if speciesId == "echeveria" { deco = 3 }
        case 2:
            color = 3; deco = canDeco ? pick([1, 2, 3]) : (speciesId == "echeveria" ? 3 : 0)
        default: break
        }
    }
    func name(_ species: String) -> String {
        var p: [String] = []
        if face > 0 { p.append(["", "웃는", "깜짝 놀란", "졸린"][face]) }
        if color > 0 { p.append(["", "줄무늬", "무지개", "황금", "파란", "까만", "초록"][color]) }
        if deco > 0 { p.append(["", "콧수염", "선글라스", "왕관"][deco]) }
        if shape > 0 { p.append(speciesId == "sunflower" ? ["", "하트", "소용돌이", "", "꼬마 다둥이"][min(shape, 4)] : ["", "하트", "별", "네모", "꼬마", "왕", "쌍둥이", "뽀글머리"][shape]) }
        if p.isEmpty { p.append("평범한") }
        return (p.filter { !$0.isEmpty } + [species]).joined(separator: " ") + ["", " ✨희귀", " 🌟전설"][rarity]
    }

    // MARK: drawing helpers
    static func heart(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath {
        let p = NSBezierPath(); p.move(to: NSPoint(x: c.x, y: c.y - r))
        p.curve(to: NSPoint(x: c.x, y: c.y + r*0.45), controlPoint1: NSPoint(x: c.x - r*1.5, y: c.y - r*0.1), controlPoint2: NSPoint(x: c.x - r*0.7, y: c.y + r*1.25))
        p.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x + r*0.7, y: c.y + r*1.25), controlPoint2: NSPoint(x: c.x + r*1.5, y: c.y - r*0.1)); p.close(); return p
    }
    static func star(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        for i in 0..<10 { let a = CGFloat(i) * .pi / 5 + .pi/2, rr = i % 2 == 0 ? r * 1.15 : r * 0.55; let pt = NSPoint(x: c.x + cos(a)*rr, y: c.y + sin(a)*rr); i == 0 ? p.move(to: pt) : p.line(to: pt) }
        p.close(); p.lineJoinStyle = .round; return p
    }
    func bodyPath(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath {
        switch shape {
        case 1: return Variant.heart(c, r)
        case 2: return Variant.star(c, r)
        case 3: return NSBezierPath(roundedRect: NSRect(x: c.x - r*0.9, y: c.y - r*0.9, width: r*1.8, height: r*1.8), xRadius: r*0.3, yRadius: r*0.3)
        case 6: let p = NSBezierPath(ovalIn: NSRect(x: c.x - r*1.25, y: c.y - r*0.8, width: r*1.6, height: r*1.6)); p.append(NSBezierPath(ovalIn: NSRect(x: c.x - r*0.35, y: c.y - r*0.8, width: r*1.6, height: r*1.6))); return p
        default: return NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2*r, height: 2*r))
        }
    }
    static let rainbow: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
    func tint(_ base: NSColor) -> NSColor {
        switch color { case 3: return NSColor(calibratedRed: 1, green: 0.8, blue: 0.25, alpha: 1); case 4: return NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 1)
        case 5: return NSColor(calibratedRed: 0.2, green: 0.17, blue: 0.22, alpha: 1); case 6: return NSColor(calibratedRed: 0.45, green: 0.78, blue: 0.35, alpha: 1); default: return base }
    }
    /// Fill a shape with this variant's color treatment
    func fill(_ path: NSBezierPath, _ base: NSColor, _ bounds: NSRect, t: CGFloat = 0) {
        tint(base).setFill(); path.fill()
        guard color == 1 || color == 2 || color == 3 else { return }
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        if color == 1 { NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 0.85).setFill(); var y = bounds.minY; while y < bounds.maxY { NSRect(x: bounds.minX, y: y, width: bounds.width, height: bounds.height/8).fill(); y += bounds.height/4 } }
        if color == 2 { let h = bounds.height / 6; for (i, c) in Variant.rainbow.enumerated() { c.setFill(); NSRect(x: bounds.minX, y: bounds.maxY - h*CGFloat(i+1), width: bounds.width, height: h + 0.5).fill() } }
        if color == 3 { NSColor(white: 1, alpha: 0.55).setFill(); NSBezierPath(ovalIn: NSRect(x: bounds.minX + bounds.width*0.2, y: bounds.midY, width: bounds.width*0.25, height: bounds.height*0.3)).fill() }
        NSGraphicsContext.restoreGraphicsState()
        if color == 3 { NSColor(calibratedRed: 1, green: 1, blue: 0.8, alpha: 0.6 + 0.4*abs(sin(t*3))).setFill(); Variant.star(NSPoint(x: bounds.maxX, y: bounds.maxY), bounds.width*0.14).fill() }
    }
    func drawFace(_ c: NSPoint, _ r: CGFloat) {
        let ink = NSColor(white: 0.12, alpha: 0.9); ink.setFill(); ink.setStroke()
        let ex = r*0.38, ey = c.y + r*0.15, es = max(1.6, r*0.22)
        if deco != 2 {
            if face == 3 { for s in [-1.0, 1.0] as [CGFloat] { let p = NSBezierPath(); p.move(to: NSPoint(x: c.x + s*ex - es*0.7, y: ey)); p.line(to: NSPoint(x: c.x + s*ex + es*0.7, y: ey)); p.lineWidth = max(0.8, r*0.1); p.lineCapStyle = .round; p.stroke() } }
            else if face > 0 || deco > 0 { for s in [-1.0, 1.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: c.x + s*ex - es/2, y: ey - es/2, width: es, height: face == 2 ? es*1.3 : es)).fill() } }
        }
        let my = c.y - r*0.3
        switch face {
        case 1: let m = NSBezierPath(); m.move(to: NSPoint(x: c.x - r*0.3, y: my + r*0.05)); m.curve(to: NSPoint(x: c.x + r*0.3, y: my + r*0.05), controlPoint1: NSPoint(x: c.x - r*0.15, y: my - r*0.25), controlPoint2: NSPoint(x: c.x + r*0.15, y: my - r*0.25)); m.lineWidth = max(0.8, r*0.1); m.lineCapStyle = .round; m.stroke()
        case 2: NSBezierPath(ovalIn: NSRect(x: c.x - r*0.13, y: my - r*0.18, width: r*0.26, height: r*0.32)).fill()
        case 3: let m = NSBezierPath(); m.move(to: NSPoint(x: c.x - r*0.15, y: my)); m.line(to: NSPoint(x: c.x + r*0.15, y: my)); m.lineWidth = max(0.8, r*0.1); m.stroke()
            NSColor(white: 1, alpha: 0.9).setFill(); NSFont.systemFont(ofSize: r*0.7).ascender > 0 ? ("z" as NSString).draw(at: NSPoint(x: c.x + r*0.7, y: c.y + r*0.6), withAttributes: [.font: NSFont.boldSystemFont(ofSize: max(5, r*0.7)), .foregroundColor: NSColor(white: 1, alpha: 0.9)]) : ()
        default: break
        }
        switch deco {
        case 1: ink.setFill(); for s in [-1.0, 1.0] as [CGFloat] { let m = NSBezierPath(); let y = c.y - r*0.12
            m.move(to: NSPoint(x: c.x, y: y)); m.curve(to: NSPoint(x: c.x + s*r*0.62, y: y + r*0.05), controlPoint1: NSPoint(x: c.x + s*r*0.2, y: y - r*0.22), controlPoint2: NSPoint(x: c.x + s*r*0.5, y: y - r*0.2))
            m.curve(to: NSPoint(x: c.x, y: y), controlPoint1: NSPoint(x: c.x + s*r*0.45, y: y - r*0.05), controlPoint2: NSPoint(x: c.x + s*r*0.2, y: y + r*0.05)); m.fill() }
        case 2: ink.setFill(); for s in [-1.0, 1.0] as [CGFloat] { NSBezierPath(roundedRect: NSRect(x: c.x + s*ex - r*0.28, y: ey - r*0.2, width: r*0.56, height: r*0.36), xRadius: r*0.12, yRadius: r*0.12).fill() }
            let b = NSBezierPath(); b.move(to: NSPoint(x: c.x - ex + r*0.2, y: ey)); b.line(to: NSPoint(x: c.x + ex - r*0.2, y: ey)); b.lineWidth = max(0.7, r*0.08); ink.setStroke(); b.stroke()
            NSColor(white: 1, alpha: 0.5).setFill(); NSRect(x: c.x - ex - r*0.15, y: ey + r*0.02, width: r*0.12, height: r*0.08).fill()
        case 3: drawCrown(NSPoint(x: c.x, y: c.y + r*0.95), r*0.75)
        default: break
        }
    }
    func drawCrown(_ c: NSPoint, _ w: CGFloat) {
        let p = NSBezierPath(); p.move(to: NSPoint(x: c.x - w/2, y: c.y)); p.line(to: NSPoint(x: c.x - w/2, y: c.y + w*0.55)); p.line(to: NSPoint(x: c.x - w/4, y: c.y + w*0.25))
        p.line(to: NSPoint(x: c.x, y: c.y + w*0.65)); p.line(to: NSPoint(x: c.x + w/4, y: c.y + w*0.25)); p.line(to: NSPoint(x: c.x + w/2, y: c.y + w*0.55)); p.line(to: NSPoint(x: c.x + w/2, y: c.y)); p.close()
        NSColor(calibratedRed: 1, green: 0.8, blue: 0.2, alpha: 1).setFill(); p.fill()
        NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.35, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - w*0.08, y: c.y + w*0.1, width: w*0.16, height: w*0.16)).fill()
    }

    /// Draw the bloom / fruit for the plant at the stem tip
    func drawBloom(tip: NSPoint, t: CGFloat) {
        switch speciesId {
        case "tomato":
            let spots: [(CGFloat, CGFloat)] = shape == 5 ? [(0, -22)] : shape == 4 ? [(-12, -16), (10, -26), (-6, -36), (8, -10), (-14, -28), (2, -46)] : [(-13, -18), (12, -30), (-6, -42)]
            let r: CGFloat = shape == 5 ? 15 : shape == 4 ? 4.5 : 8
            for (dx, dy) in spots { let c = NSPoint(x: tip.x + dx, y: tip.y + dy)
                NSColor(calibratedRed: 0.3, green: 0.6, blue: 0.3, alpha: 1).setStroke(); let st = NSBezierPath(); st.move(to: NSPoint(x: c.x, y: c.y + r)); st.line(to: NSPoint(x: tip.x + dx*0.3, y: tip.y + dy*0.3 + 8)); st.lineWidth = 1.2; st.stroke()
                let body = bodyPath(c, r); fill(body, NSColor(calibratedRed: 0.92, green: 0.25, blue: 0.2, alpha: 1), body.bounds, t: t)
                NSColor(calibratedRed: 0.3, green: 0.62, blue: 0.3, alpha: 1).setFill(); Variant.star(NSPoint(x: c.x, y: c.y + r*0.9), r*0.32).fill()
                if r >= 6 { drawFace(c, r) } }
        case "sunflower":
            let heads: [(CGFloat, CGFloat, CGFloat)] = shape == 4 ? [(0, 0, 0.55), (-16, -12, 0.45), (15, -10, 0.45)] : [(0, 0, 1)]
            for (dx, dy, k) in heads { let c = NSPoint(x: tip.x + dx, y: tip.y + dy)
                for i in 0..<14 { let a = CGFloat(i) * .pi / 7 + t*0.05
                    let pc: NSColor = color == 2 ? Variant.rainbow[i % 6] : tint(NSColor(calibratedRed: 1, green: 0.78, blue: 0.2, alpha: 1))
                    pc.setFill(); let pp = NSBezierPath(ovalIn: NSRect(x: -4*k, y: 6*k, width: 8*k, height: 12*k)); let tf = NSAffineTransform(); tf.translateX(by: c.x, yBy: c.y); tf.rotate(byRadians: a); pp.transform(using: tf as AffineTransform); pp.fill() }
                let disk = shape == 1 ? Variant.heart(c, 11*k) : NSBezierPath(ovalIn: NSRect(x: c.x - 10*k, y: c.y - 10*k, width: 20*k, height: 20*k))
                NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.15, alpha: 1).setFill(); disk.fill()
                if shape == 2 { NSColor(calibratedRed: 0.75, green: 0.55, blue: 0.25, alpha: 1).setStroke(); let sp = NSBezierPath(); var a: CGFloat = 0; sp.move(to: c)
                    while a < 4 * .pi { a += 0.3; let rr = a / (4 * .pi) * 9 * k; sp.line(to: NSPoint(x: c.x + cos(a - t)*rr, y: c.y + sin(a - t)*rr)) }; sp.lineWidth = 1.2; sp.stroke() }
                if k > 0.9 || dx == 0 { drawFace(c, 9*k) } }
        case "rose":
            let base = NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.42, alpha: 1)
            for i in 0..<6 { let a = CGFloat(i) * .pi / 3 + t*0.05, pc = NSPoint(x: tip.x + cos(a)*6, y: tip.y + sin(a)*6)
                let col = color == 2 ? Variant.rainbow[i] : tint(base); col.setFill()
                (shape == 1 ? Variant.heart(pc, 6.5) : NSBezierPath(ovalIn: NSRect(x: pc.x - 6.5, y: pc.y - 6.5, width: 13, height: 13))).fill() }
            (tint(base).blended(withFraction: 0.3, of: .black) ?? base).setFill(); NSBezierPath(ovalIn: NSRect(x: tip.x - 4.5, y: tip.y - 4.5, width: 9, height: 9)).fill()
            if color == 3 { fill(NSBezierPath(ovalIn: NSRect(x: tip.x - 4.5, y: tip.y - 4.5, width: 9, height: 9)), base, NSRect(x: tip.x - 12, y: tip.y - 12, width: 24, height: 24), t: t) }
        case "basil":
            for (i, (dx, dy)) in [(-9.0, -4.0), (9.0, -6.0), (-6.0, 8.0), (7.0, 6.0)].enumerated() { let c = NSPoint(x: tip.x + CGFloat(dx), y: tip.y + CGFloat(dy))
                let h = Variant.heart(c, 6); fill(h, NSColor(calibratedRed: 0.35, green: 0.68, blue: 0.3, alpha: 1), h.bounds, t: t + CGFloat(i)) }
            NSColor.white.setFill(); for k in 0..<4 { NSBezierPath(ovalIn: NSRect(x: tip.x - 2, y: tip.y + 12 + CGFloat(k)*4, width: 4, height: 4)).fill() }
        case "lettuce":
            for i in 0..<16 { let a = CGFloat(i) * .pi / 8, rr: CGFloat = 17 + 3*sin(CGFloat(i)*2.3 + t)
                let c = NSPoint(x: tip.x + cos(a)*rr, y: tip.y + 6 + sin(a)*rr*0.8)
                (color == 2 ? Variant.rainbow[i % 6] : tint(NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.4, alpha: 1)).blended(withFraction: CGFloat(i % 3) * 0.12, of: .white)!).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - 7, y: c.y - 6, width: 14, height: 12)).fill() }
            let c = NSPoint(x: tip.x, y: tip.y + 6); let b = NSBezierPath(ovalIn: NSRect(x: c.x - 13, y: c.y - 11, width: 26, height: 22))
            fill(b, NSColor(calibratedRed: 0.62, green: 0.86, blue: 0.48, alpha: 1), b.bounds, t: t); drawFace(c, 10)
        case "echeveria":
            if face > 0 { drawFace(NSPoint(x: tip.x, y: tip.y), 7) }
            if deco == 3 { drawCrown(NSPoint(x: tip.x, y: tip.y + 8), 16) }
        default: break
        }
    }
}
