import AppKit

/// GitHub Releases based self-updater
enum Updater {
    static let repo = "dong3789/desktop-toys"
    static let bundleId = "com.yndl.desktop-toys"
    static var currentVersion: String { ProcessInfo.processInfo.environment["DT_FAKE_VERSION"] ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0") }
    static var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?" }
    static var autoCheck: Bool { defaults.object(forKey: "autoUpdate") as? Bool ?? true }

    struct Release { let version: String; let notes: String; let zipURL: URL; let page: URL }

    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) { let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0; if p != q { return p > q } }
        return false
    }
    static func fetchLatest(_ done: @escaping (Result<Release, Error>) -> Void) {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept"); req.setValue("DesktopToys/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { d, resp, err in
            guard let d, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let tag = j["tag_name"] as? String else {
                return done(.failure(err ?? NSError(domain: "DesktopToys", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "릴리스 정보를 가져오지 못했어요."]))) }
            let assets = j["assets"] as? [[String: Any]] ?? []
            guard let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true })?["browser_download_url"] as? String, let zu = URL(string: zip) else {
                return done(.failure(NSError(domain: "DesktopToys", code: -2, userInfo: [NSLocalizedDescriptionKey: "릴리스에 zip 파일이 없어요."]))) }
            done(.success(Release(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")), notes: j["body"] as? String ?? "", zipURL: zu, page: URL(string: j["html_url"] as? String ?? "https://github.com/\(repo)/releases")!)))
        }.resume()
    }

    /// Check; on newer version ask the user. `manual` also reports "up to date" / errors.
    static func check(manual: Bool) {
        if !manual { defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck") }
        fetchLatest { r in DispatchQueue.main.async {
            switch r {
            case .failure(let e): if manual { alert("업데이트를 확인하지 못했어요", e.localizedDescription) }
            case .success(let rel):
                guard isNewer(rel.version, than: currentVersion) else { if manual { alert("최신 버전이에요 ✨", "지금 쓰는 버전 \(currentVersion)이 가장 최신이에요.") }; return }
                if !manual && defaults.string(forKey: "skippedVersion") == rel.version { return }
                activate()
                let a = NSAlert(); a.messageText = "새 버전 \(rel.version)이 나왔어요 🎉"
                a.informativeText = "지금 버전: \(currentVersion)\n\n" + String(rel.notes.prefix(900))
                a.addButton(withTitle: "지금 업데이트"); a.addButton(withTitle: "나중에")
                let res = a.runModal(); deactivate()
                if res == .alertFirstButtonReturn { install(rel, target: URL(fileURLWithPath: Bundle.main.bundlePath), relaunch: true) { err in if let err { alert("업데이트에 실패했어요", err) } } }
                else if !manual { defaults.set(rel.version, forKey: "skippedVersion") }
            }
        } }
    }

    /// Download, unzip, verify and swap the app bundle at `target` (plant data in Application Support is never touched)
    static func install(_ rel: Release, target: URL, relaunch: Bool, done: @escaping (String?) -> Void) {
        URLSession.shared.downloadTask(with: rel.zipURL) { tmp, _, err in
            guard let tmp else { return DispatchQueue.main.async { done("다운로드 실패: \(err?.localizedDescription ?? "?")") } }
            let fm = FileManager.default, work = fm.temporaryDirectory.appendingPathComponent("dt-update-\(UUID().uuidString)")
            try? fm.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = work.appendingPathComponent("u.zip"); try? fm.moveItem(at: tmp, to: zip)
            func run(_ path: String, _ args: [String]) -> Int32 { let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args; try? p.run(); p.waitUntilExit(); return p.terminationStatus }
            guard run("/usr/bin/ditto", ["-x", "-k", zip.path, work.appendingPathComponent("x").path]) == 0 else { return DispatchQueue.main.async { done("압축 해제 실패") } }
            let en = fm.enumerator(at: work.appendingPathComponent("x"), includingPropertiesForKeys: nil)
            var app: URL?; while let u = en?.nextObject() as? URL { if u.pathExtension == "app" && !u.path.contains("__MACOSX") { app = u; break } }
            guard let newApp = app, let b = Bundle(url: newApp), b.bundleIdentifier == bundleId else { return DispatchQueue.main.async { done("받은 파일이 DesktopToys 앱이 아니에요.") } }
            _ = run("/usr/bin/xattr", ["-cr", newApp.path])
            let script = work.appendingPathComponent("swap.sh")
            let sh = """
            #!/bin/bash
            PID=\(relaunch ? ProcessInfo.processInfo.processIdentifier : 0)
            while [ "$PID" != "0" ] && kill -0 $PID 2>/dev/null; do sleep 0.3; done
            rm -rf "\(target.path).old"; mv "\(target.path)" "\(target.path).old" 2>/dev/null
            if /usr/bin/ditto "\(newApp.path)" "\(target.path)"; then rm -rf "\(target.path).old"; else mv "\(target.path).old" "\(target.path)"; fi
            /usr/bin/xattr -cr "\(target.path)"
            \(relaunch ? "open \"\(target.path)\"" : "")
            """
            try? sh.write(to: script, atomically: true, encoding: .utf8)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [script.path]
            if relaunch {
                try? p.run()   // helper outlives us, waits for exit, swaps, relaunches
                DispatchQueue.main.async { done(nil); NSApp.terminate(nil) }
            } else { try? p.run(); p.waitUntilExit(); DispatchQueue.main.async { done(p.terminationStatus == 0 ? nil : "교체 실패") } }
        }.resume()
    }

    static func activate() { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
    static func deactivate() { NSApp.setActivationPolicy(.accessory) }
    static func alert(_ title: String, _ text: String) { activate(); let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal(); deactivate() }

    static func showAbout() {
        activate()
        let credits = NSMutableAttributedString(string: """
        바탕화면 위 작은 창문과 화분 🪴
        만든 사람: yndl

        날씨 데이터: Open-Meteo (open-meteo.com, CC BY 4.0)
        글꼴: 주아체 Jua — SIL Open Font License 1.1
        (앱 안 Resources/OFL-Jua.txt)
        """, attributes: [.font: cute(12, .regular), .foregroundColor: NSColor.labelColor])
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "DesktopToys", .applicationVersion: currentVersion, .version: "빌드 \(build)", .credits: credits])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // drop back to accessory once the panel closes
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in if !NSApp.windows.contains(where: { $0.isVisible && $0.className.contains("About") }) { t.invalidate(); deactivate() } } }
    }
    static var macModel: String { var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0); var b = [CChar](repeating: 0, count: max(1, size)); sysctlbyname("hw.model", &b, &size, nil, 0); return String(cString: b) }
    static func mailReport() {
        let body = "\n\n—\n앱 버전: \(currentVersion) (빌드 \(build))\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nMac 모델: \(macModel)\n"
        var c = URLComponents(); c.scheme = "mailto"; c.path = "dhlovey@gmail.com"
        c.queryItems = [URLQueryItem(name: "subject", value: "[DesktopToys] 제보"), URLQueryItem(name: "body", value: body)]
        if let u = c.url { NSWorkspace.shared.open(u) }
    }
    static func openIssues() {
        let body = "\n\n—\n앱 버전: \(currentVersion) (빌드 \(build))\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nMac 모델: \(macModel)"
        var c = URLComponents(string: "https://github.com/\(repo)/issues/new")!; c.queryItems = [URLQueryItem(name: "title", value: "[제보] "), URLQueryItem(name: "body", value: body)]
        if let u = c.url { NSWorkspace.shared.open(u) }
    }
}
