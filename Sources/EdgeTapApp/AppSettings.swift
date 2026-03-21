import EdgeTapCore
import Foundation

@MainActor
final class AppSettings {
    struct Keys {
        static let monitoringEnabled = "monitoringEnabled"
        static let absoluteEdgeThresholdX = "absoluteEdgeThresholdX"
        static let triggerDeltaY = "triggerDeltaY"
        static let gestureShortcutMappings = "gestureShortcutMappings"
        static let edgeActionTypes = "edgeActionTypes"
        static let language = "language"
    }


    var monitoringEnabled: Bool {
        didSet { defaults.set(monitoringEnabled, forKey: Keys.monitoringEnabled) }
    }

    var absoluteEdgeThresholdX: Double {
        didSet { defaults.set(absoluteEdgeThresholdX, forKey: Keys.absoluteEdgeThresholdX) }
    }

    var triggerDeltaY: Double {
        didSet { defaults.set(triggerDeltaY, forKey: Keys.triggerDeltaY) }
    }

    var gestureShortcutMappings: [GestureShortcutMapping] {
        didSet { saveGestureShortcutMappings(gestureShortcutMappings) }
    }

    var edgeActionTypes: [String: EdgeActionType] {
        didSet {
            if let data = try? JSONEncoder().encode(edgeActionTypes) {
                defaults.set(data, forKey: Keys.edgeActionTypes)
            }
        }
    }

    var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults


        if defaults.object(forKey: Keys.monitoringEnabled) == nil {
            defaults.set(false, forKey: Keys.monitoringEnabled)
        }
        if defaults.object(forKey: Keys.absoluteEdgeThresholdX) == nil {
            defaults.set(1.45, forKey: Keys.absoluteEdgeThresholdX)
        }
        if defaults.object(forKey: Keys.triggerDeltaY) == nil {
            defaults.set(0.12, forKey: Keys.triggerDeltaY)
        }
        if defaults.object(forKey: Keys.language) == nil {
            defaults.set(Localization.currentLanguage, forKey: Keys.language)
        }


        self.monitoringEnabled = defaults.bool(forKey: Keys.monitoringEnabled)
        self.absoluteEdgeThresholdX = defaults.double(forKey: Keys.absoluteEdgeThresholdX)
        self.triggerDeltaY = defaults.double(forKey: Keys.triggerDeltaY)
        self.language = defaults.string(forKey: Keys.language) ?? "en"
        self.gestureShortcutMappings = Self.loadGestureShortcutMappings(from: defaults)
        if let data = defaults.data(forKey: Keys.edgeActionTypes),
           let decoded = try? JSONDecoder().decode([String: EdgeActionType].self, from: data) {
            self.edgeActionTypes = decoded
        } else {
            self.edgeActionTypes = ["top": .custom, "bottom": .custom, "left": .custom, "right": .custom]
        }

        if defaults.data(forKey: Keys.gestureShortcutMappings) == nil {
            saveGestureShortcutMappings(self.gestureShortcutMappings)
        }
    }

    var detectorConfiguration: EdgeSwipeDetector.Configuration {
        var configuration = EdgeSwipeDetector.Configuration()
        configuration.absoluteEdgeThresholdX = absoluteEdgeThresholdX
        configuration.triggerDeltaY = triggerDeltaY
        return configuration
    }

    func gestureShortcutMapping(for slot: GestureShortcutSlot) -> GestureShortcutMapping {
        if let mapping = gestureShortcutMappings.first(where: { $0.slot == slot }) {
            return mapping
        }

        return GestureShortcutMapping(slot: slot)
    }

    func updateGestureShortcutMapping(_ mapping: GestureShortcutMapping) {
        if let index = gestureShortcutMappings.firstIndex(where: { $0.slot == mapping.slot }) {
            gestureShortcutMappings[index] = mapping
        } else {
            gestureShortcutMappings.append(mapping)
        }

        gestureShortcutMappings = Self.mergedMappings(from: gestureShortcutMappings)
    }

    var actionBindings: [GestureActionKey: DemoActionBinding] {
        var bindings: [GestureActionKey: DemoActionBinding] = [:]

        for mapping in gestureShortcutMappings {
            let shortcut = ShortcutBinding(mapping.binding.shortcut)
            bindings[mapping.slot.actionKey] = DemoActionBinding(
                enabled: mapping.binding.enabled,
                shortcut: shortcut,
                rawShortcut: mapping.binding.shortcut,
                mediaAction: mapping.binding.mediaAction
            )
        }

        return bindings
    }

    private static func loadGestureShortcutMappings(from defaults: UserDefaults) -> [GestureShortcutMapping] {
        guard let data = defaults.data(forKey: Keys.gestureShortcutMappings),
              let decoded = try? JSONDecoder().decode([GestureShortcutMapping].self, from: data) else {
            return defaultGestureShortcutMappings()
        }

        return mergedMappings(from: decoded)
    }

    private func saveGestureShortcutMappings(_ mappings: [GestureShortcutMapping]) {
        let normalized = Self.mergedMappings(from: mappings)
        if let data = try? JSONEncoder().encode(normalized) {
            defaults.set(data, forKey: Keys.gestureShortcutMappings)
        }
    }

    private static func defaultGestureShortcutMappings() -> [GestureShortcutMapping] {
        GestureShortcutSlot.allCases.map { GestureShortcutMapping(slot: $0) }
    }

    private static func mergedMappings(from mappings: [GestureShortcutMapping]) -> [GestureShortcutMapping] {
        var bySlot: [GestureShortcutSlot: GestureShortcutBinding] = [:]
        for mapping in mappings {
            bySlot[mapping.slot] = mapping.binding
        }

        for slot in GestureShortcutSlot.allCases where bySlot[slot] == nil {
            bySlot[slot] = GestureShortcutBinding()
        }

        return GestureShortcutSlot.allCases.map { slot in
            GestureShortcutMapping(slot: slot, binding: bySlot[slot] ?? GestureShortcutBinding())
        }
    }
}
