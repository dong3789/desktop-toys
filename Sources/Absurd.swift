import AppKit

/// Mystery-seed outcomes: silly plants with their own playful care rules
let ABSURD: [Species] = [
    Species(id: "unicorn", name: "유니콘", emoji: "🦄", germDays: 8, matureDays: 70, waterEvery: 2.5, overwaterHarm: 0.12, lightNeed: 0.5, lightText: "햇빛 아주 많이 (반짝임 충전용)",
            tips: ["유니콘은 햇빛으로 반짝임을 충전해요 ✨", "뿔이 빛나면 기분이 좋다는 뜻이에요.", "햇살 자리 한가운데를 제일 좋아해요 🌈"]),
    Species(id: "yeopddeok", name: "엽기떡볶이", emoji: "🌶️", germDays: 5, matureDays: 50, waterEvery: 2, overwaterHarm: 0.12, lightNeed: 0.35, lightText: "따뜻한 햇빛",
            tips: ["엽떡이가 맵기를 원해요 🌶", "추우면 소스가 굳어요. 따뜻하게 해 주세요.", "주먹밥 친구가 있으면 덜 매워해요 🍙"]),
    Species(id: "maratang", name: "마라탕", emoji: "🍲", germDays: 5, matureDays: 55, waterEvery: 1.5, overwaterHarm: 0.08, lightNeed: 0.3, lightText: "따끈한 곳",
            tips: ["마라탕은 뜨끈해야 행복해요 🔥", "국물이 줄면 물을 부어 주세요 (육수 아님 주의).", "추위를 정말 싫어해요. 쌀쌀하면 덮개를!"]),
    Species(id: "dakkochi", name: "닭꼬치", emoji: "🍢", germDays: 6, matureDays: 55, waterEvery: 2.5, overwaterHarm: 0.12, lightNeed: 0.38, lightText: "햇빛에 노릇노릇",
            tips: ["햇빛을 받으면 노릇하게 구워져요.", "꼬치 가지가 휘면 지지대를 대 주세요.", "파는 편식하지 말아요 🧅"]),
    Species(id: "bungeoppang", name: "붕어빵", emoji: "🐟", germDays: 6, matureDays: 55, waterEvery: 2.5, overwaterHarm: 0.15, lightNeed: 0.3, lightText: "보통 햇빛, 추운 날 최고",
            tips: ["붕어빵은 겨울을 좋아해요 ❄️ 추울수록 잘 자라요.", "더우면 눅눅해져요.", "머리부터 먹을지 꼬리부터 먹을지 미리 정해 두세요."]),
    Species(id: "pizza", name: "피자", emoji: "🍕", germDays: 6, matureDays: 60, waterEvery: 6, overwaterHarm: 0.35, lightNeed: 0.4, lightText: "오븐처럼 밝게",
            tips: ["피자는 물을 적게! 눅눅한 도우는 싫대요.", "햇빛을 받으면 치즈가 쭉 늘어나요 🧀", "파인애플 얘기는 꺼내지 마세요."]),
    Species(id: "soychicken", name: "간장치킨", emoji: "🍗", germDays: 6, matureDays: 60, waterEvery: 2.5, overwaterHarm: 0.12, lightNeed: 0.38, lightText: "따뜻한 햇빛",
            tips: ["간장 소스가 윤기 나게 햇빛을 쬐어 주세요.", "닭다리는 두 개뿐… 아니 여기선 많이 열려요!", "추우면 소스가 굳어요."]),
    Species(id: "hotteok", name: "호떡", emoji: "🥞", germDays: 5, matureDays: 50, waterEvery: 2.5, overwaterHarm: 0.15, lightNeed: 0.3, lightText: "보통 햇빛, 겨울 간식",
            tips: ["호떡은 찬바람 불 때 잘 자라요 🌬", "꿀이 흐르면 다 익은 거예요.", "뜨거울 때 조심! 입천장 주의."]),
    Species(id: "dalgona", name: "달고나", emoji: "🍭", germDays: 6, matureDays: 55, waterEvery: 4, overwaterHarm: 0.3, lightNeed: 0.35, lightText: "선선한 햇빛",
            tips: ["달고나는 물에 약해요. 조금씩만!", "더우면 녹아내려요 🫠", "모양대로 떼어내면 한 번 더!"]),
    Species(id: "cat", name: "고양이", emoji: "🐱", germDays: 7, matureDays: 65, waterEvery: 3, overwaterHarm: 0.15, lightNeed: 0.42, lightText: "햇볕 낮잠 자리",
            tips: ["고양이풀은 햇볕 자리에서 낮잠을 자야 자라요 😺", "물은 싫어하는 척하지만 필요해요.", "꾹꾹이를 하면 기분이 좋은 거예요."]),
]
let ALL_SPECIES = SPECIES + ABSURD
let ABSURD_MIN: [String: Double] = ["unicorn": 5, "yeopddeok": 12, "maratang": 16, "dakkochi": 8, "bungeoppang": -10, "pizza": 10, "soychicken": 10, "hotteok": -5, "dalgona": 0, "cat": 8]
/// melts / goes soggy above this
let MAX_TEMP: [String: Double] = ["bungeoppang": 24, "hotteok": 26, "dalgona": 24]
let COLD_LOVERS: Set<String> = ["bungeoppang", "hotteok"]
let HEAT_TIP: [String: String] = ["bungeoppang": "붕어빵이 더워서 눅눅해져요. 선선해지면 회복돼요.", "hotteok": "호떡 꿀이 너무 녹아요. 선선해지길 기다려요.", "dalgona": "달고나가 녹고 있어요 🫠 선선해지면 회복돼요."]
let SOGGY_TIP: [String: String] = ["pizza": "도우가 눅눅해졌어요! 흙이 마를 때까지 물 금지 🍕", "dalgona": "달고나가 물에 녹아요! 마를 때까지 기다려요."]
let COLD_TIP: [String: String] = ["maratang": "마라탕이 식어가요! 덮개를 덮어 주세요 🥶", "yeopddeok": "엽떡 소스가 굳어요! 덮개를 덮어 주세요."]
/// pool weights: real plants share ~50%, absurd ones ~50% by rarity
let ABSURD_WEIGHT: [String: Double] = ["unicorn": 1.5, "cat": 3.5, "dalgona": 4.5, "maratang": 6, "yeopddeok": 6, "dakkochi": 6, "bungeoppang": 6, "pizza": 6, "soychicken": 6, "hotteok": 4.5]
let ABSURD_RARITY: [String: String] = ["unicorn": "🌟전설", "cat": "✨희귀", "dalgona": "✨희귀", "hotteok": "✨희귀"]
func randomMysterySpecies() -> Species {
    if Double.random(in: 0..<1) < 0.5 { return SPECIES.randomElement()! }
    let tot = ABSURD_WEIGHT.values.reduce(0, +); var r = Double.random(in: 0..<tot)
    for s in ABSURD { r -= ABSURD_WEIGHT[s.id] ?? 1; if r < 0 { return s } }
    return ABSURD[0]
}
let HARVEST_LINES: [String: [String]] = [
    "yeopddeok": ["스읍… 하… 맵다! 쿨피스 어디 있어요? 🥤", "엽떡 한 접시 수확! 오늘 저녁은 해결 🌶"],
    "maratang": ["마라 한 그릇 완성! 3단계 맵기예요 🔥", "꿔바로우도 같이 열렸으면 좋겠다…"],
    "dakkochi": ["꼬치 수확! 소스는 데리야끼? 매운맛?", "꼬치가 너무 잘 익었어요. 바로 먹어야 해요 🍢"],
    "bungeoppang": ["붕어빵 수확! 머리부터? 꼬리부터? 🐟", "팥 vs 슈크림… 오늘은 팥이에요."],
    "pizza": ["피자 한 판 수확! 치즈가 쭈욱~ 🧀", "도우 끝까지 먹는 사람 손! 🍕"],
    "soychicken": ["간장치킨 수확! 1인 1닭 가능 🍗", "닭다리 쟁탈전 시작… 오늘은 내 거!"],
    "hotteok": ["호떡 수확! 꿀 조심, 뜨거워요 🔥", "씨앗호떡이 열렸어요. 고소해요!"],
    "dalgona": ["달고나 수확! 모양대로 떼어 볼까요? 🍭", "바늘 준비… 숨 참고… 성공!"],
    "unicorn": ["유니콘이 무지개를 남기고 날아갔어요 🌈", "반짝! 유니콘 털 한 가닥을 얻었어요 ✨"],
    "cat": ["고양이가 골골송을 불러줬어요 😻", "츄르를 주고 쓰다듬기 성공!"],
]

