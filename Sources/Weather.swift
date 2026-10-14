import AppKit

enum Precip: String { case none, drizzle, rain, heavyRain, freezingRain, sleet, snow, heavySnow, blizzard, storm }
struct Wx {
    var code = 0, isDay = true, temp = 18.0, wind = 5.0, humidity = 60.0, uv = 3.0, visibility = 20000.0
    var pm10 = 20.0, pm25 = 10.0, rainbow = false
    var month = Calendar.current.component(.month, from: Date())
    var hour: Double = { let c = Calendar.current.dateComponents([.hour, .minute], from: Date()); return Double(c.hour!) + Double(c.minute!)/60 }()
    var sunrise = 6.6, sunset = 18.0
    var precip: Precip {
        switch code {
        case 51, 53, 55: return .drizzle
        case 56, 57, 66, 67: return .freezingRain
        case 61, 80: return .rain
        case 63, 81: return temp < 2 ? .sleet : .rain
        case 65, 82: return .heavyRain
        case 71, 85: return .snow
        case 73, 77: return wind > 35 ? .blizzard : .snow
        case 75, 86: return wind > 35 ? .blizzard : .heavySnow
        case 95, 96, 99: return .storm
        default: return .none
        }
    }
    var clouds: Double { switch code { case 0: return 0; case 1: return 0.2; case 2: return 0.5; case 3: return 1; case 45, 48: return 0.8; default: return precip == .drizzle ? 0.8 : 1 } }
    var fog: Bool { code == 45 || code == 48 || visibility < 1500 }
    var yellowDust: Bool { pm10 >= 150 && pm25 / max(pm10, 1) < 0.45 }
    var fineDust: Bool { pm25 >= 36 || pm10 >= 81 }
    var golden: Double { // 0..1 closeness to sunrise/sunset
        let d = min(abs(hour - sunrise), abs(hour - sunset)); return max(0, 1 - d / 0.9) }
    var season: Int { [3, 3, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3][month - 1] }  // 0 spring 1 summer 2 autumn 3 winter
    var light: Double {
        guard isDay else { return 0 }
        var l = 1 - 0.55 * clouds
        switch precip { case .none: break; case .drizzle: l = min(l, 0.4); case .storm: l = 0.2; default: l = min(l, 0.32) }
        if fog { l *= 0.75 }; if fineDust { l *= 0.85 }; if golden > 0 { l *= 1 - 0.4 * golden }
        return l
    }
    var desc: String {
        var s: String
        switch precip {
        case .drizzle: s = "이슬비"; case .rain: s = "비"; case .heavyRain: s = "폭우"; case .freezingRain: s = "어는 비"; case .sleet: s = "진눈깨비"
        case .snow: s = "눈"; case .heavySnow: s = "폭설"; case .blizzard: s = "눈보라"; case .storm: s = "뇌우"
        case .none: s = fog ? (visibility < 500 ? "짙은 안개" : "안개") : code == 0 ? (isDay ? "맑음" : "맑은 밤") : code == 1 ? "대체로 맑음" : code == 2 ? "구름 조금" : "흐림"
        }
        if rainbow { s += " · 무지개" }
        if yellowDust { s += " · 황사" } else if fineDust { s += " · 미세먼지" }
        if wind >= 30 { s += " · 강풍" }
        return s
    }
    static let presets: [(String, Wx)] = {
        func w(_ f: (inout Wx) -> Void) -> Wx { var x = Wx(); f(&x); return x }
        return [
            ("맑은 봄날", w { $0.code = 0; $0.month = 4; $0.hour = 11 }),
            ("무지개", w { $0.code = 1; $0.rainbow = true; $0.month = 7; $0.hour = 16; $0.temp = 26 }),
            ("뇌우", w { $0.code = 95; $0.month = 7; $0.hour = 15; $0.wind = 30; $0.temp = 27 }),
            ("이슬비·결로", w { $0.code = 53; $0.month = 10; $0.hour = 9; $0.temp = 9; $0.humidity = 95 }),
            ("폭우", w { $0.code = 65; $0.month = 8; $0.hour = 13; $0.temp = 25; $0.wind = 20 }),
            ("어는 비", w { $0.code = 66; $0.month = 1; $0.hour = 10; $0.temp = -1 }),
            ("진눈깨비", w { $0.code = 63; $0.month = 12; $0.hour = 12; $0.temp = 1 }),
            ("함박눈", w { $0.code = 71; $0.month = 1; $0.hour = 11; $0.temp = -3 }),
            ("눈보라·성에", w { $0.code = 75; $0.month = 1; $0.hour = 14; $0.temp = -10; $0.wind = 50 }),
            ("안개", w { $0.code = 45; $0.month = 11; $0.hour = 7.5; $0.visibility = 300; $0.humidity = 98; $0.temp = 8 }),
            ("강풍 가을", w { $0.code = 2; $0.month = 10; $0.hour = 14; $0.wind = 45 }),
            ("황사", w { $0.code = 1; $0.month = 4; $0.hour = 13; $0.pm10 = 320; $0.pm25 = 70; $0.wind = 25 }),
            ("미세먼지", w { $0.code = 2; $0.month = 2; $0.hour = 12; $0.pm10 = 110; $0.pm25 = 60; $0.temp = 4 }),
            ("일출", w { $0.code = 1; $0.month = 5; $0.hour = 6.7; $0.temp = 15 }),
            ("노을", w { $0.code = 1; $0.month = 9; $0.hour = 17.9; $0.temp = 22 }),
            ("폭염 아지랑이", w { $0.code = 0; $0.month = 8; $0.hour = 14; $0.temp = 35; $0.uv = 10 }),
            ("달밤", w { $0.code = 0; $0.isDay = false; $0.month = 10; $0.hour = 22; $0.temp = 12 }),
        ]
    }()
}

/// Current weather (real, or debug preset)
var currentWx = Wx()
var debugPreset: Int? = nil

