import Combine
import Foundation

enum TriggerMode: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hover:
            return "Hover"
        case .click:
            return "Click"
        }
    }

    var systemImage: String {
        switch self {
        case .hover:
            return "cursorarrow.motionlines"
        case .click:
            return "cursorarrow.click.2"
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var triggerMode: TriggerMode {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: Self.triggerModeKey)
        }
    }

    @Published var themeColor: ThemeColor {
        didSet {
            if let data = try? JSONEncoder().encode(themeColor) {
                UserDefaults.standard.set(data, forKey: Self.themeColorKey)
            }
        }
    }

    private static let triggerModeKey = "notchNotes.triggerMode"
    private static let themeColorKey = "notchNotes.themeColor"

    init() {
        let rawMode = UserDefaults.standard.string(forKey: Self.triggerModeKey)
        triggerMode = rawMode.flatMap(TriggerMode.init(rawValue:)) ?? .hover

        if let data = UserDefaults.standard.data(forKey: Self.themeColorKey),
           let color = try? JSONDecoder().decode(ThemeColor.self, from: data) {
            themeColor = color
        } else {
            themeColor = .dark
        }
    }
}
