import AppKit

/// 🪼 Desktop jellyfish pet: swims behind all app windows, click-through except on the jelly itself
struct JellyState: Codable {
    var name: String? = nil
    var adopted = false
    var born = Date().timeIntervalSince1970
    var growth = 0.0          // "good care" days
    var fullness = 0.7
    var happiness = 0.7
    var lastUpdate = Date().timeIntervalSince1970
    var fed = 0
}
let jellyURL = appSupportDir.appendingPathComponent("jelly.json")

final class Jelly {
    var st = JellyState()
    init() { if let d = try? Data(contentsOf: jellyURL), let s = try? JSONDecoder().decode(JellyState.self, from: d) { st = s } }
    func save() { if let d = try? JSONEncoder().encode(st) { try? d.write(to: jellyURL) } }
    /// Needs decay over real time; growth only with decent care. No death: a neglected jelly just gets dim and sad.
    func advance(days: Double) {
        guard days > 0 else { return }
        st.fullness = max(0, st.fullness - days / 1.5)
        st.happiness = max(0, st.happiness - days / (st.fullness < 0.25 ? 1.0 : 2.2))
        let good = st.fullness > 0.3 && st.happiness > 0.3
        st.growth += days * (good ? 1 : 0.1)
    }
    func catchUp() { let now = Date().timeIntervalSince1970; advance(days: (now - st.lastUpdate) / 86400); st.lastUpdate = now; save() }
    var stage: Int { st.growth < 1 ? 0 : st.growth < 3 ? 1 : st.growth < 7 ? 2 : 3 }
    static let stageNames = ["아기", "꼬마", "어른", "왕"]
    var scale: CGFloat {
        let g = st.growth, pts: [(Double, Double)] = [(0, 0.5), (1, 0.62), (3, 0.82), (7, 1.0), (14, 1.3)]
        for i in 1..<pts.count where g < pts[i].0 { let a = pts[i-1], b = pts[i]; return CGFloat(a.1 + (b.1 - a.1) * (g - a.0) / (b.0 - a.0)) }
        return 1.3
    }
    var mood: Double { min(1, st.fullness * 1.4) * 0.5 + st.happiness * 0.5 }
    var name: String { st.name ?? "말랑이" }
    var days: Int { Int((Date().timeIntervalSince1970 - st.born) / 86400) + 1 }
}

struct Food { var p: CGPoint; var v: CGFloat; var age: CGFloat; var seed: CGFloat }
struct Sparkle { var p: CGPoint; var life: CGFloat; var heart: Bool }