class WeatherView: NSView {
    var wx: Wx { if let i = debugPreset { return Wx.presets[i].1 }; return currentWx }
    var temp: Double? { weatherKnown || debugPreset != nil ? wx.temp : nil }
    var parts: [(CGFloat, CGFloat, CGFloat)] = []
    var t: CGFloat = 0; var lastRainAt: Date? = nil; var flash: CGFloat = 0; var nextFlash: CGFloat = 4
    var plantLabel: String = ""
    let patchW: CGFloat = 90
    var innerRect: NSRect { glassTheme ? NSRect(x: 16, y: 26, width: 222, height: 282) : NSRect(x: 18, y: 26, width: bounds.width - 36, height: bounds.height - 38) }
    var glassRect: NSRect { innerRect.insetBy(dx: 6, dy: 6) }
    var sillTop: CGFloat { innerRect.minY - 4 }
    var sunPatchCenter: CGFloat? {
        let f: Double?
        if debugPreset != nil { let w = wx; f = w.isDay ? max(0, min(1, (w.hour - w.sunrise - 0.3) / (w.sunset - w.sunrise - 0.6))) : nil } else { f = sunPatchFrac() }
        return f.map { glassRect.minX + patchW/2 + CGFloat($0) * (glassRect.width - patchW) } }
    override var mouseDownCanMoveWindow: Bool { true }
    var hover: CGFloat = 0, hoverTarget: CGFloat = 0
    var plantInfo: (() -> (String, Double, Double, Double)?)?   // (title, moisture, health, light)
    lazy var card: NSVisualEffectView = {
        let v = NSVisualEffectView(); v.material = .hudWindow; v.blendingMode = .withinWindow; v.state = .active
        v.wantsLayer = true; v.layer?.cornerRadius = 10; v.layer?.masksToBounds = true; v.alphaValue = 0
        let c = CardView(frame: .zero); c.owner = self; c.autoresizingMask = [.width, .height]; v.addSubview(c); return v }()
    var debugPresetName: String? { debugPreset.map { Wx.presets[$0].0 } }
    var weatherLine: String {
        var s = "\(defaults.string(forKey: "cityName") ?? "서울") · \(wx.desc)" + (temp.map { String(format: " · %.0f°C", $0) } ?? "")
        if let i = debugPreset { s = "🐞 \(Wx.presets[i].0) · " + s } else if let m = staleMinutes { s += m >= 120 ? " · \(m/60)시간 전" : " · \(m)분 전" }; return s }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with e: NSEvent) { hoverTarget = 1 }
    override func mouseExited(with e: NSEvent) { hoverTarget = 0 }
    enum CardMode { case full, mid, pill }
    var cardMode: CardMode = .full
    static var cardSize: NSSize { NSSize(width: 260, height: designRound ? 76 : 80) }      // screen points, never scaled
    var external = false
    lazy var bubble: BubblePanel = BubblePanel(owner: self)
    /// Full card inside the glass if it fits at fixed screen size; otherwise a floating bubble outside the widget
    func layoutCard() {
        cardMode = .full
        let sc = sceneScale(self), g = glassRect, m: CGFloat = 6, size = WeatherView.cardSize
        external = windowStyle == 3 || g.width * sc - 2 * m < size.width || g.height * sc < size.height * 2.2
        card.frame = NSRect(x: g.minX + m / sc, y: g.maxY - (m + size.height) / sc, width: size.width / sc, height: size.height / sc)
        card.layer?.cornerRadius = R(14) / sc
        if let cv = card.subviews.first { cv.frame = card.bounds; cv.bounds = NSRect(origin: .zero, size: size); cv.needsDisplay = true }
    }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); layoutCard() }
    func setHover(_ h: CGFloat) { if h > 0 && hover == 0 { layoutCard() }; hover = h; gaugeAlpha = h; subviews.forEach { if $0 is PlantView { $0.needsDisplay = true } }
        if external { card.isHidden = true; if window != nil { bubble.show(alpha: h, near: window!.frame) } }
        else { bubble.orderOut(nil); card.alphaValue = h; card.isHidden = h <= 0.01 }; (card.subviews.first as? CardView)?.needsDisplay = true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        let g = glassRect; card.frame = NSRect(x: g.minX + 8, y: g.maxY - 62, width: g.width - 16, height: 54); addSubview(card); card.isHidden = true
        for _ in 0..<160 { parts.append((.random(in: 0...1), .random(in: 0...1), .random(in: 0.3...1))) }
        Timer.scheduledTimer(withTimeInterval: 1/24, repeats: true) { [weak self] _ in self?.tick() }
        // Wall-clock driven refresh (NSTimer intervals pause during sleep): every minute recompute day/night
        // from the clock + real sunrise/sunset, and refetch when data is ≥15 min old (retry each minute on failure)
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.clockTick() }
        for n in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                self?.lastFetchAttempt = 0; self?.clockTick()
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.fetch() } } }
        fetch()
    }
    required init?(coder: NSCoder) { fatalError() }

    func tick() {
        t += 1/24
        let w = wx, p = w.precip
        let fall: CGFloat, drift = CGFloat(w.wind) / 4000
        switch p {
        case .drizzle: fall = 0.006; case .rain, .freezingRain: fall = 0.013; case .heavyRain, .storm: fall = 0.022
        case .sleet: fall = 0.008; case .snow: fall = 0.0025; case .heavySnow: fall = 0.0035; case .blizzard: fall = 0.006
        case .none: fall = 0.002 }
        parts = parts.map { q in var y = q.1 - fall * q.2; var x = q.0 + drift * q.2 + (p == .snow || p == .heavySnow ? sin(t*2 + q.2*9)*0.0012 : 0)
            if y < 0 { y = 1; x = .random(in: 0...1) }; if x > 1 { x -= 1 }; return (x, y, q.2) }
        if p == .storm { if t > nextFlash { flash = 1; nextFlash = t + .random(in: 5...11) } }
        flash = max(0, flash - 0.08)
        if abs(hover - hoverTarget) > 0.01 { setHover(hover + (hoverTarget - hover) * 0.25) } else if hover != hoverTarget { setHover(hoverTarget) }
        if hover > 0 { (card.subviews.first as? CardView)?.needsDisplay = true; if external { bubble.bubbleView.card.needsDisplay = true } }
        needsDisplay = true
    }

    var lastFetchOK: TimeInterval = 0, lastFetchAttempt: TimeInterval = 0
    static func tod(_ d: Date) -> Double { let x = Calendar.current.dateComponents([.hour, .minute], from: d); return Double(x.hour!) + Double(x.minute!)/60 }
    func clockTick() {
        let now = Date().timeIntervalSince1970
        var w = currentWx
        w.hour = WeatherView.tod(Date()); w.month = Calendar.current.component(.month, from: Date())
        w.sunrise = WeatherView.tod(sunriseT); w.sunset = WeatherView.tod(sunsetT)
        w.isDay = w.hour >= w.sunrise && w.hour < w.sunset            // clock is the source of truth for day/night
        if lastFetchOK > 0 && now - lastFetchOK > 3 * 3600 { w.rainbow = false }   // very stale: drop transient effects
        currentWx = w; publish()
        let stale = now - lastFetchOK >= 15 * 60
        if stale && now - lastFetchAttempt >= 55 { fetch() }
    }
    var staleMinutes: Int? { lastFetchOK == 0 ? nil : { let m = Int((Date().timeIntervalSince1970 - lastFetchOK) / 60); return m >= 30 ? m : nil }() }
    func fetch() {
        lastFetchAttempt = Date().timeIntervalSince1970
        let lat = defaults.object(forKey: "lat") as? Double ?? 37.5665, lon = defaults.object(forKey: "lon") as? Double ?? 126.978
        let f = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,is_day,wind_speed_10m,uv_index,visibility&daily=sunrise,sunset&forecast_days=1&timezone=auto")!
        let a = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(lat)&longitude=\(lon)&current=pm10,pm2_5&timezone=auto")!
        URLSession.shared.dataTask(with: f) { data, _, _ in
            guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let c = j["current"] as? [String: Any] else { return }
            func n(_ k: String) -> Double? { (c[k] as? NSNumber)?.doubleValue }
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd'T'HH:mm"; df.timeZone = TimeZone(identifier: (j["timezone"] as? String) ?? "Asia/Seoul")
            let daily = j["daily"] as? [String: Any]
            let sr = (daily?["sunrise"] as? [String])?.first.flatMap { df.date(from: $0) }, ss = (daily?["sunset"] as? [String])?.first.flatMap { df.date(from: $0) }
            DispatchQueue.main.async {
                var w = currentWx
                w.code = Int(n("weather_code") ?? 0); w.isDay = (n("is_day") ?? 1) == 1; w.temp = n("temperature_2m") ?? w.temp
                w.wind = n("wind_speed_10m") ?? 0; w.humidity = n("relative_humidity_2m") ?? 60; w.uv = n("uv_index") ?? 0; w.visibility = n("visibility") ?? 20000
                if let sr { sunriseT = sr }; if let ss { sunsetT = ss }
                let cal = Calendar.current; func tod(_ d: Date) -> Double { let x = cal.dateComponents([.hour, .minute], from: d); return Double(x.hour!) + Double(x.minute!)/60 }
                w.sunrise = tod(sunriseT); w.sunset = tod(sunsetT); w.hour = tod(Date()); w.month = cal.component(.month, from: Date())
                if w.precip != .none { self.lastRainAt = Date() }
                w.rainbow = w.isDay && w.precip == .none && w.clouds <= 0.5 && (self.lastRainAt.map { Date().timeIntervalSince($0) < 3600 } ?? false)
                self.lastFetchOK = Date().timeIntervalSince1970
                currentWx = w; self.publish()
            }
        }.resume()
        URLSession.shared.dataTask(with: a) { data, _, _ in
            guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let c = j["current"] as? [String: Any] else { return }
            DispatchQueue.main.async { currentWx.pm10 = (c["pm10"] as? NSNumber)?.doubleValue ?? 0; currentWx.pm25 = (c["pm2_5"] as? NSNumber)?.doubleValue ?? 0; self.publish() }
        }.resume()
    }
    func publish() {
        currentWx.hour = WeatherView.tod(Date())   // update clock BEFORE deriving light
        let w = currentWx   // plant sim always uses REAL weather, not debug previews
        outdoorLight = w.light; outdoorTemp = w.temp; windSpeed = w.wind; pm10 = w.pm10; pm25 = w.pm25; weatherKnown = true
        needsDisplay = true
    }

    // MARK: drawing helpers
    func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { NSBezierPath(ovalIn: NSRect(x: x - w/2, y: y - h/2, width: w, height: h)).fill() }
    func cloud(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: NSColor) {
        c.setFill(); for (dx, dy, r) in [(0.0, 0.0, 1.0), (0.9, 0.3, 1.2), (1.9, 0.0, 0.9), (0.9, -0.3, 1.0)] as [(CGFloat, CGFloat, CGFloat)] { oval(x + dx*s, y + dy*s, 2*r*s, 1.4*r*s) } }
    func mix(_ a: NSColor, _ b: NSColor, _ f: Double) -> NSColor { a.blended(withFraction: CGFloat(max(0, min(1, f))), of: b) ?? a }
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
    func moonPhase() -> Double { let jd = Date().timeIntervalSince1970 / 86400 + 2440587.5; return ((jd - 2451550.1) / 29.530588853).truncatingRemainder(dividingBy: 1) }

    override func draw(_ r: NSRect) {
        let w = wx, p = w.precip
        let pal: [(NSColor, NSColor, NSColor)] = [(rgb(0.62, 0.45, 0.32), rgb(0.72, 0.55, 0.40), rgb(0.53, 0.37, 0.26)), (rgb(0.95, 0.95, 0.94), rgb(0.99, 0.99, 0.98), rgb(0.86, 0.86, 0.85)),
            (rgb(0.9, 0.86, 0.78), rgb(0.96, 0.93, 0.87), rgb(0.82, 0.77, 0.68)), (rgb(0.78, 0.63, 0.35), rgb(0.93, 0.8, 0.5), rgb(0.62, 0.48, 0.24)), (rgb(0.45, 0.31, 0.21), rgb(0.55, 0.39, 0.27), rgb(0.36, 0.24, 0.16)), (rgb(0.93, 0.92, 0.98, 0.95), rgb(1, 1, 1, 0.97), rgb(0.82, 0.8, 0.9, 0.95))]
        let (wood, woodHi, woodLo) = pal[min(windowStyle, pal.count - 1)]
        let inner = innerRect, glass = glassRect, outer = inner.insetBy(dx: -6, dy: -6)
        if glassTheme { drawGlassFrame(outer) } else {
        NSColor(white: 0, alpha: 0.12).setFill(); let sh0 = windowShape(outer, 0); sh0.transform(using: AffineTransform(translationByX: 0, byY: -2)); sh0.fill()
        NSGradient(starting: woodLo, ending: woodHi)!.draw(in: windowShape(outer, 0), angle: 90) }
        if windowStyle == 3 { let ring = windowShape(outer, 0); for k in 0..<10 { let a = CGFloat(k) * .pi / 5, b = ring.bounds, rr = b.width/2 - 5
            woodLo.setFill(); oval(b.midX + cos(a)*rr, b.midY + sin(a)*rr, 4.5, 4.5); woodHi.setFill(); oval(b.midX + cos(a)*rr - 0.6, b.midY + sin(a)*rr + 0.6, 2, 2) } }
        if !glassTheme { NSColor(white: 0, alpha: 0.16).setFill(); windowShape(outer, 10).fill() }   // inner recess
        let glassShape = windowShape(outer, windowStyle == 3 ? 12 : 12)
        NSGraphicsContext.saveGraphicsState(); glassShape.addClip()
        // sky
        var top: NSColor, bot: NSColor
        if w.isDay {
            top = mix(rgb(0.47, 0.68, 0.9), rgb(0.62, 0.66, 0.71), w.clouds); bot = mix(rgb(0.84, 0.92, 0.97), rgb(0.83, 0.85, 0.87), w.clouds)
            if p == .storm || p == .heavyRain { top = rgb(0.32, 0.35, 0.42); bot = rgb(0.52, 0.55, 0.6) }
            if w.golden > 0 { top = mix(top, rgb(0.45, 0.4, 0.7), w.golden * 0.8); bot = mix(bot, rgb(1, 0.6, 0.35), w.golden) }
            if w.yellowDust { top = mix(top, rgb(0.85, 0.72, 0.45), 0.7); bot = mix(bot, rgb(0.9, 0.78, 0.5), 0.75) }
            else if w.fineDust { top = mix(top, rgb(0.7, 0.68, 0.62), 0.6); bot = mix(bot, rgb(0.8, 0.77, 0.7), 0.6) }
        } else { top = rgb(0.09, 0.11, 0.24); bot = mix(rgb(0.2, 0.2, 0.36), rgb(0.27, 0.28, 0.33), w.clouds) }
        if glassTheme {   // dreamy pastel: lavender-blue zenith → peach horizon
            if w.isDay { top = mix(mix(rgb(0.62, 0.68, 0.95), rgb(0.6, 0.6, 0.7), w.clouds), top, p == .storm || p == .heavyRain ? 0.8 : 0.15)
                bot = mix(mix(rgb(1, 0.82, 0.7), rgb(0.85, 0.82, 0.86), w.clouds), bot, p == .storm || p == .heavyRain ? 0.8 : 0.15) }
            else { top = mix(rgb(0.13, 0.11, 0.32), top, 0.3); bot = mix(rgb(0.38, 0.28, 0.5), bot, 0.4) } }
        if flash > 0 { top = mix(top, .white, Double(flash) * 0.8); bot = mix(bot, .white, Double(flash) * 0.8) }
        if glassTheme { NSGradient(colors: [bot, mix(bot, top, 0.55).blended(withFraction: w.isDay ? 0.12 : 0, of: rgb(0.85, 0.8, 1)) ?? top, top], atLocations: [0, 0.45, 1], colorSpace: .deviceRGB)!.draw(in: glass, angle: 90) }
        else { NSGradient(starting: bot, ending: top)!.draw(in: glass, angle: 90) }
        if let img = bgImage {   // user photo, aspect-fill, then weather tints
            let gb = glassShape.bounds, s = img.size, k = max(gb.width / max(1, s.width), gb.height / max(1, s.height))
            img.draw(in: NSRect(x: gb.midX - s.width*k/2, y: gb.midY - s.height*k/2, width: s.width*k, height: s.height*k), from: .zero, operation: .sourceOver, fraction: 1)
            if !w.isDay { rgb(0.03, 0.05, 0.18, 0.62).setFill(); glass.fill(using: .sourceOver) }
            else {
                if w.clouds > 0.3 || p != .none { NSColor(white: 0.55, alpha: 0.12 + 0.25 * CGFloat(w.clouds) + (p == .storm || p == .heavyRain ? 0.2 : 0)).setFill(); glass.fill(using: .sourceOver) }
                if w.golden > 0 { rgb(1, 0.55, 0.25, 0.3 * CGFloat(w.golden)).setFill(); glass.fill(using: .sourceOver) }
            }
            if flash > 0 { NSColor(white: 1, alpha: flash * 0.7).setFill(); glass.fill(using: .sourceOver) }
        }
        let s = w.season, winterSnow = bgImage == nil && s == 3 && (w.temp < 3 || p == .snow || p == .heavySnow || p == .blizzard)
        if bgImage == nil {
        // stars & moon
        if !w.isDay && w.clouds < 0.6 {
            for i in 0..<28 { let x = glass.minX + CGFloat((i*73) % 100)/100*glass.width, y = glass.minY + glass.height*0.35 + CGFloat((i*37) % 100)/100*glass.height*0.65
                NSColor(white: 1, alpha: (0.5 + 0.5*sin(t*2 + CGFloat(i))) * CGFloat(1 - w.clouds)).setFill(); oval(x, y, 2, 2) }
            let c = NSPoint(x: glass.maxX - 50, y: glass.maxY - 45), rr: CGFloat = 17, ph = moonPhase()
            NSColor(white: 1, alpha: 0.15).setFill(); oval(c.x, c.y, 2*rr + 14, 2*rr + 14)
            rgb(0.97, 0.95, 0.85).setFill(); oval(c.x, c.y, 2*rr, 2*rr)
            let dx = 2*rr*CGFloat(ph <= 0.5 ? ph*2 : ph*2 - 2)
            NSGraphicsContext.saveGraphicsState(); NSBezierPath(ovalIn: NSRect(x: c.x-rr, y: c.y-rr, width: 2*rr, height: 2*rr)).addClip()
            rgb(0.06, 0.07, 0.2, 0.92).setFill(); oval(c.x + dx, c.y, 2*rr, 2*rr); NSGraphicsContext.restoreGraphicsState()
        }
        // sun
        if w.isDay && w.clouds < 0.9 && p == .none {
            let span = max(0.1, (w.hour - w.sunrise) / (w.sunset - w.sunrise))
            let sx = glass.minX + 30 + CGFloat(span) * (glass.width - 60), sy = glass.minY + 50 + CGFloat(sin(.pi * span)) * (glass.height - 95)
            let sc = mix(rgb(1, 0.86, 0.2), rgb(1, 0.5, 0.25), w.golden)
            if glassTheme { drawGlowSun(NSPoint(x: sx, y: sy), golden: w.golden, dim: w.clouds) }
            else { sc.withAlphaComponent(0.25).setFill(); oval(sx, sy, 60 + 6*sin(t*2), 60 + 6*sin(t*2)); sc.setFill(); oval(sx, sy, 42, 42) }
        }
        // rainbow
        if w.rainbow { let cx = glass.midX, cy = glass.minY + 20
            for (i, col) in [NSColor.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple].enumerated() {
                let rr = glass.width*0.55 - CGFloat(i)*5; let a = NSBezierPath(); a.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: rr, startAngle: 15, endAngle: 165); col.withAlphaComponent(0.45).setStroke(); a.lineWidth = 5; a.stroke() } }
        // clouds
        let nC = Int(w.clouds * 5 + 0.5)
        let cc: NSColor = w.isDay ? (p == .storm || p == .heavyRain ? NSColor(white: 0.35, alpha: 0.95) : p == .none ? NSColor(white: 0.97, alpha: 0.95) : NSColor(white: 0.7, alpha: 0.95)) : NSColor(white: 0.35, alpha: 0.85)
        let speed = 4 + CGFloat(w.wind) * 0.4
        for i in 0..<nC { let x = glass.minX + ((CGFloat(i)*61 + t*speed).truncatingRemainder(dividingBy: glass.width + 90)) - 45
            cloud(x, glass.maxY - 25 - CGFloat(i%3)*18, 13 + CGFloat(i%2)*4, w.golden > 0 && w.isDay ? mix(cc, rgb(1, 0.7, 0.55), w.golden) : cc) }
        if p == .storm && flash > 0.5 { // lightning bolt
            let bx = glass.minX + glass.width * CGFloat((Int(nextFlash) * 37) % 70 + 15) / 100
            let b = NSBezierPath(); b.move(to: NSPoint(x: bx, y: glass.maxY - 30)); var y = glass.maxY - 30; var x = bx
            while y > glass.minY + 40 { x += .random(in: -10...10); y -= 15; b.line(to: NSPoint(x: x, y: y)) }
            NSColor(calibratedRed: 1, green: 1, blue: 0.8, alpha: flash).setStroke(); b.lineWidth = 2.5; b.stroke() }
        // seasonal hills
        var hill = [rgb(0.6, 0.75, 0.5), rgb(0.45, 0.65, 0.43), rgb(0.78, 0.65, 0.43), rgb(0.68, 0.66, 0.6)][s]
        if winterSnow { hill = rgb(0.93, 0.95, 0.98) }
        if !w.isDay { hill = mix(hill, rgb(0.05, 0.08, 0.12), 0.8) } else if w.golden > 0 { hill = mix(hill, rgb(0.9, 0.5, 0.3), w.golden * 0.4) }
        if glassTheme && !winterSnow { hill = [rgb(0.72, 0.85, 0.62), rgb(0.55, 0.78, 0.55), rgb(0.93, 0.68, 0.4), rgb(0.8, 0.78, 0.82)][s]; if !w.isDay { hill = mix(hill, rgb(0.15, 0.12, 0.3), 0.75) } }
        mix(hill, bot, 0.45).setFill()
        let h2 = NSBezierPath(); h2.move(to: NSPoint(x: glass.minX, y: glass.minY)); h2.line(to: NSPoint(x: glass.minX, y: glass.minY+60))
        h2.curve(to: NSPoint(x: glass.maxX, y: glass.minY+55), controlPoint1: NSPoint(x: glass.midX, y: glass.minY+30), controlPoint2: NSPoint(x: glass.midX+60, y: glass.minY+90)); h2.line(to: NSPoint(x: glass.maxX, y: glass.minY))
        if glassTheme { NSGradient(colors: [mix(hill, bot, 0.6), mix(hill, bot, 0.3)])!.draw(in: h2, angle: 90) } else { h2.fill() }
        hill.setFill()
        let h = NSBezierPath(); h.move(to: NSPoint(x: glass.minX, y: glass.minY)); h.line(to: NSPoint(x: glass.minX, y: glass.minY+40))
        h.curve(to: NSPoint(x: glass.maxX, y: glass.minY+30), controlPoint1: NSPoint(x: glass.midX-40, y: glass.minY+80), controlPoint2: NSPoint(x: glass.midX+40, y: glass.minY+10)); h.line(to: NSPoint(x: glass.maxX, y: glass.minY))
        if glassTheme { NSGradient(colors: [mix(hill, .black, 0.12), hill, mix(hill, .white, 0.25)], atLocations: [0, 0.6, 1], colorSpace: .deviceRGB)!.draw(in: h, angle: 90) } else { h.fill() }
        // tree (sways with wind)
        let sway = CGFloat(min(w.wind, 70)) / 70 * (6 + 4*sin(t*3)) + sin(t*1.3) * 1.5
        let tx = glass.maxX - 70, ty = glass.minY + 48
        let trunk = w.isDay ? rgb(0.48, 0.36, 0.28) : rgb(0.1, 0.08, 0.06)
        trunk.setStroke(); let tr = NSBezierPath(); tr.move(to: NSPoint(x: tx, y: ty - 20)); tr.curve(to: NSPoint(x: tx + sway, y: ty + 45), controlPoint1: NSPoint(x: tx, y: ty + 10), controlPoint2: NSPoint(x: tx + sway*0.5, y: ty + 30)); tr.lineWidth = glassTheme ? 7 : 6; tr.lineCapStyle = .round; tr.stroke()
        for (a, l) in [(-0.7, 22.0), (0.6, 20.0), (-0.2, 16.0)] as [(CGFloat, CGFloat)] { let br = NSBezierPath(); let bp = NSPoint(x: tx + sway*0.7, y: ty + 30); br.move(to: bp); br.line(to: NSPoint(x: bp.x + sin(a)*l + sway*0.4, y: bp.y + cos(a)*l)); br.lineWidth = 2.5; br.stroke() }
        if s != 3 || !w.isDay && false {
            var fol = [rgb(0.98, 0.78, 0.84), rgb(0.36, 0.58, 0.38), rgb(0.9, 0.56, 0.3), rgb(0.5, 0.5, 0.5)][s]
            if !w.isDay { fol = mix(fol, rgb(0.05, 0.08, 0.1), 0.75) }
            if glassTheme { if s == 2 && w.isDay { fol = rgb(0.98, 0.58, 0.28) }
                NSGraphicsContext.saveGraphicsState(); let ft = NSAffineTransform(); ft.translateX(by: tx + sway, yBy: ty + 50); ft.scale(by: 1.28); ft.translateX(by: -(tx + sway), yBy: -(ty + 50)); ft.concat(); defer { NSGraphicsContext.restoreGraphicsState() }
                for (dx, dy, rr) in [(-18.0, 42.0, 11.0), (-6.0, 37.0, 12.0), (8.0, 38.0, 12.0), (20.0, 43.0, 11.0), (-24.0, 54.0, 10.0), (24.0, 55.0, 10.0), (-13.0, 52.0, 13.0), (13.0, 53.0, 13.0), (0.0, 50.0, 14.0), (-10.0, 65.0, 12.0), (10.0, 66.0, 12.0), (0.0, 74.0, 10.0), (-20.0, 64.0, 8.0), (20.0, 64.0, 8.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    let b = NSBezierPath(ovalIn: NSRect(x: tx + sway + dx - rr, y: ty + dy - rr*0.9, width: rr*2, height: rr*1.8))
                    NSGradient(colors: [mix(fol, rgb(1, 0.9, 0.6), 0.45), fol, mix(fol, rgb(0.6, 0.18, 0.15), 0.35)])!.draw(in: b, relativeCenterPosition: NSPoint(x: -0.35, y: 0.45)) }
                mix(fol, rgb(0.55, 0.2, 0.1), 0.4).setFill(); for i in 0..<16 { let a = CGFloat(i) * 2.4, rr = 8 + CGFloat((i * 7) % 18)
                    let lf = NSBezierPath(ovalIn: NSRect(x: -2, y: -1, width: 4, height: 2)); let tf = NSAffineTransform(); tf.translateX(by: tx + sway + cos(a)*rr, yBy: ty + 55 + sin(a)*rr*0.8); tf.rotate(byRadians: a); lf.transform(using: tf as AffineTransform); lf.fill() } }
            else { fol.setFill(); for (dx, dy, rr) in [(0.0, 52.0, 26.0), (-14.0, 42.0, 20.0), (14.0, 44.0, 20.0), (0.0, 64.0, 18.0)] as [(CGFloat, CGFloat, CGFloat)] { oval(tx + sway + dx, ty + dy, rr*2, rr*1.7) } }
            if s == 0 && w.isDay { NSColor.white.withAlphaComponent(0.6).setFill(); for i in 0..<14 { oval(tx + sway + CGFloat((i*29)%50) - 25, ty + 35 + CGFloat((i*17)%40), 4, 4) } }
        } else if winterSnow { NSColor.white.setFill(); oval(tx + sway*0.7 - 8, ty + 44, 12, 4); oval(tx + sway*0.7 + 10, ty + 46, 10, 3) }
        // drifting things: petals (spring), leaves (autumn or windy), birds, butterflies
        let windy = w.wind >= 25
        if (s == 0 || s == 2 || windy) && p == .none && !w.fog {
            let n = windy ? 14 : 6
            for i in 0..<n { let q = parts[i]
                let col = s == 0 ? rgb(1, 0.78, 0.85) : s == 2 ? (i % 2 == 0 ? rgb(0.9, 0.4, 0.1) : rgb(0.85, 0.65, 0.15)) : rgb(0.35, 0.6, 0.25)
                let x = glass.minX + (q.0 + (windy ? t*0.05*q.2 : 0)).truncatingRemainder(dividingBy: 1) * glass.width
                let y = glass.minY + (q.1*0.8 + 0.1) * glass.height
                (w.isDay ? col : mix(col, .black, 0.7)).setFill()
                let lf = NSBezierPath(ovalIn: NSRect(x: -3, y: -1.5, width: 6, height: 3)); let tf = NSAffineTransform(); tf.translateX(by: x, yBy: y); tf.rotate(byRadians: t*2*q.2 + CGFloat(i)); lf.transform(using: tf as AffineTransform); lf.fill() } }
        if w.isDay && p == .none && !w.fog && !w.yellowDust {
            let cyc = (t / 30).truncatingRemainder(dividingBy: 1)  // a flock every 30s
            if cyc < 0.5 { let bx = glass.minX - 20 + cyc*2 * (glass.width + 40)
                NSColor(white: 0.15, alpha: 0.8).setStroke()
                for k in 0..<3 { let x = bx - CGFloat(k)*14, y = glass.maxY - 60 - CGFloat(k%2)*8 + sin(t + CGFloat(k))*3, f = 3 + 2*sin(t*8 + CGFloat(k))
                    let bp = NSBezierPath(); bp.move(to: NSPoint(x: x-5, y: y+f)); bp.line(to: NSPoint(x: x, y: y)); bp.line(to: NSPoint(x: x+5, y: y+f)); bp.lineWidth = 1.3; bp.stroke() } }
            if (s == 0 || s == 1) && !windy { for k in 0..<2 { // butterflies
                let x = glass.midX + 30 + sin(t*0.5 + CGFloat(k)*2)*50, y = glass.minY + 50 + cos(t*0.7 + CGFloat(k))*15, fl = abs(sin(t*10 + CGFloat(k)))
                (k == 0 ? rgb(1, 0.85, 0.2) : rgb(0.95, 0.95, 1)).setFill(); oval(x-3, y, 6*fl, 6); oval(x+3, y, 6*fl, 6) } }
        }
        }   // end drawn landscape
        // heat shimmer
        if w.temp >= 30 && w.isDay { for i in 0..<5 { let y = glass.minY + 10 + CGFloat(i)*9
            let sh = NSBezierPath(); sh.move(to: NSPoint(x: glass.minX, y: y)); var x = glass.minX
            while x < glass.maxX { x += 10; sh.line(to: NSPoint(x: x, y: y + sin(x/9 + t*5)*1.6)) }
            NSColor(white: 1, alpha: 0.18).setStroke(); sh.lineWidth = 2; sh.stroke() } }
        // precipitation
        let wdx = CGFloat(w.wind) / 6
        func drops(_ n: Int, _ len: CGFloat, _ col: NSColor, _ lw: CGFloat) {
            col.setStroke(); let pth = NSBezierPath(); pth.lineWidth = lw
            for q in parts.prefix(n) { let x = glass.minX + q.0*glass.width, y = glass.minY + q.1*glass.height
                pth.move(to: NSPoint(x: x, y: y)); pth.line(to: NSPoint(x: x - wdx*q.2*0.5 - 1, y: y + len*q.2)) }
            pth.stroke() }
        func flakes(_ n: Int, _ sz: CGFloat, from: Int = 0) { NSColor.white.setFill()
            for q in parts[from..<min(parts.count, from + n)] { oval(glass.minX + q.0*glass.width, glass.minY + q.1*glass.height, sz*q.2 + 1.5, sz*q.2 + 1.5) } }
        switch p {
        case .drizzle: drops(60, 3, rgb(0.85, 0.9, 1, 0.5), 1)
        case .rain: drops(60, 7, rgb(0.8, 0.9, 1, 0.7), 1.5)
        case .heavyRain, .storm: drops(130, 12, rgb(0.8, 0.88, 1, 0.7), 1.6)
        case .freezingRain: drops(70, 6, rgb(0.85, 0.95, 1, 0.85), 1.5)
        case .sleet: drops(40, 5, rgb(0.8, 0.9, 1, 0.7), 1.3); flakes(30, 2.5, from: 60)
        case .snow: flakes(40, 3.5)
        case .heavySnow: flakes(100, 4)
        case .blizzard: flakes(160, 3.5); NSColor(white: 1, alpha: 0.35).setFill(); glass.fill(using: .sourceOver)
        case .none: break
        }
        if p != .none && p != .blizzard && [.snow, .heavySnow, .sleet].contains(p) == false || p == .freezingRain { // drops sliding on the glass
            NSColor(white: 1, alpha: 0.35).setFill()
            for i in 0..<(p == .drizzle ? 18 : 12) { let x = glass.minX + CGFloat((i*53) % 100)/100*glass.width, y = glass.minY + ((CGFloat((i*29) % 100)/100 - t*0.01*CGFloat(i%3)).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)*glass.height
                oval(x, y, 4, 5) } }
        if bgImage == nil && ([.snow, .heavySnow, .blizzard].contains(p) || (winterSnow && p == .none)) { NSColor.white.setFill(); NSRect(x: glass.minX, y: glass.minY, width: glass.width, height: 6).fill() }
        // fog / dust haze
        if w.fog { let a: CGFloat = w.visibility < 500 ? 0.65 : 0.45
            NSColor(white: 1, alpha: a).setFill(); glass.fill(using: .sourceOver)
            NSColor(white: 1, alpha: 0.25).setFill(); for i in 0..<3 { let x = glass.minX + ((CGFloat(i)*90 + t*5).truncatingRemainder(dividingBy: glass.width + 120)) - 60; oval(x, glass.minY + 40 + CGFloat(i)*35, 140, 25) } }
        if w.yellowDust { rgb(0.85, 0.7, 0.4, 0.35).setFill(); glass.fill(using: .sourceOver)
            rgb(0.8, 0.65, 0.35, 0.5).setFill(); for q in parts.prefix(40) { oval(glass.minX + q.0*glass.width, glass.minY + (1 - q.1)*glass.height, 1.5, 1.5) } }
        else if w.fineDust { rgb(0.6, 0.58, 0.52, 0.3).setFill(); glass.fill(using: .sourceOver) }
        // condensation / frost on the glass
        if w.humidity >= 85 && w.temp < 14 { NSColor(white: 1, alpha: 0.18).setFill(); glass.fill(using: .sourceOver)
            NSColor(white: 1, alpha: 0.3).setFill(); for i in 0..<40 { oval(glass.minX + CGFloat((i*61) % 100)/100*glass.width, glass.minY + CGFloat((i*43) % 100)/100*glass.height, 2.5, 2.5) } }
        if w.temp <= 0 || p == .freezingRain {
            let fr = NSGradient(colors: [NSColor(white: 1, alpha: 0.75), NSColor(white: 1, alpha: 0)])!
            for c in [NSPoint(x: glass.minX, y: glass.minY), NSPoint(x: glass.maxX, y: glass.minY), NSPoint(x: glass.minX, y: glass.maxY), NSPoint(x: glass.maxX, y: glass.maxY)] {
                fr.draw(fromCenter: c, radius: 0, toCenter: c, radius: w.temp <= -5 ? 70 : 45, options: []) }
            NSColor(white: 1, alpha: 0.55).setStroke(); for i in 0..<10 { let c = NSPoint(x: i % 2 == 0 ? glass.minX : glass.maxX, y: i % 4 < 2 ? glass.minY : glass.maxY)
                let fp = NSBezierPath(); fp.move(to: c); let a = CGFloat(i) * 0.6; fp.line(to: NSPoint(x: c.x + (i % 2 == 0 ? 1 : -1) * (20 + cos(a)*15), y: c.y + (i % 4 < 2 ? 1 : -1) * (20 + sin(a)*15))); fp.lineWidth = 0.8; fp.stroke() } }
        // glare
        if glassTheme { drawGlassReflections(glass, w) }
        NSColor(white: 1, alpha: glassTheme ? 0.0 : 0.10).setFill(); let gl = NSBezierPath(); gl.move(to: NSPoint(x: glass.minX+20, y: glass.maxY)); gl.line(to: NSPoint(x: glass.minX+60, y: glass.maxY)); gl.line(to: NSPoint(x: glass.minX, y: glass.minY+40)); gl.line(to: NSPoint(x: glass.minX, y: glass.maxY-20)); gl.fill()
        NSGraphicsContext.restoreGraphicsState()
        // mullions per window style (clipped to the glass)
        NSGraphicsContext.saveGraphicsState(); glassShape.addClip()
        func bar(_ r: NSRect) { NSColor(white: 0, alpha: 0.10).setFill(); r.offsetBy(dx: 1, dy: -1).fill(); wood.setFill(); NSBezierPath(roundedRect: r, xRadius: R(3), yRadius: R(3)).fill()
            if glassTheme { NSColor(white: 1, alpha: 0.9).setFill(); (r.width < r.height ? NSRect(x: r.minX + 0.6, y: r.minY, width: 1, height: r.height) : NSRect(x: r.minX, y: r.maxY - 1.4, width: r.width, height: 1)).fill() } }
        let gb = glassShape.bounds
        switch windowStyle {
        case 0: bar(NSRect(x: gb.midX-3, y: gb.minY, width: 6, height: gb.height)); bar(NSRect(x: gb.minX, y: gb.midY-3, width: gb.width, height: 6))
        case 1: break
        case 2, 5: let bw: CGFloat = windowStyle == 5 ? 4 : 5
            bar(NSRect(x: gb.midX-bw/2, y: gb.minY, width: bw, height: gb.height)); bar(NSRect(x: gb.minX, y: gb.maxY - gb.width/2 - bw/2, width: gb.width, height: bw))
            for a in [45.0, 135.0] as [CGFloat] { let p0 = NSPoint(x: gb.midX, y: gb.maxY - gb.width/2); let l = NSBezierPath(); l.move(to: p0); l.line(to: NSPoint(x: p0.x + cos(a * .pi/180)*gb.width, y: p0.y + sin(a * .pi/180)*gb.width)); l.lineWidth = windowStyle == 5 ? 3.2 : 4; wood.setStroke(); l.stroke()
                if windowStyle == 5 { NSColor(white: 1, alpha: 0.8).setStroke(); l.lineWidth = 0.8; l.stroke() } }
        case 3: NSColor(white: 1, alpha: 0.08).setStroke(); let ring = NSBezierPath(ovalIn: gb.insetBy(dx: 3, dy: 3)); ring.lineWidth = 3; ring.stroke()
        default: // 창호지 lattice with soft paper
            NSColor(calibratedRed: 1, green: 0.98, blue: 0.92, alpha: 0.16).setFill(); gb.fill(using: .sourceOver)
            for i in 1..<4 { bar(NSRect(x: gb.minX + gb.width * CGFloat(i)/4 - 1.5, y: gb.minY, width: 3, height: gb.height)) }
            for j in 1..<6 { bar(NSRect(x: gb.minX, y: gb.minY + gb.height * CGFloat(j)/6 - 1.5, width: gb.width, height: 3)) }
        }
        NSGraphicsContext.restoreGraphicsState()
        if let px = sunPatchCenter, w.light > 0 { let a = CGFloat(w.light)
            let beamCol = mix(rgb(1, 0.95, 0.6), rgb(1, 0.65, 0.35), w.golden)
            beamCol.withAlphaComponent(0.08*a).setFill()
            let beam = NSBezierPath(); beam.move(to: NSPoint(x: px - patchW/2 + 20, y: glass.maxY)); beam.line(to: NSPoint(x: px + patchW/2 + 20, y: glass.maxY)); beam.line(to: NSPoint(x: px + patchW/2, y: sillTop)); beam.line(to: NSPoint(x: px - patchW/2, y: sillTop)); beam.close(); beam.fill() }
        let sill = NSRect(x: inner.minX-14, y: inner.minY-18, width: inner.width+28, height: 14)
        if glassTheme { drawGlassSill(sill) } else {
        NSColor(white: 0, alpha: 0.14).setFill(); NSBezierPath(roundedRect: sill.offsetBy(dx: 0, dy: -3), xRadius: R(6), yRadius: R(6)).fill()
        NSGradient(starting: woodLo, ending: woodHi)!.draw(in: NSBezierPath(roundedRect: sill, xRadius: R(6), yRadius: R(6)), angle: 90)
        woodHi.withAlphaComponent(0.8).setFill(); NSBezierPath(roundedRect: NSRect(x: sill.minX + 3, y: sill.maxY - 2.5, width: sill.width - 6, height: 1.5), xRadius: 1, yRadius: 1).fill() }
        if alwaysInfo { drawInfo(w) }
        // (no plate on the sill: the soft beam alone shows the sunny spot)
    }
}

