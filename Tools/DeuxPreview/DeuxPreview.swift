#if os(macOS)
import AppKit
import SwiftUI
import DeuxCore
import DeuxPersistence
import DeuxUI

/// Demonstration data belongs exclusively to this preview process, never the app's store.
@main struct DeuxPreviewCommand {
    @MainActor static func main() {
        let application = NSApplication.shared
        let live = CommandLine.arguments.contains("--live")
        application.setActivationPolicy(live ? .regular : .prohibited)
        let delegate = PreviewApplicationDelegate()
        delegate.terminateAfterLastWindowClosed = live
        application.delegate = delegate
        Task { @MainActor in
            do {
                let store = try await demonstrationStore()
                if live {
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 900), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
                    window.title = "À deux · Démonstration locale"
                    window.isReleasedWhenClosed = false
                    window.contentView = NSHostingView(rootView: DeuxRootView(store: store))
                    delegate.window = window
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                    application.activate(ignoringOtherApps: true)
                    return
                }
                let output = try outputDirectory()
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                for screen in DeuxScreenPreview.Screen.allCases {
                    let source: HouseholdStore
                    if screen == .onboarding {
                        source = HouseholdStore(inMemory: true)
                        await source.load()
                    } else { source = store }
                    try await render(DeuxScreenPreview(store: source, screen: screen), name: screen.rawValue, into: output)
                }
                print("Aperçus SwiftUI macOS réels, avec données de démonstration en mémoire. Les contrôles et la navigation iOS restent à vérifier dans le simulateur.")
                application.terminate(nil)
            } catch {
                FileHandle.standardError.write(Data("Aperçu impossible : \(error.localizedDescription)\n".utf8))
                Darwin.exit(1)
            }
        }
        application.run()
    }

    @MainActor private static func demonstrationStore() async throws -> HouseholdStore {
        let store = HouseholdStore(inMemory: true)
        await store.load()
        try store.createHousehold(name: "Le nid de Camille & Alex", personOne: "Camille", personTwo: "Alex")
        store.currentPerson = .personOne
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        try store.saveTask(HouseTask(title: "Faire le plein de bonnes choses", notes: "Du pain, des fruits et de quoi improviser un dîner.", category: .groceries, assignee: .personTwo, dueDate: now, recurrence: .weekly, effortMinutes: 30))
        try store.saveTask(HouseTask(title: "Donner un peu d’air au salon", category: .cleaning, assignee: .anyone, dueDate: yesterday, effortMinutes: 15))
        try store.saveTask(HouseTask(title: "Lancer une lessive", category: .laundry, assignee: .personOne, dueDate: tomorrow, recurrence: .weekly, effortMinutes: 10))
        try store.saveTask(HouseTask(title: "Préparer les repas de la semaine", category: .meals, assignee: .anyone, dueDate: tomorrow, recurrence: .weekly, effortMinutes: 45))
        let plants = HouseTask(title: "Arroser les plantes", category: .other, assignee: .personOne, dueDate: now, effortMinutes: 10)
        try store.saveTask(plants)
        try store.completeTask(plants, at: now)
        store.currentPerson = .personTwo
        let admin = HouseTask(title: "Régler la facture d’électricité", category: .admin, assignee: .personTwo, dueDate: now, effortMinutes: 10)
        try store.saveTask(admin)
        try store.completeTask(admin, at: now)
        store.currentPerson = .personOne
        return store
    }

    private static func outputDirectory() throws -> URL {
        let arguments = CommandLine.arguments
        if let index = arguments.lastIndex(of: "--output") {
            guard index + 1 < arguments.count else { throw PreviewError.missingOutput }
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/images", isDirectory: true)
    }

    @MainActor private static func render<V: View>(_ content: V, name: String, into directory: URL) async throws {
        let largeText = CommandLine.arguments.contains("--large-text")
        let width: CGFloat = 430
        let height: CGFloat = largeText ? 1700 : name == "home" ? 1220 : 1100
        let root = content.environment(\.dynamicTypeSize, largeText ? .accessibility2 : .large)
            .frame(width: width, height: height)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: NSRect(x: -2400, y: -2400, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.close() }
        try await Task.sleep(for: .milliseconds(350))
        window.displayIfNeeded()
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw PreviewError.renderFailed }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        // Do not silently deliver the empty backgrounds some headless renderers produce.
        var colors = Set<UInt32>()
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 12) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 12) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let red = UInt32(max(0, min(255, color.redComponent * 255)))
                let green = UInt32(max(0, min(255, color.greenComponent * 255)))
                let blue = UInt32(max(0, min(255, color.blueComponent * 255)))
                colors.insert((red / 16) << 8 | (green / 16) << 4 | blue / 16)
            }
        }
        guard colors.count > 10, let data = bitmap.representation(using: .png, properties: [:]) else { throw PreviewError.blankRender }
        let suffix = largeText ? "-large-text" : ""
        let destination = directory.appendingPathComponent("\(name)\(suffix).png")
        try data.write(to: destination, options: .atomic)
        print(destination.path)
    }
}

@MainActor private final class PreviewApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var terminateAfterLastWindowClosed = false
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { terminateAfterLastWindowClosed }
}

private enum PreviewError: LocalizedError {
    case missingOutput, renderFailed, blankRender
    var errorDescription: String? {
        switch self {
        case .missingOutput: return "Indiquez un dossier après --output."
        case .renderFailed: return "AppKit n’a pas pu créer l’image de la vue. Lancez l’aperçu depuis une session graphique macOS."
        case .blankRender: return "Le rendu est vide. Aucun faux aperçu n’a été enregistré ; utilisez --live dans une session graphique macOS."
        }
    }
}
#else
import Foundation
@main struct DeuxPreviewCommand {
    static func main() { print("Cet outil d’aperçu utilise AppKit sur macOS.") }
}
#endif
