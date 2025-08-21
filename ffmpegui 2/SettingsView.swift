import SwiftUI

// A helper view to host the ProcessSettingView sheet for editing a preset.
// This view creates a temporary VideoItem for the UI and saves the changes back to the preset on dismiss.
struct PresetEditSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var presetViewModel: PresetViewModel
    
    // The original preset to be edited.
    var preset: Preset
    // A temporary, observable VideoItem that drives the ProcessSettingView.
    @StateObject var tempVideoItem: VideoItem

    init(preset: Preset) {
        self.preset = preset
        // Create a temporary VideoItem initialized with the preset's properties.
        // The URL is a dummy one as it's not used for preset editing.
        let item = VideoItem(url: URL(string: "file:///preset")!)
        item.apply(properties: preset.toProcessingProperties())
        self._tempVideoItem = StateObject(wrappedValue: item)
    }

    var body: some View {
        ProcessSettingView(item: tempVideoItem, isEditingPreset: true)
            .environmentObject(presetViewModel) // Pass the environment object down
            .onDisappear {
                // When the sheet is dismissed, find the original preset and update it
                // with the properties from the temporary VideoItem.
                if let index = presetViewModel.presets.firstIndex(where: { $0.id == preset.id }) {
                    presetViewModel.presets[index].update(from: tempVideoItem.properties)
                }
            }
    }
}

struct SettingsView: View {
    @EnvironmentObject var presetViewModel: PresetViewModel
    @State private var selection: Preset.ID?
    @State private var presetToEdit: Preset? // This state triggers the sheet

    var body: some View {
        TabView {
            presetTab
                .tabItem {
                    Label(NSLocalizedString("预设", comment: "预设"), systemImage: "list.bullet.rectangle")
                }
        }
        .padding()
        .frame(width: 450, height: 300)
        .sheet(item: $presetToEdit) { preset in
            // Present the helper view when presetToEdit is not nil.
            PresetEditSheetView(preset: preset)
        }
    }

    private var presetTab: some View {
        VStack(alignment: .leading) {
            List(selection: $selection) {
                ForEach($presetViewModel.presets) { $preset in
                    HStack {
                        TextField(NSLocalizedString("预设名称", comment: "预设名称"), text: $preset.name)
                        Spacer()
                        Button(NSLocalizedString("更改", comment: "更改")) {
                            presetToEdit = preset
                        }
                    }
                    .padding(.bottom, 3)
                    .padding(.top, 3)
                }
                .onDelete(perform: deletePresets)
            }
            .cornerRadius(8)
            
            
            HStack(spacing: 3) {
                Button(action: {
                    presetViewModel.addPreset()
                    selection = presetViewModel.presets.last?.id
                }) {
                    Image(systemName: "plus")
                        
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        
                }
                .buttonStyle(PlainButtonStyle())
                .cornerRadius(8)

                Button(action: {
                    if let selectedId = selection {
                        let indices = IndexSet(presetViewModel.presets.enumerated().filter { selectedId == $0.element.id }.map { $0.offset })
                        deletePresets(at: indices)
                    }
                }) {
                    Image(systemName: "minus")
                        .padding(4)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .cornerRadius(8)
                .disabled(selection == nil)
                
                Spacer()
            }
            
        }
        .padding()
    }
    
    private func deletePresets(at offsets: IndexSet) {
        presetViewModel.presets.remove(atOffsets: offsets)
        if selection != nil && !presetViewModel.presets.contains(where: { $0.id == selection }) {
            selection = nil
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(PresetViewModel()) // Provide a dummy view model for the preview
    }
}
