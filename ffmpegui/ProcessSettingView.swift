import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ProcessSettingView: View {
    @ObservedObject var item: VideoItem
    var isEditingPreset: Bool
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var presetViewModel: PresetViewModel

    private let subtitleFilePicker: NSOpenPanel?

    init(item: VideoItem, isEditingPreset: Bool = false) {
        self.item = item
        self.isEditingPreset = isEditingPreset
        
        if !isEditingPreset {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [
                UTType(filenameExtension: "srt") ?? .plainText,
                UTType(filenameExtension: "ass") ?? .plainText,
                UTType(filenameExtension: "vtt") ?? .plainText
            ]
            self.subtitleFilePicker = panel
        } else {
            self.subtitleFilePicker = nil
        }
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Toggle("分辨率", isOn: $item.resolutionEnabled)
                            .disabled(item.exportAudioOnlyEnabled)
                        if item.resolutionEnabled {
                            HStack {
                                TextField("宽度", text: $item.resolutionWidth)
                                    .frame(width: 60, height: 0)
                                Text("x")
                                TextField("高度", text: $item.resolutionHeight)
                                    .frame(width: 60, height: 0)
                                Toggle("保持比例", isOn: $item.keepAspectRatio)
                            }
                            .disabled(item.exportAudioOnlyEnabled)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    HStack {
                        Toggle("帧速率", isOn: $item.frameRateEnabled)
                            .disabled(item.exportAudioOnlyEnabled)
                        if item.frameRateEnabled {
                            HStack {
                                TextField("帧速率", text: $item.frameRate)
                                    .frame(width: 60, height: 0)
                                    
                            }
                            .disabled(item.exportAudioOnlyEnabled)
                        }
                        
                    }
                    Divider()
                    HStack {
                        Toggle("视频位速率", isOn: $item.videoBitrateEnabled)
                            .disabled(item.exportAudioOnlyEnabled)
                        if item.videoBitrateEnabled {
                            HStack {
                                TextField("位速率", text: $item.videoBitrate)
                                    .frame(width: 60, height: 0)
                                Text("Kbps")
                                Picker("编码器", selection: $item.videoEncoder) {
                                    Text("HEVC (硬件)").tag("HEVC (硬件)")
                                    Text("H.264 (硬件)").tag("H.264 (硬件)")
                                    Text("HEVC (软件)").tag("HEVC (软件)")
                                    Text("H.264 (软件)").tag("H.264 (软件)")
                                    Text("Apple ProRes(软件)").tag("Apple ProRes(软件)")
                                    Text("AV1").tag("AV1")
                                    Text("MPEG-4").tag("MPEG-4")
                                }
                                .frame(width: 150, height: 0)
                                .onChange(of: item.videoEncoder) { newEncoder in
                                    if newEncoder.contains("Apple ProRes") {
                                        item.containerFormat = "MOV"
                                    }
                                }
                            }
                            .disabled(item.exportAudioOnlyEnabled)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    HStack {
                        Toggle("音频位速率", isOn: $item.audioBitrateEnabled)
                            .disabled(item.exportVideoOnlyEnabled)
                        if item.audioBitrateEnabled {
                            HStack {
                                TextField("位速率", text: $item.audioBitrate)
                                    .frame(width: 60, height: 0)
                                Text("Kbps")
                                Picker("编码器", selection: $item.audioEncoder) {
                                    Text("AAC").tag("AAC")
                                    Text("MP3").tag("MP3")
                                    Text("Opus").tag("Opus")
                                }
                                .frame(width: 120, height: 0)
                                .disabled(item.containerFormat == "MP3")
                            }
                            .disabled(item.exportVideoOnlyEnabled)
                        }
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Toggle("容器", isOn: $item.containerEnabled)
                            .onChange(of: item.containerEnabled){ containerEnabled in
                                if containerEnabled && item.containerFormat == "MP3"{
                                    item.audioEncoder = "MP3"
                                    item.exportAudioOnlyEnabled = true
                                }
                            }
                        if item.containerEnabled {
                            HStack {
                                Picker("格式", selection: $item.containerFormat) {
                                    Text("MP4").tag("MP4")
                                    Text("MP3").tag("MP3")
                                    Text("MOV").tag("MOV")
                                    Text("MKV").tag("MKV")
                                    Text("AVI").tag("AVI")
                                    Text("FLV").tag("FLV")
                                    Text("WEBM").tag("WEBM")
                                }
                                .onChange(of: item.containerFormat) { newFormat in
                                    if newFormat == "MP3" && item.containerEnabled {
                                        item.audioEncoder = "MP3"
                                        item.exportAudioOnlyEnabled = true
                                    }
                                }
                                .disabled(item.videoEncoder.contains("Apple ProRes"))
                                .frame(width: 120, height: 0)
                            }
                        }
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Toggle("变速", isOn: $item.speedEnabled)
                        if item.speedEnabled {
                            HStack {
                                TextField("百分比", text: $item.speedPercentage)
                                    .frame(width: 60, height: 0)
                                Text("%")
                            }
                        }
                        Spacer()
                    }
                    Divider()
                    Toggle("字幕", isOn: $item.subtitleEnabled)
                    if item.subtitleEnabled {
                        if !isEditingPreset {
                            HStack {
                                Button("选择文件") {
                                    showSubtitleFilePicker()
                                }
                                Text(item.subtitleFilePath.isEmpty ? String(NSLocalizedString("未选择文件", comment: "未选择文件")) : (URL(fileURLWithPath: item.subtitleFilePath).lastPathComponent))
                            }
                        }
                        
                        HStack {
                            Picker("位置: ", selection: $item.subtitlePosition) {
                                Text("中下").tag("中下")
                                Text("顶部").tag("顶部")
                            }
                            ColorPicker("颜色: ", selection: $item.subtitleColor)
                            Text("字体: ")
                            FontPickerView(selection: $item.subtitleFont)
                        }
                        HStack {
                            Text("字号:")
                            TextField("大小", text: $item.subtitleFontSize)
                                .frame(width: 40, height: 0)
                            ColorPicker("描边颜色: ", selection: $item.subtitleOutlineColor)
                            Text("描边宽度: ")
                            TextField("宽度", text: $item.subtitleOutlineWidth)
                                .frame(width: 40, height: 0)
                        }
                    }
                    Divider()
                }.padding(10)
            }
            
            HStack {
                Toggle("仅输出音频", isOn: $item.exportAudioOnlyEnabled)
                    .onChange(of: item.exportAudioOnlyEnabled) { newValue in
                        if newValue {
                            item.exportVideoOnlyEnabled = false
                        }
                    }
                    .disabled(item.containerFormat == "MP3" && item.containerEnabled)
                Toggle("仅输出视频", isOn: $item.exportVideoOnlyEnabled)
                    .onChange(of: item.exportVideoOnlyEnabled) { newValue in
                        if newValue {
                            item.exportAudioOnlyEnabled = false
                        }
                    }
                    .disabled(item.containerFormat == "MP3" && item.containerEnabled)
                Spacer()
                if !isEditingPreset {
                    HStack {
                        Picker("预设", selection: Binding(
                            get: { item.presetName ?? "" },
                            set: { newPresetName in
                                if newPresetName == "" {
                                    item.presetName = nil
                                } else {
                                    if let selectedPreset = presetViewModel.presets.first(where: { $0.name == newPresetName }) {
                                        item.apply(properties: selectedPreset.toProcessingProperties(), presetName: selectedPreset.name)
                                    }
                                }
                            }
                        )) {
                            Text("无").tag("")
                            ForEach(presetViewModel.presets) { preset in
                                Text(preset.name).tag(preset.name)
                            }
                        }
                        .frame(width: 150) // Adjust width as needed
                        
                        if #available(macOS 14.0, *) {
                            SettingsLink {
                                Image(systemName: "gearshape")
                                    .font(.title2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            } label: {
                                Image(systemName: "gearshape")
                                    
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 10)
        }
        .padding(10)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .frame(minWidth: 600, minHeight: 450, maxHeight: 450)
    }
    
    private func showSubtitleFilePicker() {
        guard let subtitleFilePicker = subtitleFilePicker else { return }
        subtitleFilePicker.begin { response in
            if response == .OK, let url = subtitleFilePicker.url {
                DispatchQueue.main.async {
                    self.item.subtitleFilePath = url.path
                }
            }
        }
    }
}

struct ProcessSettingView_Previews: PreviewProvider {
    static var previews: some View {
        ProcessSettingView(item: VideoItem(url: URL(string: "file:///example.mov")!))
            .environmentObject(PresetViewModel())
        
        ProcessSettingView(item: VideoItem(url: URL(string: "file:///preset.mov")!), isEditingPreset: true)
            .previewDisplayName("Editing Preset")
            .environmentObject(PresetViewModel())
    }
}


