import AppKit
import CoreText
let defaults = UserDefaults.standard
func dayIndex(_ d: Date = Date()) -> Int { Int(floor(d.timeIntervalSince1970 / 86400 + 9.0/24)) }
/// Outdoor light 0...1 from the real weather (set by WeatherView)
var outdoorLight: Double = { let h = Calendar.current.component(.hour, from: Date()); return (7..<18).contains(h) ? 0.7 : 0 }()
var weatherKnown = false
let BASE = NSSize(width: 320, height: 360)   // logical scene size; the window scales it
var outdoorTemp: Double? = nil
let MIN_TEMP: [String: Double] = ["basil": 10, "tomato": 10, "sunflower": 8, "lettuce": 4, "rose": 0, "echeveria": 5]
/// Real sunrise/sunset (updated from Open-Meteo); defaults for Seoul in autumn
var sunriseT: Date = Calendar.current.date(bySettingHour: 6, minute: 35, second: 0, of: Date())!
var sunsetT: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
var windSpeed: Double = 0, pm10: Double = 0, pm25: Double = 0
/// Sun patch on the sill: x fraction across the glass between real sunrise and sunset (nil at night)
func sunPatchFrac(_ d: Date = Date()) -> Double? {
    let cal = Calendar.current
    func tod(_ x: Date) -> Double { let c = cal.dateComponents([.hour, .minute], from: x); return Double(c.hour!) + Double(c.minute!)/60 }
    let h = tod(d), a = tod(sunriseT) + 0.3, b = tod(sunsetT) - 0.3
    return (a...b).contains(h) ? (h - a) / (b - a) : nil
}

class ToyWindow: NSWindow {
    let key: String
    init(key: String, size: NSSize, defaultOrigin: NSPoint, view: NSView) {
        self.key = key
        var origin = defaultOrigin
        if let s = defaults.string(forKey: "pos.\(key)") { let p = NSPointFromString(s); if p != .zero { origin = p } }
        super.init(contentRect: NSRect(origin: origin, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
        contentView = view
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            guard let self else { return }; defaults.set(NSStringFromPoint(self.frame.origin), forKey: "pos.\(self.key)") }
    }
}
func label(_ s: String, at p: NSPoint, size: CGFloat = 11) {
    let sh = NSShadow(); sh.shadowColor = .black; sh.shadowBlurRadius = 3
    (s as NSString).draw(at: p, withAttributes: [.font: cute(size), .foregroundColor: NSColor.white, .shadow: sh])
}

/// Tinted SF Symbol drawn into a rect
func drawSymbol(_ name: String, _ r: NSRect, _ color: NSColor, weight: NSFont.Weight = .semibold) {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
    let cfg = NSImage.SymbolConfiguration(pointSize: r.height, weight: weight).applying(.init(paletteColors: [color]))
    guard let img = base.withSymbolConfiguration(cfg) else { return }
    let s = img.size, k = min(r.width / s.width, r.height / s.height)
    img.draw(in: NSRect(x: r.midX - s.width*k/2, y: r.midY - s.height*k/2, width: s.width*k, height: s.height*k))
}
enum Palette {
    static let water = NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.98, alpha: 1)
    static let dry = NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.3, alpha: 1)
    static let soggy = NSColor(calibratedRed: 0.22, green: 0.38, blue: 0.82, alpha: 1)
    static let heart = NSColor(calibratedRed: 1, green: 0.45, blue: 0.45, alpha: 1)
    static let sun = NSColor(calibratedRed: 1, green: 0.8, blue: 0.35, alpha: 1)
    static let cold = NSColor(calibratedRed: 0.55, green: 0.8, blue: 1, alpha: 1)
    static let wind = NSColor(calibratedRed: 0.6, green: 0.66, blue: 0.72, alpha: 1)
}

/// On-screen points per scene unit (scene is vector-scaled inside the window)
func sceneScale(_ v: NSView) -> CGFloat { max(0.05, v.convert(NSSize(width: 1, height: 0), to: nil).width) }

/// Bundled OFL font "Jua" (주아) registered for this process only; falls back to SF Pro Rounded
let cuteFontName = "Jua-Regular"
let cuteFontLoaded: Bool = {
    let candidates = [Bundle.main.url(forResource: "Jua-Regular", withExtension: "ttf"),
                      URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("../Resources/Jua-Regular.ttf").standardized]
    for case let u? in candidates where FileManager.default.fileExists(atPath: u.path) {
        var err: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(u as CFURL, .process, &err) || NSFont(name: cuteFontName, size: 12) != nil { break }
    }
    return NSFont(name: cuteFontName, size: 12) != nil
}()
func cute(_ size: CGFloat, _ weight: NSFont.Weight = .semibold) -> NSFont {
    if cuteFontLoaded, let f = NSFont(name: cuteFontName, size: size) { return f }
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}