extension WeatherView {
    func drawGlassFrame(_ outer: NSRect) {
        let fr = windowShape(outer, 0)
        withShadow(rgb(0.18, 0.1, 0.35, 0.45), blur: 16, dy: -7) { rgb(0.9, 0.88, 0.97, 0.92).setFill(); fr.fill() }
        NSGradient(colors: [rgb(0.97, 0.96, 0.99, 0.96), rgb(0.85, 0.82, 0.9, 0.95), rgb(0.64, 0.6, 0.72, 0.97)], atLocations: [0, 0.45, 1], colorSpace: .deviceRGB)!.draw(in: fr, angle: -65)
        // soft 3D: top-left sheen and inner glow along the rim
        NSGraphicsContext.saveGraphicsState(); fr.addClip()
        NSGradient(colors: [NSColor(white: 1, alpha: 0.7), NSColor(white: 1, alpha: 0)])!.draw(fromCenter: NSPoint(x: outer.minX + 30, y: outer.maxY - 40), radius: 0, toCenter: NSPoint(x: outer.minX + 30, y: outer.maxY - 40), radius: 140, options: [])
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: 1, alpha: 0.9).setStroke(); let rim = windowShape(outer, 1.2); rim.lineWidth = 1.4; rim.stroke()
        rgb(0.55, 0.5, 0.72, 0.35).setStroke(); let inR = windowShape(outer, 11.3); inR.lineWidth = 1.6; inR.stroke()     // bevel into the recess
        NSColor(white: 1, alpha: 0.85).setStroke(); let inR2 = windowShape(outer, 9.6); inR2.lineWidth = 1; inR2.stroke()
    }
    func drawGlowSun(_ c: NSPoint, golden: Double, dim: Double) {
        let warm = mix(rgb(1, 0.94, 0.7), rgb(1, 0.7, 0.45), golden), a = CGFloat(1 - 0.6 * dim)
        // warm light wash across the sky
        NSGradient(colors: [warm.withAlphaComponent(0.35 * a), warm.withAlphaComponent(0)])!.draw(fromCenter: c, radius: 0, toCenter: c, radius: 190, options: [])
        let pulse = 3 * sin(t * 1.5)
        NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.97, blue: 0.85, alpha: 0.9 * a), warm.withAlphaComponent(0.4 * a), warm.withAlphaComponent(0)], atLocations: [0, 0.4, 1], colorSpace: .deviceRGB)!.draw(fromCenter: c, radius: 0, toCenter: c, radius: 52 + pulse, options: [])
        let disc = NSBezierPath(ovalIn: NSRect(x: c.x - 20, y: c.y - 20, width: 40, height: 40))
        withShadow(warm.withAlphaComponent(0.9 * a), blur: 14) { mix(rgb(1, 0.95, 0.72), rgb(1, 0.75, 0.5), golden).withAlphaComponent(a).setFill(); disc.fill() }
        NSGradient(colors: [NSColor(calibratedRed: 1, green: 1, blue: 0.94, alpha: a), mix(rgb(1, 0.9, 0.6), rgb(1, 0.66, 0.4), golden).withAlphaComponent(a)])!.draw(in: disc, relativeCenterPosition: NSPoint(x: -0.3, y: 0.35))
    }
    func drawGlassReflections(_ g: NSRect, _ w: Wx) {
        let a: CGFloat = w.isDay ? 1 : 0.5
        for (x0, wd, al) in [(0.08, 0.16, 0.22), (0.3, 0.06, 0.16), (0.62, 0.1, 0.12)] as [(CGFloat, CGFloat, CGFloat)] {
            let p = NSBezierPath(); let x = g.minX + g.width * x0, ww = g.width * wd
            p.move(to: NSPoint(x: x + 70, y: g.maxY)); p.line(to: NSPoint(x: x + 70 + ww, y: g.maxY)); p.line(to: NSPoint(x: x + ww - 40, y: g.minY)); p.line(to: NSPoint(x: x - 40, y: g.minY)); p.close()
            NSGradient(colors: [NSColor(white: 1, alpha: al * a), NSColor(white: 1, alpha: 0.02)])!.draw(in: p, angle: -90) }
        // inner glow at the glass edge
        let edge = windowShape(innerRect.insetBy(dx: -6, dy: -6), 12); edge.lineWidth = 5; NSColor(white: 1, alpha: 0.18 * a).setStroke(); edge.stroke()
    }
    func drawGlassSill(_ sill0: NSRect) {
        let sill = NSRect(x: sill0.minX - 4, y: sill0.minY, width: sill0.width + 8, height: sill0.height - 2)
        let p = NSBezierPath(roundedRect: sill, xRadius: 4, yRadius: 4)
        withShadow(rgb(0.15, 0.1, 0.3, 0.45), blur: 10, dy: -5) { rgb(0.86, 0.84, 0.93, 1).setFill(); p.fill() }
        NSGradient(colors: [rgb(0.74, 0.71, 0.84), rgb(0.88, 0.86, 0.95), rgb(0.97, 0.96, 1)], atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!.draw(in: p, angle: 90)
        NSColor(white: 1, alpha: 0.95).setFill(); NSBezierPath(roundedRect: NSRect(x: sill.minX + 2, y: sill.maxY - 1.6, width: sill.width - 4, height: 1.2), xRadius: 0.6, yRadius: 0.6).fill()
    }
    /// One poetic Korean line from the weather / season / time
    var poeticLine: String {
        let w = wx, p = w.precip, s = w.season
        switch p {
        case .storm: return "천둥이 우르릉, 창문 꼭 닫아요"
        case .heavyRain: return "빗줄기가 세차게 쏟아져요"
        case .rain: return "빗방울이 톡톡 창을 두드려요"
        case .drizzle: return "보슬비가 살며시 내려요"
        case .freezingRain: return "길이 얼어요, 조심조심"
        case .sleet: return "눈과 비가 섞여 내려요"
        case .snow, .heavySnow: return "하얀 눈이 소복소복 쌓여요"
        case .blizzard: return "눈보라가 휘몰아쳐요"
        case .none: break
        }
        if w.fog { return "안개가 포근히 내려앉았어요" }
        if w.yellowDust { return "황사로 하늘이 뿌예요" }
        if w.fineDust { return "공기가 탁해요, 창문은 잠시 닫아요" }
        if !w.isDay { return w.clouds < 0.5 ? "별이 반짝이는 고요한 밤" : "구름 덮인 조용한 밤이에요" }
        if w.golden > 0.3 { return w.hour < 12 ? "아침 햇살이 번져요" : "노을이 곱게 물들어요" }
        if w.temp >= 30 { return "햇볕이 쨍쨍, 물 많이 마셔요" }
        if w.temp <= 0 { return "손이 시린 날이에요" }
        if w.wind >= 15 || (s == 2 && w.clouds > 0.1) { return ["꽃바람이 살랑여요", "시원한 바람이 불어와요", "가을바람이 불어요", "찬바람이 쌩쌩 불어요"][s] }
        if w.clouds >= 0.9 { return "구름이 하늘을 덮었어요" }
        if w.clouds > 0.3 { return "구름이 느릿느릿 흘러가요" }
        return ["봄볕이 따사로워요", "여름 햇살이 반짝여요", "가을 하늘이 높고 맑아요", "포근한 겨울 햇살이에요"][s]
    }
    /// Always-on weather text at the top-right, outside the glass. Keeps a fixed minimum on-screen size.
    func drawInfo(_ w: Wx) {
        let sc = sceneScale(self)
        func u(_ design: CGFloat, min pt: CGFloat) -> CGFloat { max(design, pt / sc) }      // scene units honoring a min point size
        let ink = NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.93, alpha: 1)
        let sh = NSShadow(); sh.shadowColor = NSColor(calibratedRed: 0.1, green: 0.06, blue: 0.22, alpha: 0.55); sh.shadowBlurRadius = 3 / sc; sh.shadowOffset = NSSize(width: 0, height: -0.5 / sc)
        let right = bounds.maxX - 8, top = bounds.maxY - 6
        let f1 = u(11, min: 10), f2 = u(34, min: 20), f3 = u(11, min: 10)
        let a1: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: f1, weight: .regular), .foregroundColor: ink, .shadow: sh]
        let a2: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: f2, weight: .thin), .foregroundColor: ink, .shadow: sh, .kern: -0.5]
        let a3: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: f3, weight: .light), .foregroundColor: ink.withAlphaComponent(0.92), .shadow: sh]
        let roomy = sc >= 0.9   // at small sizes use a shorter headline
        let head = ((roomy ? "현재 날씨: " : "") + w.desc.components(separatedBy: " · ")[0]) as NSString
        let hs = head.size(withAttributes: a1), iconS = hs.height * 0.95
        var y = top - hs.height
        head.draw(at: NSPoint(x: right - hs.width, y: y), withAttributes: a1)
        withShadow(sh.shadowColor as! NSColor, blur: 3 / sc) { drawSymbol(w.symbol.replacingOccurrences(of: ".fill", with: ""), NSRect(x: right - hs.width - iconS - 6 / sc * 0.6 - 4, y: y + hs.height * 0.05, width: iconS, height: iconS), ink, weight: .light) }
        if let tv = temp {
            let ts = String(format: "%.0f°C", tv) as NSString, tsz = ts.size(withAttributes: a2)
            y -= tsz.height * 0.92; ts.draw(at: NSPoint(x: right - tsz.width, y: y), withAttributes: a2)
            // poetic line only when there is room for it at a readable size
            if sc >= 0.75 { let ps = poeticLine as NSString, psz = ps.size(withAttributes: a3); y -= psz.height + 1; ps.draw(at: NSPoint(x: right - psz.width, y: y), withAttributes: a3) }
        }
    }
}

