import AppKit
import ServiceManagement
import UniformTypeIdentifiers
/// One widget: weather window + pot on the sill (pot slides horizontally, light depends on position)
func makeScene() -> (WeatherView, PlantView) {
    let wv = WeatherView(frame: NSRect(origin: .zero, size: BASE))
    let pw: CGFloat = 120
    let pv = PlantView(frame: NSRect(x: 0, y: wv.sillTop - 22, width: pw, height: 240))
    let g = wv.glassRect
    let clamp: (CGFloat) -> CGFloat = { let g = wv.glassRect; return min(max($0, g.minX - 22), g.maxX - pw + 22) }
    func update() {
        // light depends on whether the pot sits in the moving sun patch on the sill
        if let px = wv.sunPatchCenter { let d = abs(pv.frame.midX - px) / (wv.patchW / 2 + 25); pv.posFactor = d < 0.6 ? 1 : max(0.3, 1 - 0.7 * Double((d - 0.6) / 0.6)) } else { pv.posFactor = 1 }
        let s = pv.sp.map { _ in "\(pv.shownEmoji) \(pv.shownSpeciesName) · \(pv.stageName) · 💧\(Int(min(pv.st.moisture, 1.6)*100))% ❤️\(Int(pv.st.health*100))% ☀️\(Int(pv.posFactor*100))%" + (pv.isCold && !(pv.st.covered ?? false) ? " 🥶" : "") + ((pv.st.covered ?? false) ? " 🫙" : "") } ?? "🪴 화분을 클릭해 씨앗을 심어보세요"
        wv.plantLabel = s
    }
    let saved = defaults.object(forKey: "potX") as? Double ?? Double(g.midX - pw/2)
    pv.setFrameOrigin(NSPoint(x: clamp(CGFloat(saved)), y: pv.frame.origin.y))
    pv.dragClamp = clamp
    pv.onMove = { defaults.set(Double(pv.frame.origin.x), forKey: "potX"); update(); pv.updateTooltip() }
    pv.onChange = { update() }
    wv.plantInfo = { pv.sp.map { ((pv.st.name != nil ? "\(pv.plantName) · " : "") + (pv.variantName ?? "\(pv.shownSpeciesName) · \(pv.stageName)") + (pv.st.dead ? "" : String(format: " · %.0f일째", pv.st.realDays)), pv.st.moisture, pv.st.health, pv.posFactor * outdoorLight / max(0.01, $0.lightNeed * 2)) } ?? ("화분을 클릭해 씨앗을 심어보세요", 0, 0, 0) }
    wv.addSubview(pv, positioned: .below, relativeTo: wv.card); update(); pv.updateTooltip()
    return (wv, pv)
}
/// Container that vector-scales the 320×360 scene to any window size
class ScaleView: NSView {
    let scene: NSView
    init(scene: NSView, size: NSSize) { self.scene = scene; super.init(frame: NSRect(origin: .zero, size: size)); addSubview(scene); layoutScene(); addSubview(grip) }
    required init?(coder: NSCoder) { fatalError() }
    lazy var grip = GripView(frame: .zero)
    override var mouseDownCanMoveWindow: Bool { true }
    func layoutScene() { scene.frame = bounds; scene.bounds = NSRect(origin: .zero, size: BASE); grip.frame = NSRect(x: bounds.maxX - 18, y: 0, width: 18, height: 18); (scene as? WeatherView)?.layoutCard() }
    override func setFrameSize(_ s: NSSize) { super.setFrameSize(s); layoutScene() }
}
/// Bottom-right corner handle: drag to resize with locked aspect ratio
class GripView: NSView {
    var start: NSPoint = .zero; var startFrame: NSRect = .zero
    override var mouseDownCanMoveWindow: Bool { false }
    override func draw(_ r: NSRect) { NSColor(white: 1, alpha: 0.55).setStroke()
        for k in 0..<3 { let p = NSBezierPath(); let o = CGFloat(k)*4 + 4; p.move(to: NSPoint(x: bounds.maxX - o, y: 2)); p.line(to: NSPoint(x: bounds.maxX - 2, y: o)); p.lineWidth = 1.2; p.stroke() } }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func mouseDown(with e: NSEvent) { start = NSEvent.mouseLocation; startFrame = window!.frame }
    override func mouseDragged(with e: NSEvent) {
        let m = NSEvent.mouseLocation, dx = m.x - start.x, dy = start.y - m.y
        let sc = min(1.6, max(0.35, (startFrame.width + max(dx, dy * BASE.width / BASE.height)) / BASE.width))
        applyScale(window!, sc)
    }
}
func applyScale(_ w: NSWindow, _ sc: CGFloat) {
    let top = w.frame.maxY, sz = NSSize(width: BASE.width * sc, height: BASE.height * sc)
    w.setFrame(NSRect(x: w.frame.minX, y: top - sz.height, width: sz.width, height: sz.height), display: true)
    defaults.set(Double(sc), forKey: "scale")
}
let CITIES: [(String, Double, Double)] = [("서울", 37.5665, 126.978), ("인천", 37.4563, 126.7052), ("수원", 37.2636, 127.0286), ("춘천", 37.8813, 127.7298), ("강릉", 37.7519, 128.8761), ("대전", 36.3504, 127.3845), ("대구", 35.8714, 128.6014), ("광주", 35.1595, 126.8526), ("부산", 35.1796, 129.0756), ("울산", 35.5384, 129.3114), ("제주", 33.4996, 126.5312)]
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!; var win: ToyWindow!; var pv: PlantView!; var accelItem: NSMenuItem!; var weatherView: WeatherView!; var debugItem: NSMenuItem!; var loginItem: NSMenuItem!; var cityMenu: NSMenu!; var speedMenu: NSMenu!; var dexMenu: NSMenu!; var designMenu: NSMenu!; var autoUpdItem: NSMenuItem!; var jelly: JellyController!; var jellyMenu: NSMenu!
    func applicationDidFinishLaunching(_ n: Notification) {
        let scr = NSScreen.main!.visibleFrame
        let (wv, p) = makeScene(); pv = p
        let sc = CGFloat(defaults.object(forKey: "scale") as? Double ?? 0.6)
        let size = NSSize(width: BASE.width * sc, height: BASE.height * sc)
        win = ToyWindow(key: "scene", size: size, defaultOrigin: NSPoint(x: scr.maxX - size.width - 40, y: scr.maxY - size.height - 40), view: ScaleView(scene: wv, size: size)); weatherView = wv
        if defaults.object(forKey: "show.window") as? Bool ?? true { win.orderFront(nil) }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🪴"
        let m = NSMenu()
        m.addItem(withTitle: "창문 위젯 보이기/숨기기", action: #selector(tw), keyEquivalent: "w").target = self
        m.addItem(withTitle: "화분 초기화 (다시 심기)", action: #selector(rp), keyEquivalent: "").target = self
        let sizeM = NSMenu(); for (t, v) in [("작게 (60%)", 0.6), ("보통 (80%)", 0.8), ("크게 (100%)", 1.0)] { let it = sizeM.addItem(withTitle: t, action: #selector(setSize(_:)), keyEquivalent: ""); it.target = self; it.representedObject = v }
        m.addItem(withTitle: "크기", action: nil, keyEquivalent: "").submenu = sizeM
        let cityM = NSMenu(); cityMenu = cityM
        for (i, c) in CITIES.enumerated() { let it = cityM.addItem(withTitle: c.0, action: #selector(pickCity(_:)), keyEquivalent: ""); it.target = self; it.tag = i }
        cityM.addItem(.separator()); let ipIt = cityM.addItem(withTitle: "현재 위치 (IP로 찾기)", action: #selector(ipCity), keyEquivalent: ""); ipIt.target = self
        m.addItem(withTitle: "지역", action: nil, keyEquivalent: "").submenu = cityM; refreshCityChecks()
        loginItem = m.addItem(withTitle: "로그인 시 실행", action: #selector(toggleLogin), keyEquivalent: ""); loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let spM = NSMenu(); speedMenu = spM
        for (i, t) in ["실제 (1배)", "빠름 (약 1주)", "아주 빠름 (1~2일)"].enumerated() { let it = spM.addItem(withTitle: t, action: #selector(setSpeed(_:)), keyEquivalent: ""); it.target = self; it.tag = i }
        m.addItem(withTitle: "성장 속도", action: nil, keyEquivalent: "").submenu = spM; refreshSpeed()
        let dM = NSMenu(); designMenu = dM; m.addItem(withTitle: "디자인", action: nil, keyEquivalent: "").submenu = dM; buildDesignMenu()
        let jM = NSMenu(); jellyMenu = jM; m.addItem(withTitle: "🪼 해파리", action: nil, keyEquivalent: "").submenu = jM
        jelly = JellyController(); jelly.start(below: win)
        let dexM = NSMenu(); dexMenu = dexM; m.addItem(withTitle: "📖 도감", action: nil, keyEquivalent: "").submenu = dexM
        accelItem = m.addItem(withTitle: "시간 가속 (1분 = 1일)", action: #selector(ta), keyEquivalent: ""); accelItem.target = self
        accelItem.state = defaults.bool(forKey: "accel") ? .on : .off
        // hidden debug item: shows only while holding ⌥ (Option) with the menu open
        debugItem = NSMenuItem(title: "🐞 날씨 미리보기 순환", action: #selector(cycleWx), keyEquivalent: ""); debugItem.target = self
        debugItem.isAlternate = true; debugItem.keyEquivalentModifierMask = .option
        m.addItem(.separator()); let realIt = m.addItem(withTitle: "실제 날씨로 돌아가기", action: #selector(realWx), keyEquivalent: ""); realIt.target = self; realIt.keyEquivalentModifierMask = []
        m.addItem(debugItem)
        m.addItem(.separator())
        m.addItem(withTitle: "업데이트 확인…", action: #selector(checkUpdate), keyEquivalent: "").target = self
        autoUpdItem = m.addItem(withTitle: "자동으로 업데이트 확인", action: #selector(toggleAutoUpdate), keyEquivalent: ""); autoUpdItem.target = self; autoUpdItem.state = Updater.autoCheck ? .on : .off
        m.addItem(withTitle: "버전 정보", action: #selector(about), keyEquivalent: "").target = self
        let rpM = NSMenu(); m.addItem(withTitle: "제보 · 문의", action: nil, keyEquivalent: "").submenu = rpM
        rpM.addItem(withTitle: "메일로 보내기…", action: #selector(mailReport), keyEquivalent: "").target = self
        rpM.addItem(withTitle: "GitHub 이슈 열기…", action: #selector(openIssues), keyEquivalent: "").target = self
        // automatic update check: shortly after launch, then every 24h
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { if Updater.autoCheck { Updater.check(manual: false) } }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            if Updater.autoCheck && Date().timeIntervalSince1970 - defaults.double(forKey: "lastUpdateCheck") > 86400 { Updater.check(manual: false) } }
        m.addItem(.separator()); m.addItem(withTitle: "DesktopToys 종료", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        item.menu = m; m.delegate = self
    }
    func toggle(_ w: NSWindow, _ k: String) { if w.isVisible { w.orderOut(nil) } else { w.orderFront(nil) }; defaults.set(w.isVisible, forKey: "show.\(k)") }
    @objc func tw() { toggle(win, "window") }
    func refreshCityChecks() { let cur = defaults.string(forKey: "cityName") ?? "서울"; for it in cityMenu.items { it.state = it.title == cur ? .on : .off } }
    func setCity(_ name: String, _ lat: Double, _ lon: Double) { defaults.set(name, forKey: "cityName"); defaults.set(lat, forKey: "lat"); defaults.set(lon, forKey: "lon"); refreshCityChecks(); weatherView.fetch() }
    @objc func pickCity(_ it: NSMenuItem) { let c = CITIES[it.tag]; setCity(c.0, c.1, c.2) }
    @objc func ipCity() {
        URLSession.shared.dataTask(with: URL(string: "https://ipapi.co/json/")!) { d, _, _ in
            guard let d, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let la = (j["latitude"] as? NSNumber)?.doubleValue, let lo = (j["longitude"] as? NSNumber)?.doubleValue else { return }
            let name = koreanCity((j["city"] as? String) ?? "현재 위치")
            DispatchQueue.main.async { self.setCity(name, la, lo) } }.resume()
    }
    func menuWillOpen(_ menu: NSMenu) {
        jellyMenu.removeAllItems(); jelly.fillMenu(jellyMenu, includeToggle: true)
        dexMenu.removeAllItems()
        let dex = (defaults.dictionary(forKey: "dex") as? [String: Int] ?? [:]).sorted { $0.key < $1.key }
        if dex.isEmpty { dexMenu.addItem(withTitle: "아직 수확한 게 없어요", action: nil, keyEquivalent: "").isEnabled = false }
        for (k, v) in dex { dexMenu.addItem(withTitle: "\(k)  ×\(v)", action: nil, keyEquivalent: "").isEnabled = false }
        dexMenu.addItem(.separator()); dexMenu.addItem(withTitle: "모은 종류: \(dex.count)개", action: nil, keyEquivalent: "").isEnabled = false
    }
    func buildDesignMenu() {
        let d = designMenu!; d.removeAllItems()
        func header(_ t: String) { let h = d.addItem(withTitle: t, action: nil, keyEquivalent: ""); h.isEnabled = false }
        func opt(_ t: String, _ on: Bool, _ sel: Selector, _ tag: Int) { let it = d.addItem(withTitle: "   " + t, action: sel, keyEquivalent: ""); it.target = self; it.tag = tag; it.state = on ? .on : .off }
        header("모서리"); opt("각진", !designRound, #selector(setRound(_:)), 0); opt("둥글게", designRound, #selector(setRound(_:)), 1)
        d.addItem(.separator()); header("화분"); for (i, n) in POT_NAMES.enumerated() { opt(n, potStyle == i, #selector(setPot(_:)), i) }
        d.addItem(.separator()); header("창문"); for (i, n) in WINDOW_NAMES.enumerated() { opt(n, windowStyle == i, #selector(setWindow(_:)), i) }
        d.addItem(.separator()); header("배경")
        let b1 = d.addItem(withTitle: "   배경 사진 선택…", action: #selector(pickBG), keyEquivalent: ""); b1.target = self
        let b2 = d.addItem(withTitle: "   기본 풍경으로", action: #selector(clearBG), keyEquivalent: ""); b2.target = self; b2.state = bgImage == nil ? .on : .off
        d.addItem(.separator()); let ai = d.addItem(withTitle: "날씨 정보 항상 표시", action: #selector(toggleInfo), keyEquivalent: ""); ai.target = self; ai.state = alwaysInfo ? .on : .off
    }
    @objc func toggleInfo() { defaults.set(!alwaysInfo, forKey: "alwaysInfo"); designChanged() }
    func designChanged() { if let c = pv.dragClamp { pv.setFrameOrigin(NSPoint(x: c(pv.frame.origin.x), y: pv.frame.origin.y)); pv.onMove?() }; buildDesignMenu(); weatherView.layoutCard(); weatherView.needsDisplay = true; pv.needsDisplay = true; weatherView.bubble.bubbleView.needsDisplay = true }
    @objc func setRound(_ it: NSMenuItem) { designRound = it.tag == 1; defaults.set(designRound, forKey: "roundStyle"); designChanged() }
    @objc func setPot(_ it: NSMenuItem) { potStyle = it.tag; defaults.set(potStyle, forKey: "potStyle"); designChanged() }
    @objc func setWindow(_ it: NSMenuItem) { windowStyle = it.tag; defaults.set(windowStyle, forKey: "windowStyle"); designChanged() }
    @objc func pickBG() {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        let op = NSOpenPanel(); op.allowedContentTypes = [.image]; op.allowsMultipleSelection = false; op.message = "창밖 배경으로 쓸 사진을 골라주세요"
        let ok = op.runModal() == .OK
        NSApp.setActivationPolicy(.accessory)
        guard ok, let u = op.url, let img = NSImage(contentsOf: u) else { return }
        let dst = appSupportDir.appendingPathComponent("background." + (u.pathExtension.isEmpty ? "jpg" : u.pathExtension.lowercased()))
        for old in (try? FileManager.default.contentsOfDirectory(at: appSupportDir, includingPropertiesForKeys: nil)) ?? [] where old.lastPathComponent.hasPrefix("background.") { try? FileManager.default.removeItem(at: old) }
        try? FileManager.default.copyItem(at: u, to: dst)
        defaults.set(dst.path, forKey: "bgPath"); bgImage = NSImage(contentsOf: dst) ?? img; designChanged()
    }
    @objc func clearBG() { defaults.removeObject(forKey: "bgPath"); bgImage = nil; designChanged() }
    @objc func checkUpdate() { Updater.check(manual: true) }
    @objc func toggleAutoUpdate() { defaults.set(!Updater.autoCheck, forKey: "autoUpdate"); autoUpdItem.state = Updater.autoCheck ? .on : .off }
    @objc func about() { Updater.showAbout() }
    @objc func mailReport() { Updater.mailReport() }
    @objc func openIssues() { Updater.openIssues() }
    func refreshSpeed() { for it in speedMenu.items { it.state = it.tag == growthSpeed ? .on : .off } }
    @objc func setSpeed(_ it: NSMenuItem) { defaults.set(it.tag, forKey: "growthSpeed"); refreshSpeed(); pv.updateTooltip() }
    @objc func toggleLogin() {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } } catch { NSLog("login item: \(error)") }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
    @objc func setSize(_ it: NSMenuItem) { applyScale(win, CGFloat(it.representedObject as! Double)) }
    @objc func cycleWx() { debugPreset = ((debugPreset ?? -1) + 1) % Wx.presets.count; weatherView.needsDisplay = true }
    @objc func realWx() { debugPreset = nil; weatherView.needsDisplay = true }
    @objc func rp() { pv.confirmReset() }
    @objc func ta() { let v = !defaults.bool(forKey: "accel"); defaults.set(v, forKey: "accel"); accelItem.state = v ? .on : .off }
}
if let i = CommandLine.arguments.firstIndex(of: "--contact"), i+1 < CommandLine.arguments.count {
    // Contact sheet of weather presets (4 columns)
    let (wv, _) = makeScene(); let ids = Array(Wx.presets.indices).filter { $0 != 12 }
    let cols = 4, rows = (ids.count + cols - 1) / cols, cw: CGFloat = 330, ch: CGFloat = 370
    let img = NSImage(size: NSSize(width: CGFloat(cols)*cw, height: CGFloat(rows)*ch)); img.lockFocus()
    NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.45, alpha: 1).setFill(); NSRect(origin: .zero, size: img.size).fill()
    for (k, id) in ids.enumerated() {
        debugPreset = id; wv.t = 0; for _ in 0..<40 { wv.tick() }
        if Wx.presets[id].1.precip == .storm { wv.flash = 0.9 }
        let r = wv.bitmapImageRepForCachingDisplay(in: wv.bounds)!; wv.cacheDisplay(in: wv.bounds, to: r)
        r.draw(at: NSPoint(x: CGFloat(k % cols)*cw + 5, y: CGFloat(rows - 1 - k / cols)*ch + 5))
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if CommandLine.arguments.contains("--update-test") {
    // Test: compare against latest release; with --install <target.app> also download+verify+swap into target (no relaunch)
    let args = CommandLine.arguments
    print("current:", Updater.currentVersion)
    Updater.fetchLatest { r in
        switch r {
        case .failure(let e): print("fetch failed:", e.localizedDescription); exit(1)
        case .success(let rel):
            print("latest:", rel.version, "newer:", Updater.isNewer(rel.version, than: Updater.currentVersion), "zip:", rel.zipURL)
            if let k = args.firstIndex(of: "--install"), k+1 < args.count {
                Updater.install(rel, target: URL(fileURLWithPath: args[k+1]), relaunch: false) { err in print("install:", err ?? "ok"); exit(err == nil ? 0 : 2) }
            } else { exit(0) }
        }
    }
    RunLoop.main.run()
}
if let i = CommandLine.arguments.firstIndex(of: "--designs"), i+2 < CommandLine.arguments.count {
    // Contact sheet: radius styles, windows, pots, photo background (in-memory settings only)
    let photo = NSImage(contentsOfFile: CommandLine.arguments[i+2])
    struct Cell { var round = true, pot = 0, win = 0, photo = false, pre: Int? = 0, hover = false, title = "" }
    var cells: [Cell] = [Cell(round: false, hover: true, title: "각진"), Cell(round: true, hover: true, title: "둥글게")]
    for (k, n) in WINDOW_NAMES.enumerated() where k > 0 { cells.append(Cell(win: k, pre: [nil, 0, 13, 16, 3][k], title: "창문: " + n)) }
    for (k, n) in POT_NAMES.enumerated() { cells.append(Cell(pot: k, win: k % 2 == 0 ? 0 : 1, title: "화분: " + n)) }
    cells.append(Cell(photo: true, pre: 0, title: "사진 배경 · 맑음")); cells.append(Cell(photo: true, pre: 4, title: "사진 배경 · 폭우")); cells.append(Cell(photo: true, pre: 16, title: "사진 배경 · 밤"))
    let s: CGFloat = 0.7, cw = BASE.width * s + 24, ch = BASE.height * s + 40, cols = 5, rows = (cells.count + cols - 1) / cols
    let img = NSImage(size: NSSize(width: CGFloat(cols) * cw, height: CGFloat(rows) * ch)); img.lockFocus()
    NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1).setFill(); NSRect(origin: .zero, size: img.size).fill()
    for (k, cl) in cells.enumerated() {
        designRound = cl.round; potStyle = cl.pot; windowStyle = cl.win; bgImage = cl.photo ? photo : nil; debugPreset = cl.pre
        let (wv, pv) = makeScene(); pv.st = PlantState(); pv.st.speciesId = "tomato"; pv.st.age = 80; pv.st.health = 1; pv.st.moisture = 0.7; pv.st.variantSeed = 7 + k
        let sv = ScaleView(scene: wv, size: NSSize(width: BASE.width * s, height: BASE.height * s)); sv.grip.isHidden = true
        for _ in 0..<30 { wv.tick() }; wv.layoutCard(); if cl.hover && !wv.external { wv.setHover(1) }
        let ox = CGFloat(k % cols) * cw + 12, oy = CGFloat(rows - 1 - k / cols) * ch + 30
        let r = sv.bitmapImageRepForCachingDisplay(in: sv.bounds)!; sv.cacheDisplay(in: sv.bounds, to: r); r.draw(in: NSRect(x: ox, y: oy, width: sv.bounds.width, height: sv.bounds.height))
        if cl.hover && wv.external { let bv = wv.bubble.bubbleView; bv.side = .below; bv.pointerAt = bv.frame.width/2; let br = bv.bitmapImageRepForCachingDisplay(in: bv.bounds)!; bv.cacheDisplay(in: bv.bounds, to: br)
            br.draw(in: NSRect(x: ox + (sv.bounds.width - bv.frame.width*0.8)/2, y: oy + sv.bounds.height - bv.frame.height*0.8 - 30, width: bv.frame.width*0.8, height: bv.frame.height*0.8)) }
        (cl.title as NSString).draw(at: NSPoint(x: ox, y: oy - 22), withAttributes: [.font: cute(13), .foregroundColor: NSColor.white])
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--fruits"), i+1 < CommandLine.arguments.count {
    // Contact sheet of funny variants: per species 3 commons, 2 rares, 1 legendary
    let cols = 6, cw: CGFloat = 170, ch: CGFloat = 250
    let img = NSImage(size: NSSize(width: CGFloat(cols)*cw, height: CGFloat(SPECIES.count)*ch)); img.lockFocus()
    NSColor(calibratedRed: 0.86, green: 0.9, blue: 0.94, alpha: 1).setFill(); NSRect(origin: .zero, size: img.size).fill()
    for (row, sp) in SPECIES.enumerated() {
        var picks: [Int] = []; var want = [0, 0, 0, 1, 1, 2]; var seed = 1; var seen = Set<String>()
        while !want.isEmpty && seed < 200000 { let v = Variant(seed: seed, speciesId: sp.id); let n = v.name(sp.name)
            if let j = want.firstIndex(of: v.rarity), !seen.contains(n) { picks.append(seed); want.remove(at: j); seen.insert(n) }; seed += 1 }
        for (col, sd) in picks.sorted(by: { Variant(seed: $0, speciesId: sp.id).rarity < Variant(seed: $1, speciesId: sp.id).rarity }).enumerated() {
            let pv = PlantView(frame: NSRect(x: 0, y: 0, width: 120, height: 240))
            pv.st = PlantState(); pv.st.speciesId = sp.id; pv.st.age = sp.matureDays + 1; pv.st.health = 1; pv.st.moisture = 0.7; pv.st.variantSeed = sd; pv.posFactor = 1
            pv.t = CGFloat(col); let r = pv.bitmapImageRepForCachingDisplay(in: pv.bounds)!; pv.cacheDisplay(in: pv.bounds, to: r)
            let ox = CGFloat(col)*cw + 25, oy = CGFloat(SPECIES.count - 1 - row)*ch + 10
            r.draw(in: NSRect(x: ox, y: oy + 18, width: 120, height: 240 - 18))
            let n = Variant(seed: sd, speciesId: sp.id).name(sp.name) as NSString
            let a: [NSAttributedString.Key: Any] = [.font: cute(11.5), .foregroundColor: NSColor(white: 0.15, alpha: 1)]
            let sz = n.size(withAttributes: a); n.draw(at: NSPoint(x: CGFloat(col)*cw + (cw - sz.width)/2, y: oy + 4), withAttributes: a)
        }
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--mystery"), i+1 < CommandLine.arguments.count {
    // Contact sheet of mature absurd plants: one common + one rare/legendary each, plus a growing preview & hidden sprout
    var cells: [(String, Double, Int, String)] = []
    for (si, sp) in ABSURD.enumerated() {
        let wantR = sp.id == "unicorn" ? 2 : 1
        var c = 0, r = 0, seed = 1 + si * 37; while (c == 0 || r == 0) && seed < 100000 { let v = Variant(seed: seed, speciesId: sp.id); if v.rarity == 0 && c == 0 && v.face > 0 { c = seed }; if v.rarity == wantR && r == 0 && (v.deco > 0 || wantR == 2) { r = seed }; seed += 1 }
        cells.append((sp.id, sp.matureDays + 1, c, Variant(seed: c, speciesId: sp.id).name(sp.name))); cells.append((sp.id, sp.matureDays + 1, r, Variant(seed: r, speciesId: sp.id).name(sp.name)))
    }
    let cols = 6, cw: CGFloat = 170, ch: CGFloat = 250, rows = (cells.count + 2 + cols - 1) / cols
    cells.append(("maratang", 8, 5, "??? 새싹 (숨김)")); cells.append(("unicorn", 40, 5, "성장기 (정체 공개)"))
    let img = NSImage(size: NSSize(width: CGFloat(cols)*cw, height: CGFloat(rows)*ch)); img.lockFocus()
    NSColor(calibratedRed: 0.86, green: 0.9, blue: 0.94, alpha: 1).setFill(); NSRect(origin: .zero, size: img.size).fill()
    for (k, (id, age, sd, title)) in cells.enumerated() {
        let pv = PlantView(frame: NSRect(x: 0, y: 0, width: 120, height: 240))
        pv.st = PlantState(); pv.st.speciesId = id; pv.st.age = age; pv.st.health = 1; pv.st.moisture = 0.7; pv.st.variantSeed = sd; pv.st.mystery = true; pv.posFactor = 1; outdoorTemp = 18
        pv.t = CGFloat(k) * 0.7; let r = pv.bitmapImageRepForCachingDisplay(in: pv.bounds)!; pv.cacheDisplay(in: pv.bounds, to: r)
        let col = k % cols, row = k / cols, ox = CGFloat(col)*cw + 25, oy = CGFloat(rows - 1 - row)*ch + 10
        r.draw(in: NSRect(x: ox, y: oy + 18, width: 120, height: 240 - 18))
        let label = (pv.secret ? "\(pv.shownEmoji) " : "") + title as NSString
        let a: [NSAttributedString.Key: Any] = [.font: cute(11.5), .foregroundColor: NSColor(white: 0.15, alpha: 1)]
        let sz = label.size(withAttributes: a); label.draw(at: NSPoint(x: CGFloat(col)*cw + (cw - sz.width)/2, y: oy + 4), withAttributes: a)
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--jelly"), i+1 < CommandLine.arguments.count {
    // Preview frames: baby / adult / happy (petting) / hungry / eating
    let cw: CGFloat = 330, ch: CGFloat = 420, cells = ["아기 해파리", "어른 해파리", "쓰다듬는 중 (행복)", "배고픔 (시무룩)", "먹이 먹는 중"]
    let img = NSImage(size: NSSize(width: cw * CGFloat(cells.count) + 20, height: ch + 40)); img.lockFocus()
    NSGradient(colors: [NSColor(calibratedRed: 0.1, green: 0.16, blue: 0.34, alpha: 1), NSColor(calibratedRed: 0.32, green: 0.24, blue: 0.5, alpha: 1), NSColor(calibratedRed: 0.85, green: 0.6, blue: 0.62, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: img.size.width, height: img.size.height), angle: -90)
    for (k, title) in cells.enumerated() {
        let jm = Jelly(); jm.st = JellyState(); jm.st.growth = k == 0 ? 0.3 : 6; jm.st.fullness = k == 3 ? 0.05 : 0.8; jm.st.happiness = k == 3 ? 0.1 : k == 2 ? 0.95 : 0.7
        let v = JellyView(frame: NSRect(x: 0, y: 0, width: cw, height: ch), model: jm); v.swimRect = NSRect(x: -5000, y: -5000, width: 10000, height: 10000)
        let home = CGPoint(x: cw / 2 + (k == 4 ? 20 : 0), y: ch * 0.62); v.pos = home; v.heading = .pi / 2 + (k % 2 == 0 ? 0.25 : -0.2); v.resetChains()
        if k == 4 { for j in 0..<6 { v.food.append(Food(p: CGPoint(x: home.x - 60 + CGFloat(j) * 26, y: home.y + 70 + CGFloat(j % 3) * 22), v: 0, age: 5, seed: CGFloat(j))) } }
        for f in 0..<150 { v.target = CGPoint(x: home.x + 300 * cos(v.heading), y: home.y + 300 * sin(v.heading)); let keepFood = v.food; v.step(1.0 / 30); v.food = keepFood; v.pos = home; v.vel = .zero
            if k == 2 { v.petted(1.0 / 30) }; if k == 4 && f > 140 { v.eatGlow = 1 } }
        if k == 4 { v.food.removeFirst(2) }
        v.phase = .pi * 0.3; v.contract = 0.3
        let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cw), pixelsHigh: Int(ch), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        v.cacheDisplay(in: v.bounds, to: r); r.draw(in: NSRect(x: 10 + CGFloat(k) * cw, y: 30, width: cw, height: ch), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        let a: [NSAttributedString.Key: Any] = [.font: cute(15), .foregroundColor: NSColor.white]; let ts = title as NSString, sz = ts.size(withAttributes: a)
        ts.draw(at: NSPoint(x: 10 + CGFloat(k) * cw + (cw - sz.width) / 2, y: 10), withAttributes: a)
        let sub = String(format: "배부름 %.0f%% · 행복도 %.0f%% · %@", jm.st.fullness * 100, jm.st.happiness * 100, Jelly.stageNames[jm.stage]) as NSString
        let a2: [NSAttributedString.Key: Any] = [.font: cute(11), .foregroundColor: NSColor(white: 1, alpha: 0.75)]; let s2 = sub.size(withAttributes: a2)
        sub.draw(at: NSPoint(x: 10 + CGFloat(k) * cw + (cw - s2.width) / 2, y: ch + 14), withAttributes: a2)
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--gauge"), i+1 < CommandLine.arguments.count {
    // normal vs hover (covered and uncovered) at 100%
    windowStyle = 5; potStyle = 6; bgImage = nil
    var wx = Wx(); wx.code = 0; wx.month = 10; wx.hour = 10.2; wx.temp = 18; wx.wind = 8; currentWx = wx; weatherKnown = true
    let img = NSImage(size: NSSize(width: 4*340 + 20, height: 420)); img.lockFocus()
    NSGradient(starting: NSColor(calibratedRed: 0.15, green: 0.14, blue: 0.32, alpha: 1), ending: NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.55, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: 4*340 + 20, height: 420), angle: 60)
    for (k, (cov, hv, title)) in [(false, 0.0, "평소"), (false, 1.0, "마우스 올림"), (true, 0.0, "덮개 · 평소"), (true, 1.0, "덮개 · 마우스 올림")].enumerated() {
        let (wv, pv) = makeScene(); pv.st = PlantState(); pv.st.speciesId = "basil"; pv.st.age = 30; pv.st.health = 1; pv.st.moisture = 0.7; pv.st.covered = cov; pv.st.variantSeed = 3; outdoorTemp = 18
        let sv = ScaleView(scene: wv, size: BASE); sv.grip.isHidden = true
        for _ in 0..<30 { wv.tick() }; wv.layoutCard(); wv.setHover(CGFloat(hv))
        let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(BASE.width), pixelsHigh: Int(BASE.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        sv.cacheDisplay(in: sv.bounds, to: r); r.draw(in: NSRect(x: 20 + CGFloat(k)*340, y: 30, width: BASE.width, height: BASE.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        (title as NSString).draw(at: NSPoint(x: 24 + CGFloat(k)*340, y: 6), withAttributes: [.font: cute(14), .foregroundColor: NSColor.white])
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--glass"), i+2 < CommandLine.arguments.count {
    // Side-by-side: mockup (left) vs. glass theme render (right, autumn clear 18°C, seedling under cloche) + small-size previews
    let mock = NSImage(contentsOfFile: CommandLine.arguments[i+2])
    windowStyle = 5; potStyle = 6; bgImage = nil; alwaysInfoOverride = true
    var wx = Wx(); wx.code = 0; wx.month = 10; wx.hour = 10.2; wx.temp = 18; wx.wind = 8; wx.sunrise = 6.6; wx.sunset = 18
    currentWx = wx; weatherKnown = true
    let H: CGFloat = 720, W: CGFloat = 720 + 20 + 640 + 20 + 420
    let img = NSImage(size: NSSize(width: W, height: H + 40)); img.lockFocus()
    NSGradient(starting: NSColor(calibratedRed: 0.15, green: 0.14, blue: 0.32, alpha: 1), ending: NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.55, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H + 40), angle: 60)
    mock?.draw(in: NSRect(x: 0, y: 20, width: H, height: H))
    func render(_ s: CGFloat, covered: Bool, age: Double, at o: NSPoint) {
        let (wv, pv) = makeScene(); pv.st = PlantState(); pv.st.speciesId = "basil"; pv.st.age = age; pv.st.health = 1; pv.st.moisture = 0.7; pv.st.covered = covered; pv.st.variantSeed = 3
        outdoorTemp = 18; let sv = ScaleView(scene: wv, size: NSSize(width: BASE.width * s, height: BASE.height * s)); sv.grip.isHidden = true
        for _ in 0..<40 { wv.tick() }; pv.setFrameOrigin(NSPoint(x: wv.glassRect.minX - 6, y: pv.frame.origin.y))
        let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(sv.bounds.width), pixelsHigh: Int(sv.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        sv.cacheDisplay(in: sv.bounds, to: r); r.draw(in: NSRect(origin: o, size: sv.bounds.size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
    }
    render(2.0, covered: true, age: 9, at: NSPoint(x: 740, y: 20))
    render(1.0, covered: false, age: 40, at: NSPoint(x: 1400, y: H + 20 - 360 - 10))
    render(0.6, covered: false, age: 70, at: NSPoint(x: 1400, y: 40))
    render(0.4, covered: true, age: 30, at: NSPoint(x: 1620, y: 40))
    let a: [NSAttributedString.Key: Any] = [.font: cute(15), .foregroundColor: NSColor.white]
    ("목업 (Gemini)" as NSString).draw(at: NSPoint(x: 10, y: H + 18), withAttributes: a); ("글래스 테마 (200%)" as NSString).draw(at: NSPoint(x: 750, y: H + 18), withAttributes: a)
    ("100% · 60% · 40%" as NSString).draw(at: NSPoint(x: 1410, y: H + 18), withAttributes: a)
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--compact"), i+1 < CommandLine.arguments.count {
    // Hover previews at 40% / 60% / 100% at real on-screen size; external bubble drawn above when used
    let scales: [CGFloat] = [0.4, 0.6, 1.0]
    let W = scales.reduce(20) { $0 + max(BASE.width * $1, 300) + 20 }, H = BASE.height + 130
    let img = NSImage(size: NSSize(width: W, height: H)); img.lockFocus()
    NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    var x: CGFloat = 20; let end = Date().addingTimeInterval(4); var first = true
    for s in scales {
        let (wv, _) = makeScene()
        let sv = ScaleView(scene: wv, size: NSSize(width: BASE.width * s, height: BASE.height * s))
        if first { while Date() < end && !weatherKnown { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }; first = false }
        for _ in 0..<30 { wv.tick() }; wv.layoutCard(); wv.setHover(1)
        let colW = max(sv.bounds.width, 300), sx = x + (colW - sv.bounds.width) / 2
        let r = sv.bitmapImageRepForCachingDisplay(in: sv.bounds)!; sv.cacheDisplay(in: sv.bounds, to: r); r.draw(in: NSRect(x: sx, y: 20, width: sv.bounds.width, height: sv.bounds.height))
        if wv.external { let bv = wv.bubble.bubbleView; bv.side = .below; bv.pointerAt = sv.bounds.width / 2 + (sx - (x + (colW - bv.frame.width) / 2))
            let br = bv.bitmapImageRepForCachingDisplay(in: bv.bounds)!; bv.cacheDisplay(in: bv.bounds, to: br); br.draw(in: NSRect(x: x + (colW - bv.frame.width) / 2, y: 20 + sv.bounds.height + 4, width: bv.frame.width, height: bv.frame.height)) }
        x += colW + 20
    }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i+1 < CommandLine.arguments.count {
    // Render both widgets offscreen to a PNG (for previews without Screen Recording permission)
    let (wv, pv) = makeScene()
    let end = Date().addingTimeInterval(4); while Date() < end && !weatherKnown { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    let img = NSImage(size: NSSize(width: 1000, height: 740)); img.lockFocus()
    NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 1000, height: 740).fill()
    let shots: [(Int?, CGFloat)] = [(nil, 0), (nil, 1), (2, 1), (8, 0), (14, 0), (16, 1)]
    _ = pv; for (k, (pre, h)) in shots.enumerated() { debugPreset = pre; for _ in 0..<30 { wv.tick() }; if pre == 2 { wv.flash = 0.9 }; wv.setHover(h)
        let r = wv.bitmapImageRepForCachingDisplay(in: wv.bounds)!; wv.cacheDisplay(in: wv.bounds, to: r); r.draw(at: NSPoint(x: 10 + CGFloat(k % 3) * 330, y: 375 - CGFloat(k / 3) * 365)) }
    img.unlockFocus(); let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i+1])); exit(0)
}
if let me = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: me).filter({ $0.processIdentifier != getpid() }).count > 0 { exit(0) }   // single instance
if !defaults.bool(forKey: "glassTheme120") { defaults.set(true, forKey: "glassTheme120"); defaults.set(5, forKey: "windowStyle"); defaults.set(6, forKey: "potStyle"); windowStyle = 5; potStyle = 6 }   // v1.2.0: new default theme (others stay selectable)
if let c = defaults.string(forKey: "cityName"), koreanCity(c) != c { defaults.set(koreanCity(c), forKey: "cityName") }   // migrate English IP city names
let app = NSApplication.shared; let del = AppDelegate(); app.delegate = del; app.setActivationPolicy(.accessory); app.run()
