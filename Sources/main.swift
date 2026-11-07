import AppKit

let toTraditional = StringTransform("Hans-Hant")
let toSimplified = StringTransform("Hant-Hans")
var voteCache: [Character: (Bool, Bool)] = [:]
func convert(_ text: String) -> String {
    var simplified = 0
    var traditional = 0
    for character in text {
        let votes: (Bool, Bool)
        if let found = voteCache[character] { votes = found }
        else {
            let original = String(character)
            let trad = original.applyingTransform(toTraditional, reverse: false) ?? original
            let simp = original.applyingTransform(toSimplified, reverse: false) ?? original
            votes = (trad != original && simp == original, simp != original && trad == original)
            if voteCache.count >= 32768 { voteCache.removeAll(keepingCapacity: true) }
            voteCache[character] = votes
        }
        if votes.0 { simplified += 1 }
        if votes.1 { traditional += 1 }
    }
    guard simplified + traditional > 0 else { return text }
    // Shared characters do not vote; a tie deterministically converts to Traditional.
    return text.applyingTransform(traditional > simplified ? toSimplified : toTraditional, reverse: false) ?? text
}

final class ConversionService: NSObject {
    @objc func convertText(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let input = pasteboard.string(forType: .string) else { return }
        let output = convert(input)
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
    }
}
if CommandLine.arguments.contains("--install") || CommandLine.arguments.contains("--uninstall") {
    do {
        if CommandLine.arguments.contains("--install") { try installService() }
        else { try uninstallService() }
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        exit(1)
    }
} else if CommandLine.arguments.contains("--test") {
    testInstallerPreferences()
    let cases = [("电脑软件设置", "電腦軟件設置"), ("電腦軟件設置", "电脑软件设置"),
                 ("电脑软件設", "電腦軟件設"), ("電腦軟件设", "电脑软件设"),
                 ("hello 123 😀\n人民", "hello 123 😀\n人民"), ("", ""),
                 ("汉漢", "漢漢"), ("电脑\n软件\n", "電腦\n軟件\n")]
    for (input, expected) in cases { precondition(convert(input) == expected) }
    let start = ProcessInfo.processInfo.systemUptime
    for _ in 0..<1000 { _ = convert("电脑软件设置书签，这是自动检测简体和繁体的测试文本。") }
    print("8 cases passed; mean conversion ms:", (ProcessInfo.processInfo.systemUptime-start))
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let provider = ConversionService()
    app.servicesProvider = provider
    _ = convert("电脑软件設電腦軟件设")
    app.run()
}
