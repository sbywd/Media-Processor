import SwiftUI
import UniformTypeIdentifiers

struct ProcessSettingView: View {
    // 1. 接收从 MainView 传来的视频项目对象
    // @ObservedObject 确保当 item 的属性改变时，视图会刷新
    @ObservedObject var item: VideoItem

    // 2. 添加环境 dismiss 变量
    @Environment(\.dismiss) var dismiss

    private let subtitleFilePicker: NSOpenPanel

    init(item: VideoItem) {
        self.item = item
        
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
    }

    var body: some View {
        // 使用一个主 VStack 来组织布局
        VStack {
            // 将原有的内容放入 ScrollView
            ScrollView {
                // 将 VStack 的宽度加大，以便容纳所有控件
                VStack(alignment: .leading, spacing: 18) {
                    // 使用 item 的属性来驱动UI，而不是独立的 @State 变量
                    // 例如：$item.resolutionEnabled
                    
                        HStack {
                            Toggle("分辨率", isOn: $item.resolutionEnabled)
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
                            if item.resolutionEnabled {
                                HStack {
                                    TextField("宽度", text: $item.resolutionWidth)
                                        .frame(width: 60)
                                    Text("x")
                                    TextField("高度", text: $item.resolutionHeight)
                                        .frame(width: 60)
                                    Toggle("保持比例", isOn: $item.keepAspectRatio)
                                }
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
                            }
                            Spacer() // 添加 Spacer 确保布局紧凑
                        }
                        
                        Divider()
                        HStack {
                            Toggle("帧速率", isOn: $item.frameRateEnabled)
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
                            if item.frameRateEnabled {
                                HStack {
                                    TextField("帧速率", text: $item.frameRate)
                                        .frame(width: 60)
                                }
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
                            }
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Toggle("视频位速率", isOn: $item.videoBitrateEnabled)
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
                            if item.videoBitrateEnabled {
                                HStack {
                                    TextField("位速率", text: $item.videoBitrate)
                                        .frame(width: 60)
                                    Text("Kbps")
                                    Picker("编码器", selection: $item.videoEncoder) {
                                        Text("HEVC (硬件)").tag("HEVC (硬件)")
                                        Text("H.264 (硬件)").tag("H.264 (硬件)")
                                        Text("HEVC (软件)").tag("HEVC (软件)")
                                        Text("H.264 (软件)").tag("H.264 (软件)")
                                    }
                                    .frame(width: 150) // 给 Picker 一个固定宽度
                                }
                                .disabled(item.exportAudioOnlyEnabled || item.containerFormat == "MP3")
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
                                        .frame(width: 60)
                                    Text("Kbps")
                                    Picker("编码器", selection: $item.audioEncoder) {
                                        Text("AAC").tag("AAC")
                                        Text("MP3").tag("MP3")
                                    }
                                    .frame(width: 120)
                                    .disabled(item.containerFormat == "MP3")
                                }
                                .disabled(item.exportVideoOnlyEnabled)
                            }
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Toggle("容器", isOn: $item.containerEnabled)
                            if item.containerEnabled {
                                HStack {
                                    Picker("格式", selection: $item.containerFormat) {
                                        Text("MP4").tag("MP4")
                                        Text("MP3").tag("MP3")
                                        Text("MOV").tag("MOV")
                                        Text("MKV").tag("MKV")
                                    }
                                    .onChange(of: item.containerFormat) { newFormat in
                                        if newFormat == "MP3" {
                                            item.audioEncoder = "MP3"
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        Divider()
                        
                        Toggle("字幕", isOn: $item.subtitleEnabled)
                        if item.subtitleEnabled {
                            HStack {
                                Button("选择文件") {
                                    showSubtitleFilePicker()
                                }
                                Text(item.subtitleFilePath.isEmpty ? "未选择文件" : (URL(fileURLWithPath: item.subtitleFilePath).lastPathComponent))
                            }
                            
                            HStack {
                                Picker("位置", selection: $item.subtitlePosition) {
                                    Text("中下").tag("中下")
                                    Text("顶部").tag("顶部")
                                }
                                
                                ColorPicker("颜色", selection: $item.subtitleColor)
                                Text("字体")
                                FontPickerView(selection: $item.subtitleFont)
                                
                            }
                            HStack {
                                Text("字号:")
                                TextField("大小", text: $item.subtitleFontSize)
                                    .frame(width: 40)
                                ColorPicker("描边颜色", selection: $item.subtitleOutlineColor)
                                Text("描边宽度:")
                                TextField("宽度", text: $item.subtitleOutlineWidth)
                                    .frame(width: 40)
                            }
                        }
                        Divider()
                }.padding(10)
                
            } // ScrollView 结束
            

            // 移除这个 Spacer，因为它不再需要将按钮推到底部
            // Spacer()

            // 将底部的 HStack 移到主 VStack 中，位于 ScrollView 之后
            HStack {
                Toggle("仅输出音频", isOn: $item.exportAudioOnlyEnabled)
                    .onChange(of: item.exportAudioOnlyEnabled) { newValue in
                        if newValue {
                            item.exportVideoOnlyEnabled = false
                        }
                    }
                Toggle("仅输出视频", isOn: $item.exportVideoOnlyEnabled)
                    .onChange(of: item.exportVideoOnlyEnabled) { newValue in
                        if newValue {
                            item.exportAudioOnlyEnabled = false
                        }
                    }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction) // 允许按 Esc 键触发
                // 3. 在“完成”按钮的 action 中调用 dismiss()
                Button("完成") {
                    // 调用 dismiss() 会关闭这个模态窗口
                    dismiss()
                }
                .keyboardShortcut(.defaultAction) // 允许按回车键触发
            }
            .padding(.top, 10) // 给顶部添加一些间距，避免与滚动内容靠太近
            
        } // 主 VStack 结束
        .padding(10)
        .textFieldStyle(RoundedBorderTextFieldStyle()) // 统一设置文本框样式
        .frame(minWidth: 600, minHeight: 450,maxHeight: 450) // 调整窗口大小
    }
    private func showSubtitleFilePicker() {
        subtitleFilePicker.begin { response in
            if response == .OK, let url = self.subtitleFilePicker.url {
                DispatchQueue.main.async {
                    self.item.subtitleFilePath = url.path
                }
            }
        }
    }
}

// 为了让预览正常工作，我们需要提供一个 VideoItem 的实例
struct ProcessSettingView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个临时的 VideoItem 实例用于预览
        ProcessSettingView(item: VideoItem(url: URL(string: "file:///example.mov")!))
    }
}