// MARK: design settings (persisted; contact sheets may override in memory)
var designRound: Bool = defaults.object(forKey: "roundStyle") as? Bool ?? true
var potStyle: Int = defaults.object(forKey: "potStyle") as? Int ?? 6
var windowStyle: Int = defaults.object(forKey: "windowStyle") as? Int ?? 5
/// Always-on weather text + growth gauge (default on for the glass theme); contact sheets may override
var alwaysInfoOverride: Bool? = nil
var alwaysInfo: Bool { alwaysInfoOverride ?? (defaults.object(forKey: "alwaysInfo") as? Bool ?? (windowStyle == 5)) }
/// Growth gauge opacity: follows the hover card fade
var gaugeAlpha: CGFloat = 0
var glassTheme: Bool { windowStyle == 5 }
/// Soft drop shadow helper
func withShadow(_ c: NSColor, blur: CGFloat, dy: CGFloat = 0, _ f: () -> Void) { NSGraphicsContext.saveGraphicsState(); let s = NSShadow(); s.shadowColor = c; s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: dy); s.set(); f(); NSGraphicsContext.restoreGraphicsState() }
let POT_NAMES = ["테라코타", "하얀 도자기", "파스텔 동글이", "라탄 바구니", "고양이 화분", "콘크리트", "말랑 도자기"]
let WINDOW_NAMES = ["나무 4칸 창", "모던 화이트", "아치형 유럽 창", "둥근 선창", "한옥 창호지 창", "글래스 아치"]
let appSupportDir: URL = { let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DesktopToys"); try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true); return d }()
var bgImage: NSImage? = defaults.string(forKey: "bgPath").flatMap { NSImage(contentsOfFile: $0) }
/// Corner radius for UI chrome: crisp vs. big & pill-like
func R(_ big: CGFloat) -> CGFloat { designRound ? big : 2 }
/// Window outline for the current window style, inset by `d`
func windowShape(_ r0: NSRect, _ d: CGFloat) -> NSBezierPath {
    let r = r0.insetBy(dx: d, dy: d)
    switch windowStyle {
    case 3: let s = min(r.width, r.height); return NSBezierPath(ovalIn: NSRect(x: r.midX - s/2, y: r.maxY - s, width: s, height: s))
    case 2, 5:
        let rad = r.width / 2, br = max(0, R(14) - d * 0.4), p = NSBezierPath()
        p.move(to: NSPoint(x: r.minX, y: r.maxY - rad)); p.line(to: NSPoint(x: r.minX, y: r.minY + br))
        p.appendArc(withCenter: NSPoint(x: r.minX + br, y: r.minY + br), radius: br, startAngle: 180, endAngle: 270)
        p.line(to: NSPoint(x: r.maxX - br, y: r.minY)); p.appendArc(withCenter: NSPoint(x: r.maxX - br, y: r.minY + br), radius: br, startAngle: 270, endAngle: 360)
        p.line(to: NSPoint(x: r.maxX, y: r.maxY - rad)); p.appendArc(withCenter: NSPoint(x: r.midX, y: r.maxY - rad), radius: rad, startAngle: 0, endAngle: 180); p.close(); return p
    default: let rr = max(designRound ? 4 : 0, R(16) - d * 0.4); return NSBezierPath(roundedRect: r, xRadius: rr, yRadius: rr)
    }
}

/// Korean names for cities returned by IP geolocation (English)
let CITY_KO: [String: String] = ["Seoul": "서울", "Busan": "부산", "Incheon": "인천", "Daegu": "대구", "Daejeon": "대전", "Gwangju": "광주", "Ulsan": "울산", "Sejong": "세종",
    "Suwon": "수원", "Suwon-si": "수원시", "Seongnam": "성남", "Seongnam-si": "성남시", "Goyang": "고양", "Goyang-si": "고양시", "Yongin": "용인", "Yongin-si": "용인시",
    "Bucheon": "부천", "Bucheon-si": "부천시", "Ansan": "안산", "Ansan-si": "안산시", "Anyang": "안양", "Anyang-si": "안양시", "Hwaseong": "화성", "Hwaseong-si": "화성시",
    "Namyangju": "남양주", "Namyangju-si": "남양주시", "Pyeongtaek": "평택", "Pyeongtaek-si": "평택시", "Siheung": "시흥", "Siheung-si": "시흥시", "Gimpo": "김포", "Gimpo-si": "김포시",
    "Paju": "파주", "Paju-si": "파주시", "Uijeongbu": "의정부", "Uijeongbu-si": "의정부시", "Hanam": "하남", "Hanam-si": "하남시", "Gwangmyeong": "광명", "Gwangmyeong-si": "광명시",
    "Gunpo": "군포", "Gunpo-si": "군포시", "Guri": "구리", "Guri-si": "구리시", "Osan": "오산", "Osan-si": "오산시", "Icheon": "이천", "Icheon-si": "이천시",
    "Cheongju": "청주", "Cheongju-si": "청주시", "Cheonan": "천안", "Cheonan-si": "천안시", "Jeonju": "전주", "Jeonju-si": "전주시", "Changwon": "창원", "Changwon-si": "창원시",
    "Gimhae": "김해", "Gimhae-si": "김해시", "Pohang": "포항", "Pohang-si": "포항시", "Gumi": "구미", "Gumi-si": "구미시", "Jinju": "진주", "Jinju-si": "진주시",
    "Chuncheon": "춘천", "Chuncheon-si": "춘천시", "Wonju": "원주", "Wonju-si": "원주시", "Gangneung": "강릉", "Gangneung-si": "강릉시", "Mokpo": "목포", "Yeosu": "여수",
    "Suncheon": "순천", "Gyeongju": "경주", "Gyeongju-si": "경주시", "Jeju": "제주", "Jeju City": "제주시", "Jeju-si": "제주시", "Seogwipo": "서귀포", "Seogwipo-si": "서귀포시"]
func koreanCity(_ s: String) -> String { CITY_KO[s] ?? CITY_KO[s.replacingOccurrences(of: " City", with: "")] ?? s }
