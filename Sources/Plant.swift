import AppKit

/// Parameters loosely based on common home-gardening care guides.
struct Species {
    let id, name, emoji: String
    let germDays, matureDays: Double      // days to sprout / to bloom or harvest
    let waterEvery: Double                // days for soil to go from wet to dry
    let overwaterHarm: Double             // health loss per day while soggy
    let lightNeed: Double                 // required daily-average light (0..1)
    let lightText: String
    let tips: [String]
}
/// Growth speed: 0 실제(1x), 1 빠름(default), 2 아주 빠름. Target real days to maturity per species.
let FAST_DAYS: [String: Double] = ["basil": 4.5, "lettuce": 4, "tomato": 7, "sunflower": 7, "rose": 10, "echeveria": 14]
let VFAST_DAYS: [String: Double] = ["basil": 1.2, "lettuce": 1, "tomato": 1.5, "sunflower": 1.5, "rose": 1.8, "echeveria": 2]
var growthSpeed: Int { defaults.object(forKey: "growthSpeed") as? Int ?? 1 }
extension Species {
    /// growth-days per real day
    var speedFactor: Double { switch growthSpeed { case 1: return matureDays / (FAST_DAYS[id] ?? 7); case 2: return matureDays / (VFAST_DAYS[id] ?? 1.5); default: return 1 } }
    /// soil drying interval (real days), sped up only partially so care stays manageable
    var dryDays: Double { let floor = growthSpeed == 1 ? 0.5 : growthSpeed == 2 ? 1.0/6 : waterEvery; return min(waterEvery, max(floor, waterEvery / speedFactor)) }
    func realDaysLeft(_ age: Double) -> Double { max(0, matureDays - age) / speedFactor }
}
let SPECIES: [Species] = [
    Species(id: "basil", name: "바질", emoji: "🌿", germDays: 7, matureDays: 60, waterEvery: 2.5, overwaterHarm: 0.12, lightNeed: 0.33, lightText: "하루 6~8시간 햇빛",
            tips: ["흙 표면이 마르면 흠뻑 물을 주세요.", "꽃대가 올라오면 순지르기하면 잎이 더 풍성해져요.", "추위(10°C 이하)에 약해요."]),
    Species(id: "sunflower", name: "해바라기", emoji: "🌻", germDays: 8, matureDays: 80, waterEvery: 3, overwaterHarm: 0.1, lightNeed: 0.4, lightText: "하루 6~8시간 이상 직사광선",
            tips: ["햇빛을 아주 좋아해요. 창가에 두세요.", "뿌리 깊이까지 충분히, 대신 자주는 말고.", "키가 크면 지지대가 필요해요."]),
    Species(id: "tomato", name: "방울토마토", emoji: "🍅", germDays: 7, matureDays: 75, waterEvery: 2, overwaterHarm: 0.12, lightNeed: 0.4, lightText: "하루 8시간 햇빛",
            tips: ["물을 일정하게 주면 열매가 갈라지지 않아요.", "꽃이 피면 2주마다 비료를 주세요.", "곁순은 따주면 열매가 커져요."]),
    Species(id: "echeveria", name: "에케베리아", emoji: "🪷", germDays: 21, matureDays: 150, waterEvery: 12, overwaterHarm: 0.5, lightNeed: 0.3, lightText: "밝은 햇빛 4~6시간",
            tips: ["흙이 완전히 마른 뒤에만 물을 주세요. 과습은 뿌리를 썩게 해요!", "빛이 부족하면 웃자라요.", "비료는 아주 가끔, 묽게."]),
    Species(id: "lettuce", name: "상추", emoji: "🥬", germDays: 5, matureDays: 45, waterEvery: 1.5, overwaterHarm: 0.1, lightNeed: 0.22, lightText: "반그늘~4시간 햇빛",
            tips: ["흙을 늘 촉촉하게 유지하세요.", "더위와 강한 햇빛에는 쉽게 쓴맛이 나요.", "바깥 잎부터 따서 수확하세요."]),
    Species(id: "rose", name: "미니장미", emoji: "🌹", germDays: 30, matureDays: 120, waterEvery: 3, overwaterHarm: 0.15, lightNeed: 0.38, lightText: "하루 6시간 이상 햇빛",
            tips: ["겉흙이 마르면 물을 듬뿍 주세요.", "개화기에는 2주에 한 번 비료를 주세요.", "통풍이 잘 되는 곳이 좋아요."]),
]

struct PlantState: Codable {
    var speciesId: String? = nil
    var age = 0.0            // simulated growth-days
    var realDays = 0.0       // calendar days since planting
    var moisture = 0.8       // 0 dry .. 1 moist .. >1 soggy
    var health = 1.0
    var lightAvg = 0.3
    var atWindow = true
    var fertilizedAt = -100.0
    var mistakes = 0
    var dead = false
    var lastUpdate = Date().timeIntervalSince1970
    var lastUseDay = -1
    var covered: Bool? = nil
    var variantSeed: Int? = nil
    var name: String? = nil
    var mystery: Bool? = nil
    var revealed: Bool? = nil
}

class PlantView: NSView {
    var st = PlantState(); var t: CGFloat = 0; var trashCount = -1; var splash: CGFloat = 0
    var accel: Bool { defaults.bool(forKey: "accel") }
    var sp: Species? { ALL_SPECIES.first { $0.id == st.speciesId } }
    let url: URL = { let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DesktopToys"); try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true); return d.appendingPathComponent("plant.json") }()
    override var mouseDownCanMoveWindow: Bool { false }
    var onChange: (() -> Void)?
    var dragStart: NSPoint?; var dragged = false; var origX: CGFloat = 0
    /// 0...1 light factor from position on the sill (set by container)
    var posFactor: Double = 1
    override init(frame: NSRect) {
        super.init(frame: frame)
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(PlantState.self, from: d) { st = s }
        if st.speciesId != nil && st.variantSeed == nil { st.variantSeed = Int.random(in: 1...Int(Int32.max)); save() }
        // one-time migration to growth-speed system: re-derive age from elapsed real time (never kills the plant)
        if !defaults.bool(forKey: "speedMigrated"), let s = sp, !st.dead { st.age = max(st.age, st.realDays * s.speedFactor * 0.9); defaults.set(true, forKey: "speedMigrated"); save() }
        catchUp()
        scheduleAnim(20)
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.minuteTick() }
        checkTrash(); updateTooltip()
    }
    required init?(coder: NSCoder) { fatalError() }
    var animTimer: Timer?; var animFPS: Double = 0; var lastAnim = CACurrentMediaTime()
    /// 20fps for splashes/toasts/hover fades/shivering; idle sway is driven by the window tick
    func scheduleAnim(_ f: Double) {
        guard f != animFPS else { return }; animFPS = f; animTimer?.invalidate(); animTimer = nil
        guard f > 0 else { return }   // idle: the window redraw (WeatherView tick) advances t and repaints us
        lastAnim = CACurrentMediaTime()
        let tm = Timer(timeInterval: 1 / f, repeats: true) { [weak self] _ in self?.animTick() }; tm.tolerance = 0.2 / f; RunLoop.main.add(tm, forMode: .common); animTimer = tm
    }
    func animTick() {
        let now = CACurrentMediaTime(), dt = CGFloat(min(0.3, now - lastAnim)); lastAnim = now
        t += dt; if splash > 0 { splash -= dt }; needsDisplay = true
        let busy = splash > 0 || toast != nil || (gaugeAlpha > 0.01 && gaugeAlpha < 0.99) || (isCold && !(st.covered ?? false))
        scheduleAnim(busy ? 20 : 0)
    }
    func save() { if let d = try? JSONEncoder().encode(st) { try? d.write(to: url) } }

