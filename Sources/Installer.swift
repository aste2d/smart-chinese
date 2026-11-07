import AppKit

private let identifier = "uk.aste.smart-chinese"
private let serviceName = "智能简繁转换"
private let preferenceDomain = "pbs" as CFString
private let preferenceKey = "NSServicesStatus" as CFString
private let fm = FileManager.default
private let home = fm.homeDirectoryForCurrentUser
private let destination = home.appendingPathComponent("Applications/Smart Chinese.app")
private let agent = home.appendingPathComponent("Library/LaunchAgents/\(identifier).plist")
private let support = home.appendingPathComponent("Library/Application Support/Smart Chinese")
private let snapshot = support.appendingPathComponent("previous-services.plist")
private let launchTarget = "gui/\(getuid())"

private func run(_ executable: String, _ arguments: [String], required: Bool = true) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    if required && process.terminationStatus != 0 {
        throw NSError(domain: identifier, code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "\(executable) failed (\(process.terminationStatus))"])
    }
}
private func readPlist(_ path: URL) throws -> [String: Any] {
    try PropertyListSerialization.propertyList(from: Data(contentsOf: path), format: nil) as? [String: Any] ?? [:]
}
private func writePlist(_ value: [String: Any], _ path: URL) throws {
    try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0).write(to: path, options: .atomic)
}
private func statuses() -> [String: Any] {
    CFPreferencesAppSynchronize(preferenceDomain)
    return CFPreferencesCopyAppValue(preferenceKey, preferenceDomain) as? [String: Any] ?? [:]
}
private func saveStatuses(_ value: [String: Any]) throws {
    CFPreferencesSetAppValue(preferenceKey, value as CFDictionary, preferenceDomain)
    guard CFPreferencesAppSynchronize(preferenceDomain) else {
        throw NSError(domain: identifier, code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot save Services shortcuts"])
    }
}
private func refreshServices() throws {
    try run("/System/Library/CoreServices/pbs", ["-flush"])
    try run("/System/Library/CoreServices/pbs", ["-update"])
}
func shortcutPlan(current original: [String: Any], previous saved: [String: Any]) -> (current: [String: Any], previous: [String: Any]) {
    var current = original
    var previous = saved
    let menus = ["Convert Text from Traditional to Simplified Chinese", "Convert Text to Simplified Chinese", "将文本转换为简体中文"]
    var updates: [String: Any] = [:]
    for menu in menus {
        let key = "com.apple.ChineseTextConverterService - \(menu) - convertTextToSimplifiedChinese"
        var value = current[key] as? [String: Any] ?? [:]
        value["key_equivalent"] = ""
        updates[key] = value
    }
    updates["\(identifier) - \(serviceName) - convertText"] = ["enabled_context_menu": true, "enabled_services_menu": true,
                          "presentation_modes": ["ContextMenu": true, "ServicesMenu": true], "key_equivalent": "^~$@c"]
    for (key, value) in updates {
        if previous[key] == nil {
            previous[key] = ["existed": current[key] != nil, "value": current[key] ?? [:], "installed": value]
        }
        current[key] = value
    }
    return (current, previous)
}
func restoredShortcuts(current original: [String: Any], previous: [String: Any]) -> [String: Any] {
    var current = original
    for (key, record) in previous {
        guard let entry = record as? [String: Any], let installed = entry["installed"] as? NSDictionary,
              let now = current[key] as? NSDictionary, now == installed else { continue }
        if entry["existed"] as? Bool == true { current[key] = entry["value"] }
        else { current.removeValue(forKey: key) }
    }
    return current
}
func testInstallerPreferences() {
    let builtIn = "com.apple.ChineseTextConverterService - Convert Text from Traditional to Simplified Chinese - convertTextToSimplifiedChinese"
    let unrelated: [String: Any] = ["key_equivalent": "^t"]
    let original: [String: Any] = ["unrelated": unrelated, builtIn: ["key_equivalent": "^~$@C", "enabled_services_menu": false]]
    let plan = shortcutPlan(current: original, previous: [:])
    precondition((plan.current["unrelated"] as? NSDictionary) == (unrelated as NSDictionary))
    precondition((plan.current[builtIn] as? [String: Any])?["enabled_services_menu"] as? Bool == false)
    precondition((restoredShortcuts(current: plan.current, previous: plan.previous) as NSDictionary) == (original as NSDictionary))
    let updated = shortcutPlan(current: plan.current, previous: plan.previous)
    precondition((updated.previous as NSDictionary) == (plan.previous as NSDictionary))
    var manual = plan.current
    manual[builtIn] = ["key_equivalent": "^x"]
    precondition((restoredShortcuts(current: manual, previous: plan.previous)[builtIn] as? [String: Any])?["key_equivalent"] as? String == "^x")
    print("Installer preference tests passed: preserve unrelated settings, restore, reinstall, and keep manual changes")
}

func installService() throws {
    let source = Bundle.main.bundleURL.resolvingSymlinksInPath()
    guard source.pathExtension == "app", Bundle.main.bundleIdentifier == identifier else {
        throw NSError(domain: identifier, code: 2, userInfo: [NSLocalizedDescriptionKey: "Run the installer from the downloaded app bundle"])
    }
    let plan = shortcutPlan(current: statuses(), previous: (try? readPlist(snapshot)) ?? [:])
    let current = plan.current
    let previous = plan.previous
    try writePlist(previous, snapshot)
    try run("/bin/launchctl", ["bootout", "\(launchTarget)/\(identifier)"], required: false)
    if source.path != destination.resolvingSymlinksInPath().path {
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            let installedInfo = try readPlist(destination.appendingPathComponent("Contents/Info.plist"))
            guard installedInfo["CFBundleIdentifier"] as? String == identifier else {
                throw NSError(domain: identifier, code: 3, userInfo: [NSLocalizedDescriptionKey: "Destination belongs to another app; nothing was replaced"])
            }
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }
    try saveStatuses(current)
    let launch: [String: Any] = ["Label": identifier,
        "ProgramArguments": [destination.appendingPathComponent("Contents/MacOS/SmartChinese").path],
        "RunAtLoad": true, "KeepAlive": true, "ProcessType": "Interactive", "ThrottleInterval": 10]
    try writePlist(launch, agent)
    try run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", destination.path])
    try refreshServices()
    try run("/bin/launchctl", ["bootstrap", launchTarget, agent.path])
    print("Installed. Select text and press Control+Option+Shift+Command+C (Hyper+C).")
    print("The service starts at login. No administrator or Accessibility permission is required.")
}
func uninstallService() throws {
    try run("/bin/launchctl", ["bootout", "\(launchTarget)/\(identifier)"], required: false)
    if fm.fileExists(atPath: snapshot.path) {
        let previous = try readPlist(snapshot)
        try saveStatuses(restoredShortcuts(current: statuses(), previous: previous))
    }
    let ls = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    if fm.fileExists(atPath: destination.path) {
        let info = try readPlist(destination.appendingPathComponent("Contents/Info.plist"))
        guard info["CFBundleIdentifier"] as? String == identifier else {
            throw NSError(domain: identifier, code: 3, userInfo: [NSLocalizedDescriptionKey: "Refusing to remove an unrelated app"])
        }
        try run(ls, ["-u", destination.path], required: false)
        try fm.removeItem(at: destination)
    }
    if fm.fileExists(atPath: agent.path) { try fm.removeItem(at: agent) }
    if fm.fileExists(atPath: snapshot.path) { try fm.removeItem(at: snapshot) }
    try refreshServices()
    print("Uninstalled. Previous shortcut settings were restored where unchanged since installation.")
}
