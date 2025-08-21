import SwiftUI

class PresetViewModel: ObservableObject {
    @Published var presets: [Preset] = [] {
        didSet {
            savePresets()
        }
    }
    
    private let userDefaultsKey = "savedPresets"

    init() {
        loadPresets()
    }

    func addPreset() {
        var newPreset = Preset.newDefault()
        var newName = newPreset.name
        var counter = 2
        // 确保新预设的名称是唯一的
        while presets.contains(where: { $0.name == newName }) {
            newName = "\(newPreset.name) \(counter)"
            counter += 1
        }
        newPreset.name = newName
        presets.append(newPreset)
    }

    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    private func savePresets() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // for debugging
        if let encoded = try? encoder.encode(presets) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadPresets() {
        if let savedPresets = UserDefaults.standard.data(forKey: userDefaultsKey) {
            if let decodedPresets = try? JSONDecoder().decode([Preset].self, from: savedPresets) {
                self.presets = decodedPresets
                return
            }
        }
        // If no saved presets, load with a default one
        self.presets = [Preset.newDefault()]
    }
}