    var receivedLight: Double { outdoorLight * posFactor * ((st.covered ?? false) ? 0.6 : 1) }
    var minTemp: Double { MIN_TEMP[st.speciesId ?? ""] ?? ABSURD_MIN[st.speciesId ?? ""] ?? 5 }
    var isHot: Bool { guard let mx = MAX_TEMP[st.speciesId ?? ""], let T = outdoorTemp else { return false }; return T > mx }
    /// mystery seeds keep the species secret until the growing stage
    var secret: Bool { guard let s = sp, st.mystery == true, !st.dead else { return false }; return st.age < s.germDays + (s.matureDays - s.germDays) * 0.35 }
    var shownSpeciesName: String { secret ? "???" : (sp?.name ?? "") }
    var shownEmoji: String { secret ? "🎲" : (sp?.emoji ?? "🪴") }
    var toast: String? = nil; var toastT: CGFloat = 0
    var isCold: Bool { (outdoorTemp ?? 15) < minTemp }

    /// Advance the simulation by dt days with a given light level.
    func step(_ dt: Double, light: Double) {
        guard let s = sp, !st.dead else { return }
        st.realDays += dt
        st.moisture = max(0, st.moisture - dt / s.dryDays)
        st.lightAvg += (light - st.lightAvg) * min(1, dt / 2)
        var dh = 0.0
        if st.moisture < 0.12 { dh -= 0.25 * dt }                       // drought
        if st.moisture > 1.0 { dh -= s.overwaterHarm * dt }             // soggy roots
        let germinated = st.age >= s.germDays
        if germinated && st.lightAvg < s.lightNeed * 0.6 { dh -= 0.08 * dt }  // too dark (leggy)
        let cov = st.covered ?? false
        if let T = outdoorTemp {
            if T < minTemp && !cov { dh -= (0.15 + 0.06 * (minTemp - T)) * dt }       // cold damage
            if T < minTemp - 6 && cov { dh -= 0.05 * dt }                               // even covered, hard frost hurts
            if !cov && (windSpeed >= 40 || pm10 >= 150) && posFactor > 0.6 { dh -= 0.03 * dt }   // wind / yellow-dust stress
            if cov && T > 20 && outdoorLight > 0.7 { dh -= 0.06 * dt }                  // overheating under cover
            if let mx = MAX_TEMP[s.id], T > mx { dh -= (0.08 + 0.02 * (T - mx)) * dt }    // melts / goes soggy
        }
        // recovery: only when nothing is stressing the plant (good moisture, enough light, no cold)
        if dh == 0 && st.moisture >= 0.25 && st.moisture <= 1.0 { dh = recoveryPerDay * dt }
        st.health = min(1, st.health + dh)
        if st.health <= 0 { st.health = 0; st.dead = true; return }
        if st.health > 0.3 && st.moisture > 0.12 {
            let lf = germinated ? min(1.0, st.lightAvg / s.lightNeed) : 1.0
            let fert = ((st.realDays - st.fertilizedAt) < 14 && germinated ? 1.2 : 1.0) * (COLD_LOVERS.contains(s.id) && (outdoorTemp ?? 15) < 10 ? 1.3 : 1.0)
            st.age += dt * s.speedFactor * (0.4 + 0.6 * lf) * (0.5 + 0.5 * st.health) * fert
        }
    }
    func catchUp() {
        let now = Date().timeIntervalSince1970; var tt = st.lastUpdate
        while now - tt > 3600 {   // hour steps with typical daylight
            let h = Calendar.current.component(.hour, from: Date(timeIntervalSince1970: tt))
            step(1.0/24, light: ((7..<18).contains(h) ? 0.55 : 0) * posFactor); tt += 3600
        }
        st.lastUpdate = now; useBonus(); save()
    }
    func useBonus() { let d = dayIndex(); if st.lastUseDay != d { st.lastUseDay = d; if sp != nil && !st.dead { st.age += 0.2 } } }
    func minuteTick() {
        let mult = accel ? 1440.0 : 1.0   // accelerated: 1 real minute = 1 day
        step(60.0 / 86400 * mult, light: receivedLight)
        st.lastUpdate = Date().timeIntervalSince1970; useBonus(); checkTrash(); checkReveal(); save(); updateTooltip()
    }
    func checkReveal() { if st.mystery == true, st.revealed != true, sp != nil, !secret, !st.dead { st.revealed = true; showToast("🎲 정체 공개! \(sp!.emoji) \(sp!.name)" + (ABSURD_RARITY[sp!.id].map { " " + $0 } ?? "")) } }
    func showToast(_ s: String) { toast = s; toastT = 6 }
    func checkTrash() {
        let p = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: p) else { return }
        let n = items.filter { $0 != ".DS_Store" }.count
        if trashCount > 0 && n == 0 && sp != nil && !st.dead { st.age += 0.5; splash = 1; save() }
        trashCount = n
    }

    // MARK: actions
    var recoveryPerDay: Double { [0.08, 0.12, 0.5][min(2, max(0, growthSpeed))] }
    var plantName: String { st.name ?? (secret ? "미스터리 씨앗" : sp?.name ?? "화분") }
    /// Korean subject particle 이/가 after the name
    var nameSubj: String { guard let ch = plantName.unicodeScalars.last?.value, ch >= 0xAC00, ch <= 0xD7A3 else { return plantName + "가" }; return plantName + ((ch - 0xAC00) % 28 == 0 ? "가" : "이") }
    func askName(default d: String) -> String? {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = "이름을 지어 주세요 🌱"; a.informativeText = "비워 두면 '\(d)'(으)로 불러요."
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 28)); tf.font = cute(15); tf.placeholderString = d; tf.stringValue = st.name ?? ""
        a.accessoryView = tf; a.addButton(withTitle: "좋아요"); a.addButton(withTitle: "건너뛰기"); a.window.initialFirstResponder = tf
        let r = a.runModal(); NSApp.setActivationPolicy(.accessory)
        guard r == .alertFirstButtonReturn else { return nil }
        let v = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); return v.isEmpty ? nil : String(v.prefix(16))
    }
    var nameObj: String { guard let ch = plantName.unicodeScalars.last?.value, ch >= 0xAC00, ch <= 0xD7A3 else { return plantName + "를" }; return plantName + ((ch - 0xAC00) % 28 == 0 ? "를" : "을") }
    /// Reset with confirmation when a living plant would be pulled out
    func confirmReset() {
        if sp != nil && !st.dead {
            NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert(); a.alertStyle = .warning; a.messageText = "정말 \(nameObj) 뽑을까요?"; a.informativeText = "되돌릴 수 없어요."
            a.addButton(withTitle: "취소"); let del = a.addButton(withTitle: "뽑기"); del.hasDestructiveAction = true
            let r = a.runModal(); NSApp.setActivationPolicy(.accessory)
            guard r == .alertSecondButtonReturn else { return }
        }
        reset()
    }
    @objc func rename() { guard let s = sp else { return }; if let n = askName(default: secret ? "미스터리 씨앗" : s.name) { st.name = n } else if st.name == nil { return }; save(); updateTooltip() }
    func plant(_ s: Species, mystery: Bool = false) { st = PlantState(); st.speciesId = s.id; if mystery { st.mystery = true }; st.variantSeed = Int.random(in: 1...Int(Int32.max)); st.lastUseDay = dayIndex(); st.name = Bundle.main.bundleIdentifier != nil ? askName(default: mystery ? "미스터리 씨앗" : s.name) : nil; save(); updateTooltip() }
    func reset() { st = PlantState(); save(); updateTooltip() }
    @objc func water() {
        st.moisture = min(1.6, st.moisture + 0.7); splash = 1.5
        if st.moisture > 1.15 { st.mistakes += 1 }
        save(); updateTooltip()
    }
    @objc func fertilize() {
        guard let s = sp else { return }
        if st.realDays - st.fertilizedAt < 7 || st.age < s.germDays + 7 { st.health -= 0.2; st.mistakes += 1 }   // too often / too young: fertilizer burn
        if s.id == "echeveria" && st.realDays - st.fertilizedAt < 30 { st.health -= 0.1 }
        st.fertilizedAt = st.realDays
        if st.health <= 0 { st.health = 0; st.dead = true }
        save(); updateTooltip()
    }
    @objc func toggleCover() { st.covered = !(st.covered ?? false); save(); updateTooltip() }
    @objc func toggleWindow() { st.atWindow.toggle(); save(); updateTooltip() }
    @objc func pickSeed(_ m: NSMenuItem) { plant(SPECIES[m.tag]) }
    @objc func pickMystery() { plant(randomMysterySpecies(), mystery: true) }
    @objc func replant() { reset() }

    var stageName: String {
        guard let s = sp else { return "빈 화분" }
        if st.dead { return "말라 죽음" }
        if st.age < s.germDays { return "씨앗 (발아 중)" }
        if st.age < s.germDays + (s.matureDays - s.germDays) * 0.35 { return "새싹" }
        if st.age < s.matureDays { return "성장기" }
        if let v = variantName { return v }
        if ABSURD.contains(where: { $0.id == s.id }) { return "다 자람" }
        return ["tomato": "열매 맺음", "lettuce": "수확 가능", "echeveria": "다 자란 로제트"][s.id] ?? "꽃 핌"
    }
    func statusLines() -> [String] {
        guard let s = sp else { return ["빈 화분이에요. 씨앗을 골라 심어주세요."] }
        let moist = st.moisture > 1.0 ? "과습 💦" : st.moisture < 0.12 ? "바싹 마름 🏜️" : st.moisture < 0.35 ? "건조함" : "적당함"
        let lightR = st.lightAvg / s.lightNeed
        let light = lightR < 0.6 ? "부족 🌥️" : lightR < 1 ? "약간 부족" : "충분 ☀️"
        return [(st.name != nil ? "\(plantName) · " : "") + "\(shownSpeciesName) · \(stageName)",
                String(format: "흙 수분: %.0f%% (%@)", min(st.moisture, 1.6) * 100, moist),
                String(format: "빛: %@ · 창 위치 빛 %.0f%% · 필요: %@", light, posFactor*100, secret ? "???" : s.lightText),
                String(format: "건강: %.0f%% · 실수 %d회", st.health * 100, st.mistakes),
                String(format: "기온: %@ (최저 %.0f°C) · 덮개 %@", outdoorTemp.map { String(format: "%.0f°C", $0) } ?? "?", minTemp, (st.covered ?? false) ? "덮음" : "없음"),
                st.age >= s.matureDays ? String(format: "심은 지 %.1f일 · 다 자랐어요!", st.realDays) : String(format: "심은 지 %.1f일 · 다 자라기까지 약 %.1f일", st.realDays, s.realDaysLeft(st.age)),
                "💡 " + tip()]
    }
    func tip() -> String {
        guard let s = sp else { return "" }
        if st.dead { return "다시 심어보세요. 이번엔 가이드를 따라봐요!" }
        let cov = st.covered ?? false
        if isCold && !cov, let ct = COLD_TIP[s.id] { return ct }
        if isCold && !cov { return String(format: "%@ 추워해요(%.0f°C, 최저 %.0f°C). 덮어 주세요!", nameSubj, outdoorTemp ?? 0, minTemp) }
        if cov && !isCold && (outdoorTemp ?? 0) > 15 { return "따뜻해요. 덮개를 치워 주세요." }
        if isHot { return HEAT_TIP[s.id] ?? "너무 더워요. 선선해지면 회복돼요." }
        if !cov && windSpeed >= 40 { return "바람이 세요. 덮개를 덮어 보호해 주세요." }
        if !cov && pm10 >= 150 { return "황사가 심해요. 덮개를 덮어 주세요." }
        if st.age >= s.germDays && outdoorLight > 0 && posFactor < 0.6 { return "\(nameSubj) 그늘에 있어요. 햇빛 자리로 옮겨 주세요." }
        if st.moisture > 1.0, let so = SOGGY_TIP[s.id] { return so }
        if st.moisture > 1.0 { return s.id == "echeveria" ? "과습 상태! 흙이 완전히 마를 때까지 물을 주지 마세요." : "\(nameSubj) 물에 잠겼어요. 흙이 마를 때까지 기다리세요." }
        if st.moisture < 0.3 { return "\(nameSubj) 목말라해요. 지금 물을 흠뻑 주세요." }
        if st.age >= s.germDays && st.lightAvg < s.lightNeed * 0.8 { return posFactor > 0.85 ? "오늘은 빛이 약해요. 날씨가 개면 회복돼요." : "빛이 부족해요. 화분을 창 가운데로 옮겨주세요." }
        if st.health < 0.99 { return String(format: "%@ 회복 중이에요 (하루 약 +%.0f%%). 지금처럼만 돌봐 주세요.", nameSubj, recoveryPerDay * 100) }
        if st.age < s.germDays { return st.mystery == true ? "무엇이 자랄까요? 🎲 흙을 촉촉하게 유지해 주세요." : "발아 전에는 흙을 촉촉하게만 유지하세요." }
        if secret { return ["새싹이 뭔가 수상해요… 🤔", "정체는 조금 더 자라면 공개돼요!", "잎에서 묘하게 맛있는 냄새가 나요…?"][Int(st.realDays * 3) % 3] }
        if COLD_LOVERS.contains(s.id) && (outdoorTemp ?? 15) < 10 { return "\(nameSubj) 추운 날씨에 신나게 자라요 ❄️" }
        return s.tips[Int(st.realDays) % s.tips.count]
    }
    var badge: String? {
        guard sp != nil, !st.dead else { return nil }
        let cov = st.covered ?? false
        if isCold && !cov { return "🥶" }
        if st.moisture < 0.25 { return "💧" }
        if !cov && (windSpeed >= 40 || pm10 >= 150) { return "💨" }
        if let s = sp, st.age >= s.germDays, outdoorLight > 0, posFactor < 0.6 { return "☀️" }
        return nil
    }
    var variant: Variant? { guard let s = sp, let seed = st.variantSeed else { return nil }; return Variant(seed: seed, speciesId: s.id) }
    var isMature: Bool { guard let s = sp else { return false }; return !st.dead && st.age >= s.matureDays }
    var variantName: String? { guard isMature, let s = sp, let v = variant else { return nil }; return v.name(s.name) }
    @objc func harvest() {
        guard isMature, let s = sp, let name = variantName else { return }
        var dex = defaults.dictionary(forKey: "dex") as? [String: Int] ?? [:]; dex[name + (st.name != nil ? " — \(plantName)" : ""), default: 0] += 1; defaults.set(dex, forKey: "dex")
        if ["lettuce", "sunflower"].contains(s.id) { reset() }        // annuals: harvest ends the plant
        else { st.age = s.germDays + (s.matureDays - s.germDays) * 0.55; st.variantSeed = Int.random(in: 1...Int(Int32.max)); save() }
        if let l = HARVEST_LINES[s.id]?.randomElement() { showToast(l) } else { showToast("🧺 \(name) 수확!") }
        splash = 1; updateTooltip()
    }
    func updateTooltip() { toolTip = statusLines().joined(separator: "\n"); onChange?(); scheduleAnim(20) }

    var dragClamp: ((CGFloat) -> CGFloat)?
    override func mouseDown(with e: NSEvent) { dragStart = NSEvent.mouseLocation; dragged = false; origX = frame.origin.x }
    override func mouseDragged(with e: NSEvent) {
        guard let s = dragStart else { return }
        let dx = (NSEvent.mouseLocation.x - s.x) / ((window?.frame.width ?? BASE.width) / BASE.width)
        if abs(dx) > 3 { dragged = true }
        if dragged { setFrameOrigin(NSPoint(x: dragClamp?(origX + dx) ?? origX + dx, y: frame.origin.y)); onMove?() }
    }
    var onMove: (() -> Void)?
    override func mouseUp(with e: NSEvent) {
        if dragged { dragged = false; return }
        let m = NSMenu(); m.autoenablesItems = false
        for l in statusLines() { let i = m.addItem(withTitle: l, action: nil, keyEquivalent: ""); i.isEnabled = false }
        m.addItem(.separator())
        if sp == nil || st.dead {
            if st.dead { m.addItem(withTitle: "🪦 치우고 다시 심기", action: #selector(replant), keyEquivalent: "").target = self }
            if sp == nil { for (i, s) in SPECIES.enumerated() {
                let it = m.addItem(withTitle: "\(s.emoji) \(s.name) 씨앗 심기 (약 \(String(format: "%.0f", s.matureDays / s.speedFactor))일, 물 \(String(format: s.dryDays < 1 ? "%.0f시간" : "%.1f일", s.dryDays < 1 ? s.dryDays * 24 : s.dryDays)) 간격)", action: #selector(pickSeed(_:)), keyEquivalent: ""); it.tag = i; it.target = self }
                m.addItem(withTitle: "🎲 랜덤 씨앗 (무엇이 자랄지 몰라요!)", action: #selector(pickMystery), keyEquivalent: "").target = self }
        } else {
            if isMature { m.addItem(withTitle: "🧺 수확하기 — \(variantName ?? "")", action: #selector(harvest), keyEquivalent: "").target = self }
            m.addItem(withTitle: "✏️ 이름 바꾸기…", action: #selector(rename), keyEquivalent: "").target = self
            m.addItem(withTitle: "💧 물 주기", action: #selector(water), keyEquivalent: "").target = self
            m.addItem(withTitle: (st.covered ?? false) ? "🧺 덮개 치우기" : "🧣 덮개 덮기", action: #selector(toggleCover), keyEquivalent: "").target = self
            m.addItem(withTitle: "🧪 비료 주기", action: #selector(fertilize), keyEquivalent: "").target = self
        }
        NSMenu.popUpContextMenu(m, with: e, for: self)
    }

    // MARK: drawing
    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
    /// Pot body + rim for the selected pot style (soil & face drawn after)
    func drawPot(_ cx: CGFloat) {
        NSColor(white: 0, alpha: 0.15).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-34, y: 18, width: 68, height: 8)).fill()
        func grad(_ path: NSBezierPath, _ cols: [NSColor], _ angle: CGFloat = 0) { NSGradient(colors: cols)!.draw(in: path, angle: angle) }
        switch potStyle {
        case 1: // white ceramic minimal (straight cylinder)
            let body = NSBezierPath(roundedRect: NSRect(x: cx-31, y: 22, width: 62, height: 49), xRadius: R(8), yRadius: R(8))
            grad(body, [c(0.98, 0.98, 0.97), c(0.93, 0.93, 0.92), c(0.84, 0.84, 0.83)])
            NSColor(white: 0, alpha: 0.06).setFill(); NSRect(x: cx-31, y: 64, width: 62, height: 1).fill()
        case 2: // pastel round bowl
            let body = NSBezierPath(); body.move(to: NSPoint(x: cx-37, y: 70)); body.curve(to: NSPoint(x: cx+37, y: 70), controlPoint1: NSPoint(x: cx-40, y: 8), controlPoint2: NSPoint(x: cx+40, y: 8)); body.close()
            grad(body, [c(1, 0.82, 0.86), c(0.97, 0.72, 0.78), c(0.9, 0.62, 0.7)])
            NSColor(white: 1, alpha: 0.35).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-26, y: 44, width: 10, height: 14)).fill()
            c(0.72, 0.9, 0.84).setFill(); NSBezierPath(roundedRect: NSRect(x: cx-38, y: 64, width: 76, height: 8), xRadius: R(4), yRadius: R(4)).fill()
        case 3: // rattan basket
            let body = NSBezierPath(); body.move(to: NSPoint(x: cx-28, y: 22)); body.line(to: NSPoint(x: cx+28, y: 22)); body.line(to: NSPoint(x: cx+36, y: 66)); body.line(to: NSPoint(x: cx-36, y: 66)); body.close()
            grad(body, [c(0.86, 0.7, 0.47), c(0.8, 0.63, 0.4), c(0.7, 0.53, 0.32)])
            NSGraphicsContext.saveGraphicsState(); body.addClip()
            c(0.62, 0.46, 0.27, 0.55).setStroke()
            for row in 0..<7 { let y = 25 + CGFloat(row) * 6.2; for k in 0..<12 { let x = cx - 38 + CGFloat(k) * 7 + (row % 2 == 0 ? 0 : 3.5)
                let w = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 6, height: 4.4)); w.lineWidth = 0.8; w.stroke() } }
            NSGraphicsContext.restoreGraphicsState()
            let rim = NSBezierPath(roundedRect: NSRect(x: cx-39, y: 63, width: 78, height: 9), xRadius: R(4.5), yRadius: R(4.5)); grad(rim, [c(0.75, 0.57, 0.35), c(0.88, 0.72, 0.5)], 90)
            c(0.62, 0.46, 0.27, 0.6).setStroke(); let tw = NSBezierPath(); var x = cx - 37; while x < cx + 37 { tw.move(to: NSPoint(x: x, y: 64)); tw.line(to: NSPoint(x: x + 4, y: 71)); x += 5 }; tw.lineWidth = 0.8; tw.stroke()
        case 4: // cat pot
            let fur = [c(0.98, 0.96, 0.93), c(0.94, 0.9, 0.85), c(0.86, 0.81, 0.75)]
            for s in [-1.0, 1.0] as [CGFloat] { let e = NSBezierPath(); e.move(to: NSPoint(x: cx + s*35, y: 58)); e.line(to: NSPoint(x: cx + s*33, y: 92)); e.line(to: NSPoint(x: cx + s*12, y: 66)); e.close(); fur[1].setFill(); e.fill()
                let ie = NSBezierPath(); ie.move(to: NSPoint(x: cx + s*31, y: 64)); ie.line(to: NSPoint(x: cx + s*30.5, y: 85)); ie.line(to: NSPoint(x: cx + s*19, y: 67)); ie.close(); c(1, 0.72, 0.75).setFill(); ie.fill() }
            let body = NSBezierPath(roundedRect: NSRect(x: cx-34, y: 22, width: 68, height: 49), xRadius: R(16), yRadius: R(16)); grad(body, fur)
            c(0.4, 0.3, 0.28, 0.6).setStroke()
            for s in [-1.0, 1.0] as [CGFloat] { for k in 0..<2 { let wk = NSBezierPath(); wk.move(to: NSPoint(x: cx + s*20, y: 37 + CGFloat(k)*3)); wk.line(to: NSPoint(x: cx + s*31, y: 36 + CGFloat(k)*5)); wk.lineWidth = 0.9; wk.stroke() } }
            c(1, 0.6, 0.65).setFill(); let nose = NSBezierPath(); nose.move(to: NSPoint(x: cx-2.5, y: 40)); nose.line(to: NSPoint(x: cx+2.5, y: 40)); nose.line(to: NSPoint(x: cx, y: 37.5)); nose.close(); nose.fill()
        case 6: // 말랑 도자기: squat glossy kawaii ceramic
            let body = NSBezierPath(); body.move(to: NSPoint(x: cx-22, y: 22))
            body.curve(to: NSPoint(x: cx-31, y: 64), controlPoint1: NSPoint(x: cx-44, y: 22), controlPoint2: NSPoint(x: cx-42, y: 56))
            body.line(to: NSPoint(x: cx+31, y: 64))
            body.curve(to: NSPoint(x: cx+22, y: 22), controlPoint1: NSPoint(x: cx+42, y: 56), controlPoint2: NSPoint(x: cx+44, y: 22)); body.close()
            withShadow(NSColor(calibratedRed: 0.2, green: 0.15, blue: 0.35, alpha: 0.35), blur: 8, dy: -3) { c(0.95, 0.94, 0.97).setFill(); body.fill() }
            NSGradient(colors: [c(1, 1, 1), c(0.95, 0.94, 0.97), c(0.82, 0.8, 0.88)], atLocations: [0, 0.45, 1], colorSpace: .deviceRGB)!.draw(in: body, relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
            // warm bounce light from the sill + specular highlights
            NSGraphicsContext.saveGraphicsState(); body.addClip()
            NSGradient(colors: [c(1, 0.86, 0.75, 0.35), c(1, 0.86, 0.75, 0)])!.draw(in: NSRect(x: cx-40, y: 22, width: 80, height: 14), angle: 90)
            NSGraphicsContext.restoreGraphicsState()
            let hl = NSBezierPath(ovalIn: NSRect(x: -3.5, y: -8, width: 7, height: 16)); let tr = NSAffineTransform(); tr.translateX(by: cx-25, yBy: 48); tr.rotate(byDegrees: -25); hl.transform(using: tr as AffineTransform)
            NSColor(white: 1, alpha: 0.9).setFill(); hl.fill(); NSBezierPath(ovalIn: NSRect(x: cx-27, y: 34, width: 3, height: 3)).fill()
            let rim = NSBezierPath(roundedRect: NSRect(x: cx-35, y: 61, width: 70, height: 11), xRadius: 5.5, yRadius: 5.5)
            NSGradient(colors: [c(0.86, 0.85, 0.91), c(1, 1, 1)])!.draw(in: rim, angle: 90)
            NSColor(white: 1, alpha: 0.95).setStroke(); rim.lineWidth = 0.8; rim.stroke()
        case 5: // concrete block
            let body = NSBezierPath(roundedRect: NSRect(x: cx-33, y: 22, width: 66, height: 49), xRadius: R(6), yRadius: R(6)); grad(body, [c(0.8, 0.8, 0.79), c(0.72, 0.72, 0.71), c(0.62, 0.62, 0.61)])
            NSGraphicsContext.saveGraphicsState(); body.addClip(); for k in 0..<40 { NSColor(white: k % 2 == 0 ? 0.5 : 0.9, alpha: 0.35).setFill(); NSBezierPath(ovalIn: NSRect(x: cx - 32 + CGFloat((k*37) % 64), y: 24 + CGFloat((k*53) % 45), width: 1.4, height: 1.4)).fill() }; NSGraphicsContext.restoreGraphicsState()
        default: // terracotta
            let pot = NSBezierPath(); pot.move(to: NSPoint(x: cx-26, y: 22)); pot.line(to: NSPoint(x: cx+26, y: 22)); pot.line(to: NSPoint(x: cx+34, y: 62)); pot.line(to: NSPoint(x: cx-34, y: 62)); pot.close()
            grad(pot, [c(0.86, 0.55, 0.40), c(0.78, 0.47, 0.34), c(0.68, 0.39, 0.29)])
            NSColor(white: 0, alpha: 0.10).setFill(); NSRect(x: cx-33, y: 56, width: 66, height: 4).fill()
            let rim = NSBezierPath(roundedRect: NSRect(x: cx-39, y: 59, width: 78, height: 12), xRadius: R(6), yRadius: R(6))
            grad(rim, [c(0.76, 0.45, 0.33), c(0.88, 0.6, 0.45)], 90)
        }
    }
    override func draw(_ r: NSRect) {
        let cx = bounds.midX
        let dead = st.dead
        drawPot(cx)
        let soil = st.moisture > 1 ? 0.2 : st.moisture < 0.2 ? 0.55 : 0.36
        NSColor(calibratedRed: soil, green: soil*0.7, blue: soil*0.52, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-33, y: 66, width: 66, height: 7)).fill()
        if st.moisture > 1 { NSColor(white: 1, alpha: 0.35).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-12, y: 68.5, width: 9, height: 2)).fill(); NSBezierPath(ovalIn: NSRect(x: cx+6, y: 68, width: 6, height: 2)).fill() }
        // face
        let ink = NSColor(calibratedRed: 0.36, green: 0.2, blue: 0.15, alpha: 0.85); ink.setFill(); ink.setStroke()
        if potStyle == 6 && !dead { let blink = Int(t*10) % 40 == 0
            for dx in [-10.0, 10.0] as [CGFloat] { c(0.2, 0.13, 0.12).setFill(); NSBezierPath(ovalIn: NSRect(x: cx+dx-3.2, y: 40.5, width: 6.4, height: blink ? 1.2 : 7)).fill()
                if !blink { NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: cx+dx-1.6, y: 44, width: 2.4, height: 2.4)).fill(); NSBezierPath(ovalIn: NSRect(x: cx+dx+0.8, y: 42, width: 1.1, height: 1.1)).fill() } }
            ink.setFill() } else if dead { for dx in [-10.0, 10.0] as [CGFloat] { let x = NSBezierPath(); x.move(to: NSPoint(x: cx+dx-3, y: 41)); x.line(to: NSPoint(x: cx+dx+3, y: 47)); x.move(to: NSPoint(x: cx+dx-3, y: 47)); x.line(to: NSPoint(x: cx+dx+3, y: 41)); x.lineWidth = 1.5; x.stroke() } }
        else { let blink = Int(t*10) % 40 == 0; for dx in [-10.0, 10.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: cx+dx-2.5, y: 42, width: 5, height: blink ? 1 : 5)).fill() } }
        let happy = st.health > 0.6 && !dead
        let m = NSBezierPath(); m.move(to: NSPoint(x: cx-6, y: 35)); m.curve(to: NSPoint(x: cx+6, y: 35), controlPoint1: NSPoint(x: cx-3, y: happy ? 30 : 39), controlPoint2: NSPoint(x: cx+3, y: happy ? 30 : 39)); m.lineWidth = 1.6; m.lineCapStyle = .round; m.stroke()
        if potStyle == 6 { for dx in [-18.0, 18.0] as [CGFloat] { let b = NSBezierPath(ovalIn: NSRect(x: cx+dx-5, y: 33.5, width: 10, height: 5.5)); NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.5, blue: 0.55, alpha: happy ? 0.55 : 0.15), NSColor(calibratedRed: 1, green: 0.6, blue: 0.6, alpha: 0)])!.draw(in: b, relativeCenterPosition: .zero) } }
        else { NSColor(calibratedRed: 1, green: 0.55, blue: 0.5, alpha: happy ? 0.35 : 0).setFill(); for dx in [-17.0, 17.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: cx+dx-4, y: 34, width: 8, height: 4)).fill() } }

        guard let s = sp else { return }
        let wilt = CGFloat(dead ? 1 : min(1, (1 - st.health) + (st.moisture < 0.25 ? (0.25 - st.moisture) * 2.4 : 0)))
        let cold = isCold && !(st.covered ?? false) && !dead
        if cold { NSGraphicsContext.current?.cgContext.translateBy(x: sin(t*45) * 0.8, y: 0) }
        let base = NSPoint(x: cx, y: 70)
        if st.age < s.germDays { // seed mound
            NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.18, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-8, y: 70, width: 16, height: 6)).fill()
        } else {
            let p = CGFloat(min(1, (st.age - s.germDays) / (s.matureDays - s.germDays)))
            let shade = outdoorLight > 0 && posFactor < 0.6 ? 0.25 : 0.0
            let leaf0 = dead ? NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.25, alpha: 1) : NSColor(calibratedRed: 0.3 + wilt*0.4, green: 0.7 - wilt*0.25, blue: 0.25, alpha: 1)
            let leaf = leaf0.blended(withFraction: shade, of: NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.3, alpha: 1)) ?? leaf0
            let sway = dead ? 0 : sin(t*1.2) * 3 * (1 - wilt)
            if s.id == "echeveria" { // rosette
                let rr = 8 + 26*p
                for ring in 0..<3 { for k in 0..<8 { let a = CGFloat(k) * .pi/4 + CGFloat(ring)*0.4, rl = rr * (1 - CGFloat(ring)*0.28)
                    let ec = NSColor(calibratedRed: 0.5 + CGFloat(ring)*0.08, green: 0.72, blue: 0.68, alpha: 1)
                    (dead ? leaf : (st.age >= s.matureDays ? (variant?.tint(ec) ?? ec) : ec)).setFill()
                    let lp = NSBezierPath(ovalIn: NSRect(x: -rl*0.25, y: 0, width: rl*0.5, height: rl))
                    let tr = NSAffineTransform(); tr.translateX(by: base.x, yBy: base.y + 4 + rr*0.25); tr.scaleX(by: 1, yBy: 0.45 * (1 - wilt*0.5)); tr.rotate(byRadians: a); lp.transform(using: tr as AffineTransform); lp.fill() } }
                if st.age >= s.matureDays && !dead, let v = variant { v.drawBloom(tip: NSPoint(x: base.x, y: base.y + 4 + rr*0.3), t: t) }
            } else {
                let tall: CGFloat = ["sunflower": 105, "tomato": 85, "rose": 70, "basil": 60, "lettuce": 30, "unicorn": 70, "maratang": 62, "pizza": 66, "cat": 62, "dalgona": 72, "hotteok": 74, "bungeoppang": 76, "soychicken": 76, "yeopddeok": 76, "dakkochi": 66][s.id] ?? 60
                let stemH = 12 + tall*p
                let tip = NSPoint(x: cx + sway + wilt*28, y: base.y + stemH*(1 - wilt*0.4))
                leaf.setStroke(); let sp2 = NSBezierPath(); sp2.move(to: base); sp2.curve(to: tip, controlPoint1: NSPoint(x: cx, y: base.y + stemH*0.5), controlPoint2: NSPoint(x: tip.x - wilt*10, y: tip.y)); sp2.lineWidth = s.id == "sunflower" ? 5 : 3.5; sp2.lineCapStyle = .round; sp2.stroke()
                leaf.setFill()
                let n = p < 0.15 ? 2 : (p < 0.5 ? 4 : 6), big: CGFloat = s.id == "lettuce" ? 1.8 : 1
                for i in 0..<n {
                    let f = CGFloat(i/2 + 1) / CGFloat(n/2 + 1) * 0.9, side: CGFloat = i % 2 == 0 ? 1 : -1
                    let pt = NSPoint(x: base.x + (tip.x - base.x)*f, y: base.y + (tip.y - base.y)*f), sz = (7 + 10*p) * big
                    let tr = NSAffineTransform(); tr.translateX(by: pt.x, yBy: pt.y); tr.rotate(byDegrees: side*(35 + wilt*55) - sway)
                    let lp = NSBezierPath(ovalIn: NSRect(x: side > 0 ? 0 : -sz*1.6, y: -sz*0.35, width: sz*1.6, height: sz*0.75)); lp.transform(using: tr as AffineTransform); lp.fill()
                }
                if !dead && !secret && st.age < s.matureDays && ABSURD.contains(where: { $0.id == s.id }), let v = variant { var pv = v; pv.color = 0; pv.deco = 0; pv.face = 0; pv.drawAbsurd(tip: tip, t: t, k: 0.35 + 0.35 * CGFloat((st.age - s.germDays) / (s.matureDays - s.germDays))) }
                if st.age >= s.matureDays && !dead, let v = variant { v.drawBloom(tip: s.id == "lettuce" ? NSPoint(x: tip.x, y: base.y + 10) : tip, t: t) }
            }
        }
        if cold && st.age >= (sp?.germDays ?? 0) { NSColor(white: 1, alpha: 0.85).setFill()   // frost specks
            for k in 0..<10 { NSBezierPath(ovalIn: NSRect(x: cx - 18 + CGFloat((k*37) % 36), y: 78 + CGFloat((k*23) % 50), width: 2.5, height: 2.5)).fill() } }
        if st.covered ?? false { // glass cloche
            let d = NSBezierPath(); d.move(to: NSPoint(x: cx-38, y: 70)); d.line(to: NSPoint(x: cx-38, y: 150)); d.curve(to: NSPoint(x: cx+38, y: 150), controlPoint1: NSPoint(x: cx-38, y: 195), controlPoint2: NSPoint(x: cx+38, y: 195)); d.line(to: NSPoint(x: cx+38, y: 70)); d.close()
            if glassTheme || potStyle == 6 { drawGlossyCloche(d, cx) } else {
            NSColor(white: 1, alpha: 0.22).setFill(); d.fill(); NSColor(white: 1, alpha: 0.7).setStroke(); d.lineWidth = 1.5; d.stroke()
            NSColor(white: 1, alpha: 0.5).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-26, y: 110, width: 6, height: 40)).fill()
            NSColor(white: 0.9, alpha: 0.9).setFill(); NSBezierPath(ovalIn: NSRect(x: cx-5, y: 176, width: 10, height: 8)).fill() } }
        if gaugeAlpha > 0.01 { NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current?.cgContext.setAlpha(gaugeAlpha); drawGauge(cx); NSGraphicsContext.restoreGraphicsState() }
        if splash > 0 { NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: min(1, splash)).setFill()
            for k in 0..<5 { NSBezierPath(ovalIn: NSRect(x: cx - 20 + CGFloat(k)*10, y: 74 + CGFloat(k*13 % 30) + splash*40, width: 4, height: 6)).fill() } }
        // single action badge (no text)
        if let b = badge ?? (isHot ? "🔥" : nil) {
            let k = max(1, 15 / (18 * sceneScale(self)))      // keep badge ≥ ~15pt on screen
            let bx = cx + 30, by: CGFloat = 76 + 9*(k - 1) + 2*sin(t*2)
            let tr = NSAffineTransform(); tr.translateX(by: bx, yBy: by); tr.scale(by: k); tr.translateX(by: -bx, yBy: -by); NSGraphicsContext.saveGraphicsState(); tr.concat()
            let (sym, col): (String, NSColor) = ["🥶": ("snowflake", Palette.cold), "💧": ("drop.fill", Palette.dry), "💨": ("wind", Palette.wind), "☀️": ("sun.max.fill", Palette.sun), "🔥": ("thermometer.sun.fill", NSColor.systemOrange)][b] ?? ("exclamationmark", .gray)
            NSColor(white: 0, alpha: 0.12).setFill(); NSBezierPath(roundedRect: NSRect(x: bx-9, y: by-10, width: 18, height: 18), xRadius: 9, yRadius: 9).fill()
            NSColor(white: 1, alpha: 0.92).setFill(); NSBezierPath(roundedRect: NSRect(x: bx-9, y: by-9, width: 18, height: 18), xRadius: 9, yRadius: 9).fill()
            drawSymbol(sym, NSRect(x: bx-5.5, y: by-5.5, width: 11, height: 11), col.blended(withFraction: 0.15, of: .black) ?? col)
            NSGraphicsContext.restoreGraphicsState()
        }
        if let msg = toast, toastT > 0 {
            if t - lastToastTick > 0 { toastT -= min(0.2, t - lastToastTick) }; lastToastTick = t
            let a: [NSAttributedString.Key: Any] = [.font: cute(9.5), .foregroundColor: NSColor(white: 0.15, alpha: 1)]
            let ns = msg as NSString, maxW: CGFloat = bounds.width - 8
            var sz = ns.boundingRect(with: NSSize(width: maxW - 12, height: 100), options: [.usesLineFragmentOrigin], attributes: a).size; sz.width = ceil(sz.width); sz.height = ceil(sz.height)
            let alpha = min(1, toastT), box = NSRect(x: cx - (sz.width + 12)/2, y: 196 + (1 - alpha) * 6, width: sz.width + 12, height: sz.height + 8)
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current?.cgContext.setAlpha(alpha)
            NSColor(white: 1, alpha: 0.95).setFill(); NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
            ns.draw(with: NSRect(x: box.minX + 6, y: box.minY + 4, width: sz.width, height: sz.height), options: [.usesLineFragmentOrigin], attributes: a)
            NSGraphicsContext.restoreGraphicsState()
            if toastT <= 0 { toast = nil }
        }
    }
    var lastToastTick: CGFloat = 0
}