extension Variant {
    func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
    func oval(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath { NSBezierPath(ovalIn: NSRect(x: c.x - w/2, y: c.y - h/2, width: w, height: h)) }
    func shine(_ c: NSPoint, _ w: CGFloat) { NSColor(white: 1, alpha: 0.55).setFill(); oval(c, w, w*0.6).fill() }
    func sparkles(_ c: NSPoint, _ rad: CGFloat, _ n: Int, _ t: CGFloat, _ color: NSColor = NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: 1)) {
        for i in 0..<n { let a = CGFloat(i) * 2 * .pi / CGFloat(n) + t * 0.6, rr = rad * (0.8 + 0.25 * sin(t * 2 + CGFloat(i)))
            color.withAlphaComponent(0.45 + 0.55 * abs(sin(t * 2.5 + CGFloat(i) * 1.7))).setFill()
            Variant.star(NSPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr), 2.6 + CGFloat(i % 2)).fill() }
    }
    func stick(_ a: NSPoint, _ b: NSPoint, _ w: CGFloat = 1.6) { col(0.78, 0.62, 0.42).setStroke(); let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.lineWidth = w; p.lineCapStyle = .round; p.stroke() }
    func hangStem(_ from: NSPoint, _ to: NSPoint) { col(0.3, 0.6, 0.3).setStroke(); let p = NSBezierPath(); p.move(to: from); p.line(to: to); p.lineWidth = 1.2; p.stroke() }

    /// Draw an absurd plant's "fruit" at the stem tip. k = scale (preview while growing = ~0.55)
    func drawAbsurd(tip: NSPoint, t: CGFloat, k: CGFloat = 1) {
        NSGraphicsContext.saveGraphicsState()
        let tr = NSAffineTransform(); tr.translateX(by: tip.x, yBy: tip.y); tr.scale(by: k * 1.3); tr.concat()
        let o = NSPoint.zero
        switch speciesId {
        case "unicorn":
            let bob = sin(t * 2) * 1.5
            let body = oval(NSPoint(x: 0, y: 6 + bob), 30, 18)
            let white = col(0.99, 0.97, 1)
            // legs
            for lx in [-9.0, -4.0, 4.0, 9.0] as [CGFloat] { let leg = NSBezierPath(roundedRect: NSRect(x: lx - 2, y: -6 + bob, width: 4, height: 10), xRadius: 2, yRadius: 2); white.blended(withFraction: 0.08, of: .gray)!.setFill(); leg.fill()
                col(0.85, 0.75, 0.95).setFill(); NSRect(x: lx - 2, y: -6 + bob, width: 4, height: 2.5).fill() }
            fill(body, white, body.bounds, t: t)
            // tail
            for (i, c) in Variant.rainbow.enumerated() where i % 2 == 0 { c.withAlphaComponent(0.9).setStroke(); let p = NSBezierPath(); p.move(to: NSPoint(x: -14, y: 9 + bob)); p.curve(to: NSPoint(x: -24, y: -2 + bob + CGFloat(i)), controlPoint1: NSPoint(x: -22, y: 14 + bob), controlPoint2: NSPoint(x: -26 + sin(t*3)*2, y: 6 + bob)); p.lineWidth = 2.6; p.lineCapStyle = .round; p.stroke() }
            // neck + head
            let neck = NSBezierPath(); neck.move(to: NSPoint(x: 7, y: 10 + bob)); neck.line(to: NSPoint(x: 14, y: 24 + bob)); neck.line(to: NSPoint(x: 20, y: 22 + bob)); neck.line(to: NSPoint(x: 15, y: 6 + bob)); neck.close(); tint(white).setFill(); neck.fill()
            let head = oval(NSPoint(x: 18, y: 25 + bob), 16, 13); fill(head, white, head.bounds, t: t)
            tint(white).setFill(); oval(NSPoint(x: 24, y: 22 + bob), 9, 8).fill()
            col(1, 0.75, 0.85).setFill(); oval(NSPoint(x: 26, y: 21.5 + bob), 2, 1.6).fill()
            // ear + horn
            let ear = NSBezierPath(); ear.move(to: NSPoint(x: 13, y: 29 + bob)); ear.line(to: NSPoint(x: 14, y: 36 + bob)); ear.line(to: NSPoint(x: 17, y: 30 + bob)); ear.close(); tint(white).setFill(); ear.fill()
            let horn = NSBezierPath(); horn.move(to: NSPoint(x: 18, y: 30 + bob)); horn.line(to: NSPoint(x: 23, y: 44 + bob)); horn.line(to: NSPoint(x: 22, y: 30 + bob)); horn.close()
            col(1, 0.82, 0.3).setFill(); horn.fill(); col(1, 0.95, 0.7).setStroke(); for hy in [33.0, 37.0] as [CGFloat] { let s = NSBezierPath(); s.move(to: NSPoint(x: 18.8, y: hy + bob)); s.line(to: NSPoint(x: 22.2, y: hy + 1.5 + bob)); s.lineWidth = 0.8; s.stroke() }
            // mane
            for (i, c) in Variant.rainbow.enumerated() { c.setFill(); oval(NSPoint(x: 12 - CGFloat(i) * 1.2, y: 30 - CGFloat(i) * 3.2 + bob), 7, 5).fill() }
            NSColor(white: 0.12, alpha: 0.9).setFill(); oval(NSPoint(x: 20, y: 26 + bob), 2.4, face == 3 ? 0.8 : 2.8).fill()
            col(1, 0.6, 0.7, 0.5).setFill(); oval(NSPoint(x: 21, y: 22.5 + bob), 4, 2.2).fill()
            if deco == 3 { drawCrown(NSPoint(x: 15, y: 31 + bob), 9) }
            if deco == 2 { NSColor(white: 0.1, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: 17, y: 24.5 + bob, width: 6, height: 3.5), xRadius: 1, yRadius: 1).fill() }
            sparkles(NSPoint(x: 4, y: 18), 30, 7, t)
        case "yeopddeok":
            for (j, (dx, dy, rot)) in [(-16.0, -14.0, 12.0), (2.0, -4.0, -4.0), (17.0, -18.0, -14.0)].enumerated() {
                NSGraphicsContext.saveGraphicsState(); let q = NSAffineTransform(); q.translateX(by: CGFloat(dx), yBy: CGFloat(dy)); q.rotate(byDegrees: CGFloat(rot) + sin(t*1.5 + CGFloat(j)) * 3); q.concat()
                hangStem(NSPoint(x: 0, y: 18), NSPoint(x: -CGFloat(dx)*0.4, y: 26 - CGFloat(dy)*0.5))
                stick(NSPoint(x: 0, y: 20), NSPoint(x: 0, y: -22), 1.4)
                for m in 0..<2 { let cy = 8 - CGFloat(m) * 15; let cake = NSBezierPath(roundedRect: NSRect(x: -4.5, y: cy - 6.5, width: 9, height: 13), xRadius: 3.5, yRadius: 3.5)
                    fill(cake, col(0.9, 0.18, 0.12), cake.bounds, t: t); NSColor(white: 1, alpha: 0.5).setFill(); NSBezierPath(roundedRect: NSRect(x: -2.8, y: cy - 3, width: 2, height: 7), xRadius: 1, yRadius: 1).fill()
                    col(0.75, 0.1, 0.06).setFill(); oval(NSPoint(x: 2.5, y: cy - 6.5), 3, 2.5).fill()
                    if m == 1 && j == 1 && face > 0 { drawFace(NSPoint(x: 0, y: cy), 5) } }
                NSGraphicsContext.restoreGraphicsState() }
            // sauce drops falling
            for i in 0..<3 { let ph = (t * 0.5 + CGFloat(i) * 0.33).truncatingRemainder(dividingBy: 1); let x = CGFloat(i - 1) * 16 + 2, y = -26 - ph * 22
                col(0.85, 0.12, 0.08, 1 - ph).setFill(); let d = NSBezierPath(); d.move(to: NSPoint(x: x, y: y + 5)); d.curve(to: NSPoint(x: x, y: y + 5), controlPoint1: NSPoint(x: x - 4, y: y - 3), controlPoint2: NSPoint(x: x + 4, y: y - 3)); d.fill() }
            col(0.95, 0.2, 0.1).setFill(); let ch = NSBezierPath(); ch.move(to: NSPoint(x: 8, y: 20)); ch.curve(to: NSPoint(x: 22, y: 30), controlPoint1: NSPoint(x: 10, y: 28), controlPoint2: NSPoint(x: 16, y: 32)); ch.curve(to: NSPoint(x: 8, y: 20), controlPoint1: NSPoint(x: 18, y: 26), controlPoint2: NSPoint(x: 12, y: 21)); ch.fill()
            col(0.3, 0.62, 0.3).setFill(); oval(NSPoint(x: 7.5, y: 20.5), 4, 3).fill()
            if deco == 3 { drawCrown(NSPoint(x: 2, y: 20), 12) }
        case "maratang":
            // bloom petals behind the bowl
            for i in 0..<8 { let a = CGFloat(i) * .pi / 4 + .pi/8 + t*0.04; NSGraphicsContext.saveGraphicsState(); let q = NSAffineTransform(); q.translateX(by: 0, yBy: 4); q.rotate(byRadians: a); q.concat()
                col(0.98, 0.45, 0.35).blended(withFraction: CGFloat(i % 2) * 0.2, of: .white)!.setFill(); oval(NSPoint(x: 0, y: 20), 11, 16).fill(); NSGraphicsContext.restoreGraphicsState() }
            let bowl = NSBezierPath(); bowl.move(to: NSPoint(x: -21, y: 6)); bowl.curve(to: NSPoint(x: 21, y: 6), controlPoint1: NSPoint(x: -20, y: -16), controlPoint2: NSPoint(x: 20, y: -16)); bowl.close()
            fill(bowl, NSColor(white: 0.98, alpha: 1), bowl.bounds, t: t)
            col(0.85, 0.2, 0.15).setStroke(); for i in 0..<5 { let x = -12 + CGFloat(i) * 6; let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: -1)); p.line(to: NSPoint(x: x + 3, y: 2)); p.line(to: NSPoint(x: x + 6, y: -1)); p.lineWidth = 1.1; p.stroke() }
            col(0.82, 0.16, 0.08).setFill(); oval(NSPoint(x: 0, y: 6), 42, 9).fill()
            col(0.98, 0.9, 0.7).setStroke(); for i in 0..<3 { let p = NSBezierPath(); p.move(to: NSPoint(x: -14 + CGFloat(i)*4, y: 5)); p.curve(to: NSPoint(x: 2 + CGFloat(i)*4, y: 6), controlPoint1: NSPoint(x: -9 + CGFloat(i)*4, y: 9), controlPoint2: NSPoint(x: -4 + CGFloat(i)*4, y: 3)); p.lineWidth = 1; p.stroke() }
            col(0.4, 0.75, 0.35).setFill(); oval(NSPoint(x: 9, y: 7.5), 9, 4).fill()
            NSColor(white: 0.97, alpha: 1).setFill(); NSRect(x: -6, y: 5.5, width: 5, height: 4).fill(); NSRect(x: 13, y: 4.5, width: 4, height: 3.5).fill()
            col(1, 0.75, 0.2).setFill(); for (x, y) in [(-16.0, 6.0), (3.0, 8.0), (16.0, 7.0)] as [(CGFloat, CGFloat)] { oval(NSPoint(x: x, y: y), 2, 2).fill() }
            if face > 0 { drawFace(NSPoint(x: 0, y: -5), 7) }
            NSColor(white: 1, alpha: 0.75).setStroke()
            for i in 0..<3 { let x = CGFloat(i - 1) * 9, ph = (t * 0.4 + CGFloat(i) * 0.3).truncatingRemainder(dividingBy: 1)
                let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: 12 + ph * 6)); p.curve(to: NSPoint(x: x, y: 26 + ph * 6), controlPoint1: NSPoint(x: x + 4, y: 17 + ph * 6), controlPoint2: NSPoint(x: x - 4, y: 21 + ph * 6)); p.lineWidth = 1.6; p.lineCapStyle = .round
                NSColor(white: 1, alpha: 0.8 * (1 - ph)).setStroke(); p.stroke() }
            if deco == 3 { drawCrown(NSPoint(x: 0, y: 30), 14) }
        case "dakkochi":
            for (j, (ang, len)) in [(28.0, 30.0), (-30.0, 30.0), (88.0, 26.0)].enumerated() {
                NSGraphicsContext.saveGraphicsState(); let q = NSAffineTransform(); q.translateX(by: 0, yBy: j == 2 ? 0 : -14); q.rotate(byDegrees: CGFloat(ang) - 90 + sin(t*1.2 + CGFloat(j))*2); q.concat()
                stick(NSPoint(x: 0, y: 0), NSPoint(x: 0, y: CGFloat(len) + 6), 1.6)
                for m in 0..<4 { let y = 6 + CGFloat(m) * 6.5
                    if m % 2 == 1 { col(0.92, 0.95, 0.85).setFill(); NSBezierPath(roundedRect: NSRect(x: -3.5, y: y - 2.5, width: 7, height: 5), xRadius: 1.5, yRadius: 1.5).fill(); col(0.45, 0.75, 0.35).setFill(); NSRect(x: -3.5, y: y - 2.5, width: 2.5, height: 5).fill() }
                    else { let ch = NSBezierPath(roundedRect: NSRect(x: -5.5, y: y - 3.5, width: 11, height: 7.5), xRadius: 3, yRadius: 3); fill(ch, col(0.82, 0.5, 0.22), ch.bounds, t: t); shine(NSPoint(x: -2, y: y + 1.5), 3)
                        col(0.55, 0.28, 0.12, 0.6).setStroke(); let g = NSBezierPath(); g.move(to: NSPoint(x: -4, y: y - 1)); g.line(to: NSPoint(x: 4, y: y - 1)); g.lineWidth = 0.9; g.stroke() } }
                if j == 2 && face > 0 { drawFace(NSPoint(x: 0, y: 25.5), 5) }
                NSGraphicsContext.restoreGraphicsState() }
            if deco == 3 { drawCrown(NSPoint(x: 0, y: 34), 11) }
        case "bungeoppang":
            for (j, (dx, dy, s)) in [(-15.0, -16.0, 0.85), (14.0, -26.0, 0.85), (0.0, 2.0, 1.0)].enumerated() {
                let c = NSPoint(x: CGFloat(dx), y: CGFloat(dy) + sin(t*1.4 + CGFloat(j))*1.2), sc = CGFloat(s)
                hangStem(NSPoint(x: c.x, y: c.y + 7*sc), NSPoint(x: CGFloat(dx)*0.3, y: 10))
                let tail = NSBezierPath(); tail.move(to: NSPoint(x: c.x + 10*sc, y: c.y)); tail.line(to: NSPoint(x: c.x + 19*sc, y: c.y + 7*sc)); tail.curve(to: NSPoint(x: c.x + 19*sc, y: c.y - 7*sc), controlPoint1: NSPoint(x: c.x + 16*sc, y: c.y), controlPoint2: NSPoint(x: c.x + 16*sc, y: c.y)); tail.close()
                let body = oval(c, 25*sc, 15*sc); body.append(tail)
                fill(body, col(0.86, 0.6, 0.28), body.bounds, t: t)
                col(0.7, 0.45, 0.2, 0.7).setStroke()
                for m in 0..<3 { let a = NSBezierPath(); a.appendArc(withCenter: NSPoint(x: c.x + CGFloat(m)*4*sc, y: c.y), radius: 3.5*sc, startAngle: 120, endAngle: 240); a.lineWidth = 0.9; a.stroke() }
                let fin = NSBezierPath(); fin.move(to: NSPoint(x: c.x - 3*sc, y: c.y + 7*sc)); fin.curve(to: NSPoint(x: c.x + 7*sc, y: c.y + 6*sc), controlPoint1: NSPoint(x: c.x, y: c.y + 11*sc), controlPoint2: NSPoint(x: c.x + 5*sc, y: c.y + 10*sc)); fin.lineWidth = 1; fin.stroke()
                shine(NSPoint(x: c.x - 4*sc, y: c.y + 3*sc), 4*sc)
                if face > 0 && j == 2 { drawFace(NSPoint(x: c.x - 6*sc, y: c.y + 1), 5*sc) } else { NSColor(white: 0.15, alpha: 0.9).setFill(); oval(NSPoint(x: c.x - 7*sc, y: c.y + 2*sc), 2.4*sc, 2.4*sc).fill() }
                if j == 2 && deco == 3 { drawCrown(NSPoint(x: c.x - 4, y: c.y + 7), 10) }
                if j == 2 && deco == 2 { NSColor(white: 0.1, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: c.x - 10*sc, y: c.y, width: 7*sc, height: 4*sc), xRadius: 1, yRadius: 1).fill() } }
        case "pizza":
            let r: CGFloat = 20, rot = t * 0.15
            col(0.85, 0.62, 0.32).setFill(); oval(o, 2*r + 5, 2*r + 5).fill()
            let cheese = oval(o, 2*r - 1, 2*r - 1); fill(cheese, col(1, 0.83, 0.35), cheese.bounds, t: t)
            col(0.95, 0.72, 0.25).setFill(); for i in 0..<6 { let a = CGFloat(i) * 1.1 + rot; oval(NSPoint(x: cos(a)*r*0.5, y: sin(a)*r*0.6), 6, 4).fill() }
            col(0.85, 0.65, 0.3, 0.5).setStroke(); for i in 0..<4 { let a = CGFloat(i) * .pi / 4 + rot; let p = NSBezierPath(); p.move(to: NSPoint(x: cos(a)*r, y: sin(a)*r)); p.line(to: NSPoint(x: -cos(a)*r, y: -sin(a)*r)); p.lineWidth = 0.8; p.stroke() }
            for (i, (pr, pa)) in [(0.55, 0.3), (0.6, 1.9), (0.58, 3.5), (0.62, 5.0), (0.15, 0.0)].enumerated() { let a = CGFloat(pa) + rot, rr = CGFloat(pr) * r
                if face > 0 && i == 4 { continue }
                col(0.82, 0.22, 0.18).setFill(); oval(NSPoint(x: cos(a)*rr, y: sin(a)*rr), 7, 7).fill(); col(0.65, 0.15, 0.12).setFill(); oval(NSPoint(x: cos(a)*rr + 1, y: sin(a)*rr - 1), 2, 2).fill() }
            col(0.3, 0.6, 0.28).setFill(); for i in 0..<3 { let a = CGFloat(i) * 2.1 + 1 + rot; oval(NSPoint(x: cos(a)*r*0.35, y: sin(a)*r*0.75), 4, 2.6).fill() }
            if face > 0 { drawFace(NSPoint(x: 0, y: 0), 8) }
            // cheese drip
            col(1, 0.83, 0.35).setFill(); let dl = 4 + 3 * (1 + sin(t * 1.5)); NSBezierPath(roundedRect: NSRect(x: 8, y: -r - dl, width: 3.5, height: dl + 3), xRadius: 1.75, yRadius: 1.75).fill()
            if deco == 3 { drawCrown(NSPoint(x: 0, y: r + 1), 13) }
        case "soychicken":
            for (j, (dx, dy, rot)) in [(-15.0, -12.0, 25.0), (14.0, -20.0, -20.0), (0.0, 2.0, 0.0)].enumerated() {
                NSGraphicsContext.saveGraphicsState(); let q = NSAffineTransform(); q.translateX(by: CGFloat(dx), yBy: CGFloat(dy)); q.rotate(byDegrees: CGFloat(rot) + sin(t*1.3 + CGFloat(j))*4); q.concat()
                hangStem(NSPoint(x: 0, y: 12), NSPoint(x: -CGFloat(dx)*0.5, y: 18 - CGFloat(dy)*0.6))
                NSColor(white: 0.97, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: -1.8, y: 4, width: 3.6, height: 10), xRadius: 1.5, yRadius: 1.5).fill()
                oval(NSPoint(x: -2.2, y: 14), 4.4, 4.4).fill(); oval(NSPoint(x: 2.2, y: 14), 4.4, 4.4).fill()
                let meat = NSBezierPath(); meat.move(to: NSPoint(x: -3, y: 6)); meat.curve(to: NSPoint(x: 3, y: 6), controlPoint1: NSPoint(x: -14, y: -16), controlPoint2: NSPoint(x: 14, y: -16)); meat.close()
                fill(meat, col(0.55, 0.3, 0.12), meat.bounds, t: t)
                col(0.75, 0.45, 0.2, 0.8).setFill(); oval(NSPoint(x: -2.5, y: -2), 4, 6).fill(); shine(NSPoint(x: -3, y: -1), 3)
                NSColor(white: 1, alpha: 0.95).setFill(); for (sx, sy) in [(2.0, -4.0), (4.0, 0.0), (-1.0, -8.0)] as [(CGFloat, CGFloat)] { oval(NSPoint(x: sx, y: sy), 1.4, 0.9).fill() }
                if j == 2 && face > 0 { drawFace(NSPoint(x: 0, y: -4), 5.5) }
                if j == 2 && deco == 3 { drawCrown(NSPoint(x: 0, y: 17), 10) }
                NSGraphicsContext.restoreGraphicsState() }
        case "hotteok":
            for (j, (dx, dy, s)) in [(-15.0, -16.0, 0.8), (15.0, -22.0, 0.8), (0.0, 2.0, 1.0)].enumerated() {
                let c = NSPoint(x: CGFloat(dx), y: CGFloat(dy) + sin(t*1.2 + CGFloat(j))), sc = CGFloat(s)
                hangStem(NSPoint(x: c.x, y: c.y + 8*sc), NSPoint(x: CGFloat(dx)*0.3, y: 10))
                let b = oval(c, 26*sc, 16*sc); fill(b, col(0.88, 0.62, 0.3), b.bounds, t: t)
                col(0.97, 0.78, 0.45).setFill(); oval(NSPoint(x: c.x - 2, y: c.y + 2*sc), 16*sc, 8*sc).fill()
                col(0.55, 0.28, 0.1).setFill(); let dl = (3 + 3 * (1 + sin(t*1.3 + CGFloat(j)))) * sc
                NSBezierPath(roundedRect: NSRect(x: c.x + 5*sc, y: c.y - 6*sc - dl, width: 3*sc, height: dl + 4*sc), xRadius: 1.5*sc, yRadius: 1.5*sc).fill()
                oval(NSPoint(x: c.x + 6.5*sc, y: c.y - 6*sc - dl), 4*sc, 4*sc).fill()
                col(0.95, 0.9, 0.75).setFill(); for m in 0..<5 { oval(NSPoint(x: c.x - 8*sc + CGFloat(m)*4*sc, y: c.y + CGFloat((m*7) % 5 - 2)*sc), 1.8*sc, 1.1*sc).fill() }
                if j == 2 && face > 0 { drawFace(NSPoint(x: c.x, y: c.y - 1), 6) }
                if j == 2 && deco == 3 { drawCrown(NSPoint(x: c.x, y: c.y + 7), 10) } }
        case "dalgona":
            stick(NSPoint(x: 0, y: -16), NSPoint(x: 0, y: 2), 2.2)
            let disk = oval(NSPoint(x: 0, y: 6), 36, 36); fill(disk, col(0.85, 0.58, 0.2), disk.bounds, t: t)
            col(0.95, 0.72, 0.32).setFill(); oval(NSPoint(x: -2, y: 8), 26, 26).fill()
            let sc = NSPoint(x: -2, y: 8); let stamp: NSBezierPath = shape == 1 ? Variant.heart(sc, 7) : shape == 2 ? Variant.star(sc, 7) : NSBezierPath(ovalIn: NSRect(x: sc.x - 7, y: sc.y - 7, width: 14, height: 14))
            col(0.65, 0.4, 0.12).setStroke(); stamp.lineWidth = 1.5; let dash: [CGFloat] = [2, 1.5]; stamp.setLineDash(dash, count: 2, phase: 0); stamp.stroke()
            col(0.55, 0.3, 0.1, 0.6).setFill(); for i in 0..<6 { let a = CGFloat(i) * 1.05; oval(NSPoint(x: cos(a)*15, y: 6 + sin(a)*15), 1.5, 1.5).fill() }
            shine(NSPoint(x: -9, y: 16), 6)
            if face > 0 { drawFace(NSPoint(x: -2, y: 7), 6) }
            if deco == 3 { drawCrown(NSPoint(x: 0, y: 23), 12) }
            sparkles(NSPoint(x: 0, y: 6), 22, 3, t, NSColor(white: 1, alpha: 1))
        case "cat":
            let tail = NSBezierPath(); tail.move(to: NSPoint(x: 6, y: -16)); tail.curve(to: NSPoint(x: 24, y: 6 + sin(t*2)*4), controlPoint1: NSPoint(x: 20, y: -20), controlPoint2: NSPoint(x: 28, y: -6)); tail.lineWidth = 4.5; tail.lineCapStyle = .round
            tint(col(0.98, 0.72, 0.35)).setStroke(); tail.stroke()
            let fur = col(0.98, 0.72, 0.35)
            for s in [-1.0, 1.0] as [CGFloat] { let e = NSBezierPath(); e.move(to: NSPoint(x: s*15, y: 8)); e.line(to: NSPoint(x: s*14, y: 24 + (s > 0 ? sin(t*3) : 0))); e.line(to: NSPoint(x: s*4, y: 13)); e.close(); tint(fur).setFill(); e.fill()
                col(1, 0.75, 0.78).setFill(); let ie = NSBezierPath(); ie.move(to: NSPoint(x: s*13, y: 11)); ie.line(to: NSPoint(x: s*12.5, y: 20)); ie.line(to: NSPoint(x: s*7, y: 13)); ie.close(); ie.fill() }
            let head = oval(NSPoint(x: 0, y: 5), 34, 27); fill(head, fur, head.bounds, t: t)
            if color == 0 { col(0.9, 0.55, 0.22).setFill(); for i in 0..<3 { NSBezierPath(roundedRect: NSRect(x: -5 + CGFloat(i)*4, y: 13, width: 2, height: 5), xRadius: 1, yRadius: 1).fill() } }
            NSColor(white: 1, alpha: 0.85).setFill(); oval(NSPoint(x: 0, y: -1), 16, 10).fill()
            let ink = NSColor(white: 0.12, alpha: 0.9); ink.setFill(); ink.setStroke()
            let sleepy = face == 3 || Int(t * 10) % 50 < 3
            for s in [-1.0, 1.0] as [CGFloat] {
                if sleepy { let p = NSBezierPath(); p.appendArc(withCenter: NSPoint(x: s*7, y: 7), radius: 2.5, startAngle: 200, endAngle: 340); p.lineWidth = 1.2; p.stroke() }
                else if deco == 2 { NSBezierPath(roundedRect: NSRect(x: s*7 - 4, y: 5, width: 8, height: 5), xRadius: 1.5, yRadius: 1.5).fill() }
                else { oval(NSPoint(x: s*7, y: 7), 3.2, face == 2 ? 4.5 : 3.6).fill() }
                for k in 0..<2 { let w = NSBezierPath(); w.move(to: NSPoint(x: s*9, y: 0 + CGFloat(k)*2.5)); w.line(to: NSPoint(x: s*20, y: -1 + CGFloat(k)*4)); w.lineWidth = 0.7; w.stroke() } }
            col(1, 0.55, 0.6).setFill(); let nose = NSBezierPath(); nose.move(to: NSPoint(x: -1.6, y: 2)); nose.line(to: NSPoint(x: 1.6, y: 2)); nose.line(to: NSPoint(x: 0, y: 0.3)); nose.close(); nose.fill()
            ink.setStroke(); let m = NSBezierPath(); m.move(to: NSPoint(x: -3, y: -1.5)); m.curve(to: NSPoint(x: 0, y: -0.5), controlPoint1: NSPoint(x: -2, y: -3), controlPoint2: NSPoint(x: -0.5, y: -2.5)); m.curve(to: NSPoint(x: 3, y: -1.5), controlPoint1: NSPoint(x: 0.5, y: -2.5), controlPoint2: NSPoint(x: 2, y: -3)); m.lineWidth = 0.9; m.stroke()
            col(1, 0.55, 0.55, 0.4).setFill(); oval(NSPoint(x: -11, y: 0), 5, 3).fill(); oval(NSPoint(x: 11, y: 0), 5, 3).fill()
            if deco == 1 { ink.setFill(); for s in [-1.0, 1.0] as [CGFloat] { oval(NSPoint(x: s*4, y: -3), 7, 2.4).fill() } }
            for s in [-1.0, 1.0] as [CGFloat] { tint(fur).setFill(); oval(NSPoint(x: s*9, y: -10), 9, 6).fill(); col(1, 0.75, 0.78).setFill(); oval(NSPoint(x: s*9, y: -10.5), 3, 2).fill() }
            if deco == 3 { drawCrown(NSPoint(x: 0, y: 17), 12) }
            if sleepy && face == 3 { ("z" as NSString).draw(at: NSPoint(x: 15, y: 18 + sin(t)*2), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 8), .foregroundColor: NSColor(white: 1, alpha: 0.95)]) }
        default: break
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