extension Wx {
    var symbol: String {
        switch precip {
        case .drizzle: return "cloud.drizzle.fill"; case .rain: return "cloud.rain.fill"; case .heavyRain: return "cloud.heavyrain.fill"
        case .freezingRain, .sleet: return "cloud.sleet.fill"; case .snow, .heavySnow: return "cloud.snow.fill"; case .blizzard: return "wind.snow"
        case .storm: return "cloud.bolt.rain.fill"
        case .none:
            if fog { return "cloud.fog.fill" }; if yellowDust || fineDust { return isDay ? "sun.dust.fill" : "moon.haze.fill" }
            if wind >= 30 { return "wind" }
            if clouds >= 0.9 { return "cloud.fill" }; if clouds > 0.1 { return isDay ? "cloud.sun.fill" : "cloud.moon.fill" }
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        }
    }
}
/// Hover card: weather headline, plant line, thin bars with SF Symbols
class CardView: NSView {
    weak var owner: WeatherView?
    var solid = false
    override func draw(_ r: NSRect) {
        guard let o = owner else { return }
        if o.cardMode != .full { drawPill(o); return }
        if !solid { NSColor(white: 0.05, alpha: 0.42).setFill(); NSBezierPath(roundedRect: bounds, xRadius: R(14), yRadius: R(14)).fill() }
        NSColor(white: 1, alpha: 0.08).setStroke(); let edge = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: R(14), yRadius: R(14)); edge.lineWidth = 1; edge.stroke()
        let w = o.wx, city = defaults.string(forKey: "cityName") ?? "서울"
        let title: [NSAttributedString.Key: Any] = [.font: cute(13.5), .foregroundColor: NSColor.white]
        let sub: [NSAttributedString.Key: Any] = [.font: cute(11, .medium), .foregroundColor: NSColor(white: 1, alpha: 0.72)]
        let big: [NSAttributedString.Key: Any] = [.font: cute(17), .foregroundColor: NSColor.white]
        let pad: CGFloat = designRound ? 16 : 13, top = bounds.height - 10 - 19
        let head = (o.debugPresetName.map { "\($0) · " } ?? "") + "\(city) · \(w.desc)" + (debugPreset == nil ? (o.staleMinutes.map { $0 >= 120 ? " · \($0/60)시간 전" : " · \($0)분 전" } ?? "") : "")
        (head as NSString).draw(at: NSPoint(x: pad, y: top), withAttributes: title)
        if let t = o.temp { let ts = String(format: "%.0f°", t) as NSString, sz = ts.size(withAttributes: big)
            ts.draw(at: NSPoint(x: bounds.width - pad - sz.width, y: top - 2), withAttributes: big)
            drawSymbol("thermometer.medium", NSRect(x: bounds.width - pad - sz.width - 12, y: top + 2, width: 9, height: 11), NSColor(white: 1, alpha: 0.7), weight: .regular) }
        guard let (pt, m, h, l) = o.plantInfo?() else { return }
        drawSymbol("leaf.fill", NSRect(x: pad, y: 33, width: 11, height: 10), NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.55, alpha: 1))
        (pt as NSString).draw(at: NSPoint(x: pad + 16, y: 30), withAttributes: sub)
        let mc = m > 1 ? Palette.soggy : m < 0.25 ? Palette.dry : Palette.water
        let colW = (bounds.width - pad*2 + 8) / 3
        for (k, (sym, v, col)) in [("drop.fill", min(m, 1.0), mc), ("heart.fill", h, Palette.heart), ("sun.max.fill", l, Palette.sun)].enumerated() {
            let x = pad + CGFloat(k) * colW
            drawSymbol(sym, NSRect(x: x, y: 10, width: 11, height: 10), col)
            let track = NSRect(x: x + 16, y: 13.5, width: colW - 22 - (k == 0 && m > 1 ? 11 : 0), height: 3)
            NSColor(white: 1, alpha: 0.16).setFill(); NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()
            col.setFill(); NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: max(3, track.width * CGFloat(max(0, min(1, v)))), height: 3), xRadius: 1.5, yRadius: 1.5).fill()
            if k == 0 && m > 1 { drawSymbol("exclamationmark.triangle.fill", NSRect(x: track.maxX + 2, y: 10.5, width: 9, height: 9), Palette.dry) }
        }
    }
    /// Compact pill: [weather symbol] 18° [health dot] — 13pt semibold, sized in screen points
    func drawPill(_ o: WeatherView) {
        let r = bounds.height / 2
        NSColor(white: 0.05, alpha: 0.5).setFill(); NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r).fill()
        NSColor(white: 1, alpha: 0.1).setStroke(); let e = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: r, yRadius: r); e.stroke()
        let f: [NSAttributedString.Key: Any] = [.font: cute(14), .foregroundColor: NSColor.white]
        let ts = (o.temp.map { String(format: "%.0f°", $0) } ?? "–") as NSString, sz = ts.size(withAttributes: f)
        var x: CGFloat = 9
        if o.cardMode == .mid { drawSymbol(o.wx.symbol, NSRect(x: x, y: bounds.midY - 7, width: 16, height: 14), .white, weight: .medium); x += 21 }
        else { drawSymbol("thermometer.medium", NSRect(x: x, y: bounds.midY - 6.5, width: 9, height: 13), NSColor(white: 1, alpha: 0.8), weight: .regular); x += 12 }
        ts.draw(at: NSPoint(x: x, y: bounds.midY - sz.height / 2), withAttributes: f); x += sz.width + 8
        if o.cardMode == .mid, let (_, m, h, _) = o.plantInfo?(), h > 0 {
            let col = h > 0.6 ? Palette.water.blended(withFraction: 0.5, of: NSColor.systemGreen)! : h > 0.3 ? Palette.dry : Palette.heart
            drawSymbol("leaf.fill", NSRect(x: x, y: bounds.midY - 6, width: 12, height: 12), col)
            if m < 0.25 || m > 1 { drawSymbol("drop.fill", NSRect(x: x + 15, y: bounds.midY - 5.5, width: 9, height: 11), m > 1 ? Palette.soggy : Palette.dry) }
        }
    }
}