extension PlantView {
    func drawGlossyCloche(_ d: NSBezierPath, _ cx: CGFloat) {
        NSGradient(colors: [NSColor(white: 1, alpha: 0.10), NSColor(white: 1, alpha: 0.04), NSColor(white: 1, alpha: 0.22)], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: d, angle: 0)
        NSGraphicsContext.saveGraphicsState(); d.addClip()
        NSGradient(colors: [NSColor(white: 1, alpha: 0.75), NSColor(white: 1, alpha: 0)])!.draw(in: NSRect(x: cx-34, y: 72, width: 10, height: 112), angle: 0)    // left rim light
        NSGradient(colors: [NSColor(white: 1, alpha: 0), NSColor(white: 1, alpha: 0.55)])!.draw(in: NSRect(x: cx+27, y: 72, width: 11, height: 100), angle: 0)    // right rim light
        NSGraphicsContext.restoreGraphicsState()
        let streak = NSBezierPath(roundedRect: NSRect(x: cx-25, y: 104, width: 5, height: 52), xRadius: 2.5, yRadius: 2.5)
        NSGradient(colors: [NSColor(white: 1, alpha: 0.05), NSColor(white: 1, alpha: 0.85), NSColor(white: 1, alpha: 0.1)])!.draw(in: streak, angle: 90)
        let cap = NSBezierPath(); cap.appendArc(withCenter: NSPoint(x: cx, y: 150), radius: 31, startAngle: 120, endAngle: 160); cap.lineWidth = 3; cap.lineCapStyle = .round; NSColor(white: 1, alpha: 0.7).setStroke(); cap.stroke()
        NSColor(white: 1, alpha: 0.8).setStroke(); d.lineWidth = 1.1; d.stroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: cx-38, y: 66.5, width: 76, height: 7)); NSColor(white: 1, alpha: 0.55).setStroke(); ring.lineWidth = 1.2; ring.stroke()
        let knob = NSBezierPath(ovalIn: NSRect(x: cx-6, y: 176, width: 12, height: 10))
        withShadow(NSColor(white: 0, alpha: 0.2), blur: 2, dy: -1) { NSColor(white: 0.97, alpha: 0.95).setFill(); knob.fill() }
        NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: cx-3.5, y: 181, width: 3, height: 2.5)).fill()
    }
    var levelInfo: (Int, String, Double)? {
        guard let s = sp, !st.dead else { return nil }
        let names = ["씨앗", "새싹", "꼬마 식물", "다 자람"]
        let lv = st.age < s.germDays ? 1 : st.age < s.germDays + (s.matureDays - s.germDays) * 0.35 ? 2 : st.age < s.matureDays ? 3 : 4
        return (lv, names[lv - 1], min(1, st.age / s.matureDays))
    }
    /// Plant top (scene units) to float the gauge above the foliage
    var plantTopY: CGFloat {
        guard let s = sp else { return 76 }
        if st.age < s.germDays { return 78 }
        let p = CGFloat(min(1, (st.age - s.germDays) / (s.matureDays - s.germDays)))
        if s.id == "echeveria" { return 80 + 30*p }
        let tall: CGFloat = ["sunflower": 105, "tomato": 85, "rose": 70, "basil": 60, "lettuce": 30][s.id] ?? 72
        return 82 + tall*p + (st.age >= s.matureDays ? (ABSURD.contains { $0.id == s.id } ? 44 : 22) : 10)
    }
    /// Small frosted growth chip: '레벨 N 씨앗' + bar + '성장도 12%' (fixed min on-screen size)
    func drawGauge(_ cx: CGFloat) {
        guard let (lv, nm, g) = levelInfo else { return }
        let sc = sceneScale(self), fs = max(8, 9 / sc), compact = fs > 12
        let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fs, weight: .medium), .foregroundColor: NSColor(calibratedRed: 0.22, green: 0.2, blue: 0.3, alpha: 1)]
        let l1 = (compact ? "Lv.\(lv) \(nm)" : "레벨 \(lv) \(nm)") as NSString, l2 = String(format: compact ? "%.0f%%" : "성장도 %.0f%%", g * 100) as NSString
        let s1 = l1.size(withAttributes: a), s2 = l2.size(withAttributes: a)
        let barH = max(2.5, 3 / sc), gap = max(2, 2.5 / sc)
        let wInner = max(s1.width, s2.width, 40), h = s1.height + gap + barH + gap + s2.height
        let covered = st.covered ?? false
        var y = max(covered ? 112 : 0, plantTopY + 6); y = min(y, bounds.height - h - 6)
        let box = NSRect(x: cx - wInner/2 - 6, y: y, width: wInner + 12, height: h + 8)
        if !covered { withShadow(NSColor(calibratedRed: 0.2, green: 0.15, blue: 0.35, alpha: 0.25), blur: 4, dy: -1) { NSColor(white: 1, alpha: 0.72).setFill(); NSBezierPath(roundedRect: box, xRadius: min(8, box.height/2), yRadius: min(8, box.height/2)).fill() } }
        var ty = box.maxY - 4 - s1.height
        l1.draw(at: NSPoint(x: cx - s1.width/2, y: ty), withAttributes: a); ty -= gap + barH
        let track = NSRect(x: cx - wInner/2, y: ty, width: wInner, height: barH)
        NSColor(white: 1, alpha: 0.9).setFill(); NSBezierPath(roundedRect: track, xRadius: barH/2, yRadius: barH/2).fill()
        NSColor(white: 0, alpha: 0.08).setStroke(); NSBezierPath(roundedRect: track, xRadius: barH/2, yRadius: barH/2).stroke()
        NSColor(calibratedRed: 0.36, green: 0.75, blue: 0.4, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: max(barH, track.width * CGFloat(g)), height: barH), xRadius: barH/2, yRadius: barH/2).fill()
        ty -= gap + s2.height; l2.draw(at: NSPoint(x: cx - s2.width/2, y: ty), withAttributes: a)
    }
}
