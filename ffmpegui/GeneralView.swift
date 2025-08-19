import SwiftUI

// MARK: - 主视图

/// `GeneralView` 结构体是应用程序中负责文件转换功能的主要视图。
/// 它允许用户选择输入/输出文件，配置转换参数，并显示FFmpeg命令预览和执行状态。
struct GeneralView: View {
    // MARK: 状态变量 (现在通过Binding从ContentView获取)
    @Binding var encodingMode: EncodingMode
    @Binding var videoCodec: String
    @Binding var audioCodec: String
    @Binding var outputFormat: String
    @Binding var videoBitrate: String
    @Binding var audioBitrate: String
    @Binding var videoWidth: String
    @Binding var videoHeight: String
    @Binding var videoFrameRate: String
    @Binding var speed: String
    @Binding var onlyAudio: Bool
    @Binding var onlyVideo: Bool
    @Binding var colorSpace: ColorSpace
    
    /// 计算属性，根据当前编码模式返回可用的视频编码器列表。
    private var availableVideoCodecs: [String] {
        switch encodingMode {
        case .software:
            return ["HEVC", "H.264"]
        case .hardware:
            return ["HEVC (VideoToolbox)", "H.264 (VideoToolbox)"]
        }
    }
    
    /// 音频编码器选项列表。
    let audioCodecs = ["AAC", "Opus", "MP3"]
    /// 输出格式选项列表。
    let outputFormats = ["MP4", "MOV", "MKV", "MP3"]
    
    // MARK: 视图主体
        
    /// `GeneralView` 的视图内容。
    var body: some View {
        /// 垂直堆栈布局，内容左对齐，间距为 16。
        VStack(alignment: .leading, spacing: 16) {
            /// 编码方式选择器。
            Picker("编码方式", selection: $encodingMode) {
                /// 遍历所有 `EncodingMode` 枚举值，为每个模式创建一个文本标签。
                ForEach(EncodingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented) // 设置选择器样式为分段控制。
            .padding(.bottom, 8) // 添加底部内边距。

            /// 转换参数表单视图。
            ConversionForm(
                encodingMode: encodingMode,
                videoCodec: $videoCodec, audioCodec: $audioCodec, outputFormat: $outputFormat,
                videoBitrate: $videoBitrate, audioBitrate: $audioBitrate,
                videoWidth: $videoWidth, videoHeight: $videoHeight, videoFrameRate: $videoFrameRate,
                speed: $speed, onlyAudio: $onlyAudio, onlyVideo: $onlyVideo, colorSpace: $colorSpace,
                videoCodecs: availableVideoCodecs,
                audioCodecs: audioCodecs, outputFormats: outputFormats
            )
        }
        .padding() // 为整个视图添加内边距。
    }
}

// MARK: - 表单子视图
/// `ConversionForm` 结构体定义了转换参数的表单视图。
/// 它使用 `@Binding` 来与父视图的状态变量进行双向绑定。
private struct ConversionForm: View {
    let encodingMode: EncodingMode // 编码模式，只读。
    
    /// `@Binding` 属性包装器，用于绑定视频编码器。
    @Binding var videoCodec: String
    /// `@Binding` 属性包装器，用于绑定音频编码器。
    @Binding var audioCodec: String
    /// `@Binding` 属性包装器，用于绑定输出格式。
    @Binding var outputFormat: String
    /// `@Binding` 属性包装器，用于绑定视频比特率。
    @Binding var videoBitrate: String
    /// `@Binding` 属性包装器，用于绑定音频比特率。
    @Binding var audioBitrate: String
    /// `@Binding` 属性包装器，用于绑定视频宽度。
    @Binding var videoWidth: String
    /// `@Binding` 属性包装器，用于绑定视频高度。
    @Binding var videoHeight: String
    /// `@Binding` 属性包装器，用于绑定视频帧率。
    @Binding var videoFrameRate: String
    /// `@Binding` 属性包装器，用于绑定变速百分比。
    @Binding var speed: String
    /// `@Binding` 属性包装器，用于绑定仅输出音频的开关状态。
    @Binding var onlyAudio: Bool
    /// `@Binding` 属性包装器，用于绑定仅输出视频的开关状态。
    @Binding var onlyVideo: Bool
    /// `@Binding` 属性包装器，用于绑定色彩空间。
    @Binding var colorSpace: ColorSpace
    