/// Floating, non-activating, click-through bubble showing the full card outside the widget
class BubblePanel: NSPanel {
    let bubbleView: BubbleView
    init(owner: WeatherView) {
        bubbleView = BubbleView(owner: owner)
        super.init(contentRect: NSRect(origin: .zero, size: bubbleView.frame.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false; backgroundColor = .clear; hasShadow = true; ignoresMouseEvents = true; hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        contentView = bubbleView
    }
    override var canBecomeKey: Bool { false }
    func show(alpha: CGFloat, near wf: NSRect) {
        if alpha <= 0.01 { orderOut(nil); return }
        let vf = (screen ?? NSScreen.screens.first { $0.frame.intersects(wf) } ?? NSScreen.main)!.visibleFrame
        let s = frame.size, gap: CGFloat = 4
        var o: NSPoint, side: BubbleView.Side
        if wf.maxY + gap + s.height <= vf.maxY { side = .below; o = NSPoint(x: wf.midX - s.width/2, y: wf.maxY + gap) }        // bubble above widget, pointer at bottom
        else if wf.minY - gap - s.height >= vf.minY { side = .above; o = NSPoint(x: wf.midX - s.width/2, y: wf.minY - gap - s.height) }
        else if wf.maxX + gap + s.width <= vf.maxX { side = .left; o = NSPoint(x: wf.maxX + gap, y: wf.maxY - s.height - 20) }
        else { side = .right; o = NSPoint(x: wf.minX - gap - s.width, y: wf.maxY - s.height - 20) }
        o.x = min(max(o.x, vf.minX + 4), vf.maxX - s.width - 4); o.y = min(max(o.y, vf.minY + 4), vf.maxY - s.height - 4)
        // pointer aims at widget center
        bubbleView.side = side; bubbleView.pointerAt = side == .below || side == .above ? wf.midX - o.x : wf.maxY - 40 - o.y
        setFrameOrigin(o); alphaValue = alpha; bubbleView.needsDisplay = true; bubbleView.card.needsDisplay = true
        if !isVisible { orderFront(nil) }
    }
}
class BubbleView: NSView {
    enum Side { case below, above, left, right }   // where the pointer sits on the bubble
    var side: Side = .below; var pointerAt: CGFloat = 140
    let card = CardView(frame: .zero); static let P: CGFloat = 8
    init(owner: WeatherView) {
        let s = WeatherView.cardSize
        super.init(frame: NSRect(x: 0, y: 0, width: s.width + 2*BubbleView.P, height: s.height + 2*BubbleView.P))
        card.owner = owner; card.solid = true; card.frame = NSRect(x: BubbleView.P, y: BubbleView.P, width: s.width, height: s.height); addSubview(card)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ r: NSRect) {
        let b = card.frame, P = BubbleView.P, path = NSBezierPath(roundedRect: b, xRadius: R(14), yRadius: R(14))
        let t = NSBezierPath()
        switch side {
        case .below: let x = min(max(pointerAt, b.minX + 16), b.maxX - 16); t.move(to: NSPoint(x: x - 7, y: b.minY)); t.line(to: NSPoint(x: x, y: b.minY - P + 1)); t.line(to: NSPoint(x: x + 7, y: b.minY))
        case .above: let x = min(max(pointerAt, b.minX + 16), b.maxX - 16); t.move(to: NSPoint(x: x - 7, y: b.maxY)); t.line(to: NSPoint(x: x, y: b.maxY + P - 1)); t.line(to: NSPoint(x: x + 7, y: b.maxY))
        case .left: let y = min(max(pointerAt, b.minY + 12), b.maxY - 12); t.move(to: NSPoint(x: b.minX, y: y - 7)); t.line(to: NSPoint(x: b.minX - P + 1, y: y)); t.line(to: NSPoint(x: b.minX, y: y + 7))
        case .right: let y = min(max(pointerAt, b.minY + 12), b.maxY - 12); t.move(to: NSPoint(x: b.maxX, y: y - 7)); t.line(to: NSPoint(x: b.maxX + P - 1, y: y)); t.line(to: NSPoint(x: b.maxX, y: y + 7))
        }
        t.close(); path.append(t)
        NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 0.9).setFill(); path.fill()
    }
}