final class JellyView: NSView {
    let model: Jelly
    var pos = CGPoint(x: 500, y: 400), vel = CGVector(dx: 0, dy: 0)
    var heading: CGFloat = .pi / 2
    var phase: CGFloat = 0, t: CGFloat = 0, contract: CGFloat = 0
    var target = CGPoint(x: 500, y: 500), nextWander: CGFloat = 0
    var tentacles: [[CGPoint]] = [], arms: [[CGPoint]] = []
    var food: [Food] = []
    var pet: CGFloat = 0, eatGlow: CGFloat = 0
    var sparkles: [Sparkle] = []
    var swimRect: NSRect = .zero            // where the jelly may roam (view coords)
    var onClick: ((NSEvent) -> Void)?
    var lastDirty: [NSRect] = []
    init(frame: NSRect, model: Jelly) { self.model = model; super.init(frame: frame); swimRect = bounds; pos = CGPoint(x: bounds.midX, y: bounds.midY); target = pos; resetChains() }
    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }

    var R: CGFloat { 44 * model.scale }
    var dir: CGVector { CGVector(dx: cos(heading), dy: sin(heading)) }
    /// bell rim point in world coords for local x (−1…1 of half-width) at the bell base
    func rimPoint(_ fx: CGFloat) -> CGPoint {
        let w = R * (1 + 0.14 * contract), px = CGVector(dx: dir.dy, dy: -dir.dx)   // perpendicular (right side)
        return CGPoint(x: pos.x + px.dx * fx * w * 0.82 - dir.dx * R * 0.05, y: pos.y + px.dy * fx * w * 0.82 - dir.dy * R * 0.05)
    }
    func resetChains() {
        tentacles = (0..<7).map { k in let a = rimPoint(-1 + 2 * CGFloat(k) / 6); return (0..<16).map { i in CGPoint(x: a.x - dir.dx * CGFloat(i) * 6, y: a.y - dir.dy * CGFloat(i) * 6) } }
        arms = (0..<3).map { k in let a = rimPoint(-0.3 + 0.3 * CGFloat(k)); return (0..<9).map { i in CGPoint(x: a.x - dir.dx * CGFloat(i) * 6, y: a.y - dir.dy * CGFloat(i) * 6) } }
    }
    func feed(at x: CGFloat? = nil) {
        let cx = x ?? pos.x
        for _ in 0..<11 { let fx = min(max(cx + .random(in: -160...160), swimRect.minX + 30), swimRect.maxX - 30)
            food.append(Food(p: CGPoint(x: fx, y: min(swimRect.maxY - 10, pos.y + .random(in: 160...300))), v: .random(in: 14...24), age: 0, seed: .random(in: 0...10))) }
    }
    func nearestFood() -> Int? { food.indices.min { hypot(food[$0].p.x - pos.x, food[$0].p.y - pos.y) < hypot(food[$1].p.x - pos.x, food[$1].p.y - pos.y) } }

    func step(_ dt: CGFloat) {
        t += dt
        let s = model.scale, mood = CGFloat(model.mood)
        // food sinks and wiggles
        for i in food.indices { food[i].age += dt; food[i].p.y -= food[i].v * dt; food[i].p.x += sin(t * 1.7 + food[i].seed) * 6 * dt }
        food.removeAll { $0.p.y < swimRect.minY + 6 && $0.age > 40 || $0.age > 120 }
        for i in food.indices where food[i].p.y < swimRect.minY + 6 { food[i].p.y = swimRect.minY + 6; food[i].v = 0 }
        let chasing: Bool
        if let fi = nearestFood() { target = food[fi].p; chasing = true
            if hypot(food[fi].p.x - pos.x, food[fi].p.y - pos.y) < R * 0.95 { food.remove(at: fi); eat() } }
        else { chasing = false
            if t > nextWander || hypot(target.x - pos.x, target.y - pos.y) < 60 {
                let m = R * 2.2; target = CGPoint(x: .random(in: (swimRect.minX + m)...max(swimRect.minX + m + 1, swimRect.maxX - m)), y: .random(in: (swimRect.minY + m)...max(swimRect.minY + m + 1, swimRect.maxY - m)))
                nextWander = t + .random(in: 9...18) } }
        // gentle turning toward the target
        var d = atan2(target.y - pos.y, target.x - pos.x) - heading
        while d > .pi { d -= 2 * .pi }; while d < -.pi { d += 2 * .pi }
        let turn: CGFloat = chasing ? 1.1 : 0.45
        heading += max(-turn * dt, min(turn * dt, d)) + sin(t * 0.7) * 0.05 * dt
        // bell pulse → thrust (slower and weaker when sad)
        let rate: CGFloat = (chasing ? 1.05 : 0.62) * (0.65 + 0.35 * mood) * (1.15 - 0.15 * s)
        phase += 2 * .pi * rate * dt
        contract = pow(max(0, sin(phase)), 2)
        let thrust = contract * 85 * sqrt(s) * (chasing ? 1.6 : 1) * (0.6 + 0.4 * mood)
        vel.dx += dir.dx * thrust * dt; vel.dy += dir.dy * thrust * dt
        let drag = pow(0.33, dt); vel.dx *= drag; vel.dy *= drag
        vel.dy -= 5 * dt * (1 - contract)                                  // drifts down while relaxing
        // soft edge avoidance
        let m = R * 1.6
        if pos.x < swimRect.minX + m { vel.dx += (swimRect.minX + m - pos.x) * 1.2 * dt }
        if pos.x > swimRect.maxX - m { vel.dx -= (pos.x - swimRect.maxX + m) * 1.2 * dt }
        if pos.y < swimRect.minY + m { vel.dy += (swimRect.minY + m - pos.y) * 1.2 * dt }
        if pos.y > swimRect.maxY - m { vel.dy -= (pos.y - swimRect.maxY + m) * 1.2 * dt }
        pos.x += vel.dx * dt; pos.y += vel.dy * dt
        // tentacle physics: follow-the-leader rope with water drag and sway
        func rope(_ c: inout [CGPoint], anchor: CGPoint, seg: CGFloat, k: Int, sway: CGFloat) {
            c[0] = anchor; let perp = CGVector(dx: dir.dy, dy: -dir.dx)
            for i in 1..<c.count {
                let w = sin(t * 2.1 - CGFloat(i) * 0.45 + CGFloat(k) * 1.3) * sway * CGFloat(i) / CGFloat(c.count)
                var p = c[i]; p.x += (-dir.dx * 10 + perp.dx * w * 8) * dt; p.y += (-dir.dy * 10 + perp.dy * w * 8 - 6) * dt
                let dx = p.x - c[i-1].x, dy = p.y - c[i-1].y, l = max(0.001, hypot(dx, dy))
                c[i] = CGPoint(x: c[i-1].x + dx / l * seg, y: c[i-1].y + dy / l * seg) }
        }
        for k in tentacles.indices { rope(&tentacles[k], anchor: rimPoint(-1 + 2 * CGFloat(k) / CGFloat(tentacles.count - 1)), seg: 6.5 * s * (1 + CGFloat(k % 2) * 0.25), k: k, sway: 1.6) }
        for k in arms.indices { rope(&arms[k], anchor: rimPoint(-0.25 + 0.25 * CGFloat(k)), seg: 6 * s, k: k + 9, sway: 2.4) }
        // petting & effects
        pet = max(0, pet - dt * 0.35); eatGlow = max(0, eatGlow - dt * 0.8)
        for i in sparkles.indices { sparkles[i].life -= dt * 0.8; sparkles[i].p.y += 18 * dt; sparkles[i].p.x += sin(t * 3 + CGFloat(i)) * 6 * dt }
        sparkles.removeAll { $0.life <= 0 }
    }
    func eat() {
        model.st.fullness = min(1, model.st.fullness + 0.09); model.st.happiness = min(1, model.st.happiness + 0.02); model.st.fed += 1; eatGlow = 1
        for _ in 0..<3 { sparkles.append(Sparkle(p: CGPoint(x: pos.x + .random(in: -R...R) * 0.5, y: pos.y + R * 0.8), life: 1, heart: false)) }
    }
    func petted(_ dt: CGFloat) {
        pet = min(1, pet + dt * 1.6)
        model.st.happiness = min(1, model.st.happiness + Double(dt) * 0.03)
        if CGFloat.random(in: 0...1) < dt * 6 { sparkles.append(Sparkle(p: CGPoint(x: pos.x + .random(in: -R...R), y: pos.y + .random(in: 0...R * 1.2)), life: 1, heart: CGFloat.random(in: 0...1) < 0.35)) }
    }
    func hitTestJelly(_ p: CGPoint) -> Bool { hypot(p.x - (pos.x + dir.dx * R * 0.5), p.y - (pos.y + dir.dy * R * 0.5)) < R * 1.05 }

    /// Dirty regions: jelly + tentacles, food, sparkles (keeps redraw cost low on a full-screen view)
    func invalidate() {
        var rs: [NSRect] = []
        var minX = pos.x, maxX = pos.x, minY = pos.y, maxY = pos.y
        for c in tentacles + arms { for p in c { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) } }
        let bell = NSRect(x: pos.x - R * 1.8, y: pos.y - R * 1.8, width: R * 3.6, height: R * 3.6)
        rs.append(NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).union(bell).insetBy(dx: -34, dy: -34))
        for f in food { rs.append(NSRect(x: f.p.x - 10, y: f.p.y - 10, width: 20, height: 26)) }
        for sp in sparkles { rs.append(NSRect(x: sp.p.x - 10, y: sp.p.y - 12, width: 20, height: 24)) }
        for r in rs + lastDirty { setNeedsDisplay(r) }
        lastDirty = rs
    }

    // MARK: drawing
    func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
    var tint: NSColor {
        let mood = CGFloat(model.mood), base = col(0.62, 0.72, 1), warm = col(1, 0.66, 0.84)
        var c = base.blended(withFraction: min(1, pet * 0.8 + CGFloat(model.st.happiness) * 0.25), of: warm) ?? base
        if mood < 0.45 { c = c.blended(withFraction: (0.45 - mood) * 1.6, of: col(0.6, 0.62, 0.7)) ?? c }
        return c
    }
    override func draw(_ dirty: NSRect) {
        NSColor.clear.set(); dirty.fill(using: .copy)
        let mood = CGFloat(model.mood), dim = 0.55 + 0.45 * min(1, mood * 1.6), tc = tint
        // food
        for f in food { let a = min(1, f.age * 2) * (f.age > 100 ? (120 - f.age) / 20 : 1)
            withShadow(col(0.9, 1, 0.7, a), blur: 6) { col(0.95, 1, 0.75, a).setFill(); NSBezierPath(ovalIn: NSRect(x: f.p.x - 2.6, y: f.p.y - 2.6, width: 5.2, height: 5.2)).fill() } }
        // tentacles behind the bell
        func strokeChain(_ c: [CGPoint], width w0: CGFloat, alpha: CGFloat, color: NSColor) {
            for i in 1..<c.count { let p = NSBezierPath(); p.move(to: c[i-1]); p.line(to: c[i]); p.lineCapStyle = .round
                p.lineWidth = max(0.6, w0 * (1 - CGFloat(i) / CGFloat(c.count)) + 0.6); color.withAlphaComponent(alpha * (1 - 0.6 * CGFloat(i) / CGFloat(c.count))).setStroke(); p.stroke() } }
        let s = model.scale
        for c in tentacles { strokeChain(c, width: 2 * s, alpha: 0.55 * dim, color: tc.blended(withFraction: 0.3, of: .white)!) }
        for c in arms { strokeChain(c, width: 6 * s, alpha: 0.32 * dim, color: tc.blended(withFraction: 0.15, of: col(1, 0.6, 0.85))!) }
        // bell
        NSGraphicsContext.saveGraphicsState()
        let tr = NSAffineTransform(); tr.translateX(by: pos.x, yBy: pos.y); tr.rotate(byRadians: heading - .pi / 2); tr.concat()
        let w = R * 2 * (1 + 0.14 * contract), h = R * 1.3 * (1 - 0.12 * contract)
        let bell = NSBezierPath(); bell.move(to: NSPoint(x: -w/2, y: 0))
        bell.curve(to: NSPoint(x: 0, y: h), controlPoint1: NSPoint(x: -w/2, y: h * 0.78), controlPoint2: NSPoint(x: -w * 0.3, y: h))
        bell.curve(to: NSPoint(x: w/2, y: 0), controlPoint1: NSPoint(x: w * 0.3, y: h), controlPoint2: NSPoint(x: w/2, y: h * 0.78))
        // scalloped rim
        let n = 8; for i in 0..<n { let x0 = w/2 - w * CGFloat(i) / CGFloat(n), x1 = w/2 - w * CGFloat(i + 1) / CGFloat(n)
            bell.curve(to: NSPoint(x: x1, y: 0), controlPoint1: NSPoint(x: x0 - w/CGFloat(n) * 0.2, y: -R * 0.1), controlPoint2: NSPoint(x: x1 + w/CGFloat(n) * 0.2, y: -R * 0.1)) }
        bell.close()
        let glowA = (0.55 + 0.3 * pet + 0.4 * eatGlow) * dim
        withShadow(tc.withAlphaComponent(glowA), blur: 26 * s + 10 * pet) { tc.withAlphaComponent(0.22 * dim).setFill(); bell.fill() }
        NSGradient(colors: [NSColor(white: 1, alpha: 0.6 * dim), tc.withAlphaComponent(0.42 * dim), tc.withAlphaComponent(0.16 * dim)], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: bell, relativeCenterPosition: NSPoint(x: -0.25, y: 0.45))
        // inner petals (gonads)
        for k in 0..<4 { let a = CGFloat(k) * .pi / 2 + .pi / 4; let pc = NSPoint(x: cos(a) * w * 0.12, y: h * 0.42 + sin(a) * h * 0.1)
            col(1, 0.75, 0.9, 0.3 * dim).setFill(); NSBezierPath(ovalIn: NSRect(x: pc.x - w * 0.07, y: pc.y - h * 0.06, width: w * 0.14, height: h * 0.12)).fill() }
        NSColor(white: 1, alpha: 0.55 * dim).setStroke(); bell.lineWidth = 1.1; bell.stroke()
        let hl = NSBezierPath(ovalIn: NSRect(x: -w * 0.3, y: h * 0.55, width: w * 0.2, height: h * 0.22)); NSColor(white: 1, alpha: 0.55).setFill(); hl.fill()
        NSColor(white: 1, alpha: 0.8).setFill(); NSBezierPath(ovalIn: NSRect(x: -w * 0.12, y: h * 0.82, width: w * 0.06, height: h * 0.05)).fill()
        // face (kept upright-ish relative to bell)
        let fy = h * 0.36, ink = col(0.22, 0.2, 0.36, 0.85 * dim + 0.1), sad = mood < 0.35, happy = pet > 0.2 || mood > 0.75
        ink.setFill(); ink.setStroke()
        let blink = Int(t * 10) % 47 == 0
        for sx in [-1.0, 1.0] as [CGFloat] {
            let ex = sx * w * 0.14
            if happy && pet > 0.3 { let a = NSBezierPath(); a.appendArc(withCenter: NSPoint(x: ex, y: fy), radius: R * 0.07, startAngle: 20, endAngle: 160); a.lineWidth = max(1, R * 0.035); a.lineCapStyle = .round; a.stroke() }
            else { NSBezierPath(ovalIn: NSRect(x: ex - R * 0.05, y: fy - R * 0.06, width: R * 0.1, height: blink ? R * 0.02 : R * 0.12)).fill()
                if !blink { NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: ex - R * 0.02, y: fy + R * 0.01, width: R * 0.035, height: R * 0.035)).fill(); ink.setFill() } }
            if sad { let b = NSBezierPath(); b.move(to: NSPoint(x: ex - sx * R * 0.07, y: fy + R * 0.13)); b.line(to: NSPoint(x: ex + sx * R * 0.05, y: fy + R * 0.09)); b.lineWidth = max(0.8, R * 0.025); b.stroke() }
        }
        let m = NSBezierPath(), my = fy - R * 0.14
        if sad { m.move(to: NSPoint(x: -R * 0.07, y: my - R * 0.02)); m.curve(to: NSPoint(x: R * 0.07, y: my - R * 0.02), controlPoint1: NSPoint(x: -R * 0.03, y: my + R * 0.04), controlPoint2: NSPoint(x: R * 0.03, y: my + R * 0.04)) }
        else if eatGlow > 0.3 { NSBezierPath(ovalIn: NSRect(x: -R * 0.045, y: my - R * 0.06, width: R * 0.09, height: R * 0.09 * (0.6 + 0.4 * sin(t * 18)))).fill() }
        else { m.move(to: NSPoint(x: -R * 0.07, y: my)); m.curve(to: NSPoint(x: R * 0.07, y: my), controlPoint1: NSPoint(x: -R * 0.03, y: my - R * 0.06), controlPoint2: NSPoint(x: R * 0.03, y: my - R * 0.06)) }
        m.lineWidth = max(1, R * 0.03); m.lineCapStyle = .round; m.stroke()
        let blushA = (happy ? 0.45 : 0.15) + 0.3 * pet
        for sx in [-1.0, 1.0] as [CGFloat] { let b = NSRect(x: sx * w * 0.24 - R * 0.09, y: fy - R * 0.11, width: R * 0.18, height: R * 0.09)
            NSGradient(colors: [col(1, 0.45, 0.6, blushA), col(1, 0.5, 0.6, 0)])!.draw(in: NSBezierPath(ovalIn: b), relativeCenterPosition: .zero) }
        NSGraphicsContext.restoreGraphicsState()
        // sparkles / hearts
        for sp in sparkles { let a = max(0, min(1, sp.life * 1.5)), r: CGFloat = 4 + 3 * (1 - sp.life)
            if sp.heart { col(1, 0.5, 0.7, a).setFill(); Variant.heart(sp.p, r).fill() }
            else { col(1, 0.97, 0.75, a).setFill(); let p = NSBezierPath(); for i in 0..<8 { let ang = CGFloat(i) * .pi / 4, rr = i % 2 == 0 ? r * 1.4 : r * 0.35; let pt = NSPoint(x: sp.p.x + cos(ang) * rr, y: sp.p.y + sin(ang) * rr); i == 0 ? p.move(to: pt) : p.line(to: pt) }; p.close(); p.fill() } }
    }
    override func mouseDown(with e: NSEvent) { if hitTestJelly(convert(e.locationInWindow, from: nil)) { onClick?(e) } }
}