    let videoCodecs: [String] // 可用的视频编码器列表。
    let audioCodecs: [String] // 可用的音频编码器列表。
    let outputFormats: [String] // 可用的输出格式列表。

    /// `ConversionForm` 的视图内容。
    var body: some View {
        /// `Grid` 布局，内容左对齐，水平间距20，垂直间距12。
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            /// 网格行，内容顶部对齐。
            GridRow(alignment: .firstTextBaseline) {
                /// 视频编码器选择区域。
                HStack { Text("视频编码器:"); Picker("", selection: $videoCodec) { ForEach(videoCodecs, id: \.self) { Text($0) } }.labelsHidden().frame(width: 180) }
                    .disabled(onlyAudio) // 如果仅输出音频，则禁用此区域。
                /// 视频比特率设置区域。
                HStack { Text("视频比特率:");
                    TextField("", text: $videoBitrate)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                        .disabled(encodingMode == .hardware) // 如果是硬件编码，则禁用此文本框。
                    Text("Kbps")
                        .frame(width: 60, alignment: .leading)
                }
                .disabled(onlyAudio) // 如果仅输出音频，则禁用此区域。
                /// 视频分辨率设置区域。
                HStack { Text("视频分辨率:"); TextField("宽", text: $videoWidth).frame(width: 50); Text("x"); TextField("高", text: $videoHeight).frame(width: 50) }
                    .disabled(onlyAudio) // 如果仅输出音频，则禁用此区域。
            }
            /// 网格行，内容顶部对齐。
            GridRow(alignment: .firstTextBaseline) {
                /// 音频编码选择区域。
                HStack { Text("音频编码:"); Picker("", selection: $audioCodec) { ForEach(audioCodecs, id: \.self) { Text($0) } }.labelsHidden().frame(width: 100) }
                    .disabled(onlyVideo) // 如果仅输出视频，则禁用此区域。
                /// 音频比特率设置区域。
                HStack { Text("音频比特率:"); TextField("", text: $audioBitrate).frame(width: 60).multilineTextAlignment(.trailing); Text("Kbps") }
                    .disabled(onlyVideo) // 如果仅输出视频，则禁用此区域。
                /// 视频帧率设置区域。
                HStack { Text("视频帧率:"); TextField("FPS", text: $videoFrameRate).frame(width: 50); Text("FPS") }
                    .disabled(onlyAudio) // 如果仅输出音频，则禁用此区域。
            }
            /// 网格行，内容顶部对齐。
            GridRow(alignment: .firstTextBaseline) {
                /// 输出格式选择区域。
                HStack { Text("输出格式:"); Picker("", selection: $outputFormat) { ForEach(outputFormats, id: \.self) { Text($0) } }.labelsHidden().frame(width: 100) }
                /// 仅输出音频/视频开关区域。
                HStack(spacing: 20) {
                    Toggle(isOn: $onlyAudio) { Text("仅输出音频") }.disabled(outputFormat == "MP3") // 如果输出格式是MP3，则禁用此开关。
                    Toggle(isOn: $onlyVideo) { Text("仅输出视频") }.disabled(outputFormat == "MP3") // 如果输出格式是MP3，则禁用此开关。
                }
                /// 变速设置区域。
                HStack { Text("变速:"); TextField("", text: $speed).frame(width: 50).multilineTextAlignment(.trailing); Text("%") }
            }
            /// 网格行，内容顶部对齐。
            GridRow(alignment: .firstTextBaseline) {
                /// 色彩空间选择区域。
                HStack { Text("色彩空间:"); Picker("", selection: $colorSpace) { ForEach(ColorSpace.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
            }
        }
    }
}

/// `GeneralView_Previews` 结构体用于 SwiftUI 预览。
struct GeneralView_Previews: PreviewProvider {
    /// 预览内容。
    static var previews: some View {
        /// 返回 `GeneralView` 实例，并注入 `CommandRunner` 环境对象，设置预览宽度。
        GeneralView(
            encodingMode: .constant(.software),
            videoCodec: .constant("HEVC"),
            audioCodec: .constant("AAC"),
            outputFormat: .constant("MP4"),
            videoBitrate: .constant("1000"),
            audioBitrate: .constant("128"),
            videoWidth: .constant(""),
            videoHeight: .constant(""),
            videoFrameRate: .constant(""),
            speed: .constant("100"),
            onlyAudio: .constant(false),
            onlyVideo: .constant(false),
            colorSpace: .constant(.rec709)
        )
        .frame(width: 850)
    }
}