final class JellyWindow: NSWindow { override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }

/// Owns the full-screen desktop-level window, the 30fps loop, mouse polling and persistence
final class JellyController: NSObject {
    let model = Jelly()
    var win: JellyWindow?; var view: JellyView?
    var timer: Timer?; var paused = false
    var lastMouse = NSPoint.zero; var lastSave: TimeInterval = 0
    weak var below: NSWindow?
    static var enabled: Bool { defaults.object(forKey: "jelly.show") as? Bool ?? true }
    override init() {
        super.init(); model.catchUp()
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification] { nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.paused = true } }
        for n in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification] { nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.paused = false; self?.model.catchUp() } }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.layout() }
    }
    func start(below w: NSWindow?) { below = w; if JellyController.enabled { show() } }
    func show() {
        if win == nil {
            let scr = NSScreen.main ?? NSScreen.screens[0]
            let w = JellyWindow(contentRect: scr.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            let v = JellyView(frame: NSRect(origin: .zero, size: scr.frame.size), model: model)
            v.onClick = { [weak self] e in self?.popMenu(e) }
            w.contentView = v; win = w; view = v; layout()
        }
        if let b = below, b.isVisible { win?.order(.below, relativeTo: b.windowNumber) } else { win?.orderFront(nil) }
        timer?.invalidate()
        let tm = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.frame() }
        RunLoop.main.add(tm, forMode: .common); timer = tm
        if !model.st.adopted { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.adopt() } }
    }
    func hide() { timer?.invalidate(); timer = nil; win?.orderOut(nil); model.save() }
    func layout() {
        guard let w = win, let v = view else { return }
        let scr = NSScreen.main ?? NSScreen.screens[0]
        w.setFrame(scr.frame, display: false); v.frame = NSRect(origin: .zero, size: scr.frame.size)
        let vf = scr.visibleFrame; v.swimRect = NSRect(x: vf.minX - scr.frame.minX, y: vf.minY - scr.frame.minY, width: vf.width, height: vf.height).insetBy(dx: 10, dy: 10)
        v.pos.x = min(max(v.pos.x, v.swimRect.minX + 80), v.swimRect.maxX - 80); v.pos.y = min(max(v.pos.y, v.swimRect.minY + 80), v.swimRect.maxY - 80); v.resetChains()
    }
    func frame() {
        guard !paused, let w = win, let v = view, w.isVisible else { return }
        let dt: CGFloat = 1.0 / 30
        v.step(dt)
        // petting: global mouse polling (window is click-through); only counts when the jelly is the topmost thing under the cursor
        let m = NSEvent.mouseLocation, local = NSPoint(x: m.x - w.frame.minX, y: m.y - w.frame.minY)
        var over = false
        if v.hitTestJelly(local) { over = NSWindow.windowNumber(at: m, belowWindowWithWindowNumber: 0) == w.windowNumber }
        if over && hypot(m.x - lastMouse.x, m.y - lastMouse.y) > 1.5 { v.petted(dt) }
        if w.ignoresMouseEvents == over { w.ignoresMouseEvents = !over }
        lastMouse = m
        v.invalidate()
        let now = Date().timeIntervalSince1970
        if now - lastSave > 60 { lastSave = now; model.advance(days: (now - model.st.lastUpdate) / 86400); model.st.lastUpdate = now; model.save() }
    }
    func feed() { if win == nil || !(win!.isVisible) { defaults.set(true, forKey: "jelly.show"); show() }; view?.feed() }
    func askName() -> String? {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = "🪼 해파리 이름을 지어 주세요"; a.informativeText = "바탕화면을 헤엄쳐 다닐 거예요. 비워 두면 '말랑이'라고 불러요."
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 28)); tf.font = cute(15); tf.placeholderString = "말랑이"; tf.stringValue = model.st.name ?? ""
        a.accessoryView = tf; a.addButton(withTitle: "좋아요"); a.addButton(withTitle: "건너뛰기"); a.window.initialFirstResponder = tf
        let r = a.runModal(); NSApp.setActivationPolicy(.accessory)
        guard r == .alertFirstButtonReturn else { return nil }
        let v = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); return v.isEmpty ? nil : String(v.prefix(16))
    }
    func adopt() { guard !model.st.adopted else { return }; model.st.adopted = true; model.st.born = Date().timeIntervalSince1970; model.st.name = askName(); model.save() }
    @objc func rename() { if let n = askName() { model.st.name = n; model.save() } }
    @objc func feedAction() { feed() }
    func bar(_ v: Double) -> String { let n = Int((v * 5).rounded()); return String(repeating: "●", count: n) + String(repeating: "○", count: 5 - n) }
    func statusLines() -> [String] {
        let st = model.st
        let mood = model.mood > 0.75 ? "기분 최고 💕" : model.mood > 0.45 ? "느긋해요" : model.mood > 0.25 ? "조금 시무룩" : "배고프고 쓸쓸해요…"
        return ["🪼 \(model.name) · \(Jelly.stageNames[model.stage]) 해파리 · \(model.days)일째",
                "배부름 \(bar(st.fullness)) \(Int(st.fullness * 100))%",
                "행복도 \(bar(st.happiness)) \(Int(st.happiness * 100))%",
                "\(mood) · 쓰다듬으면 좋아해요"]
    }
    func fillMenu(_ m: NSMenu, includeToggle: Bool) {
        for l in statusLines() { m.addItem(withTitle: l, action: nil, keyEquivalent: "").isEnabled = false }
        m.addItem(.separator())
        m.addItem(withTitle: "🦐 먹이 주기", action: #selector(feedAction), keyEquivalent: "").target = self
        m.addItem(withTitle: "✏️ 이름 바꾸기…", action: #selector(rename), keyEquivalent: "").target = self
        if includeToggle { let it = m.addItem(withTitle: "해파리 보이기", action: #selector(toggle), keyEquivalent: ""); it.target = self; it.state = (win?.isVisible ?? false) ? .on : .off }
    }
    func popMenu(_ e: NSEvent) { guard let v = view else { return }; let m = NSMenu(); m.autoenablesItems = false; fillMenu(m, includeToggle: false); NSMenu.popUpContextMenu(m, with: e, for: v) }
    @objc func toggle() { let on = !(win?.isVisible ?? false); defaults.set(on, forKey: "jelly.show"); on ? show() : hide() }
}
