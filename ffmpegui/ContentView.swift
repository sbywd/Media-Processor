import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// `ProgressDisplayView` 结构体，用于显示 FFmpeg 命令执行进度。
/// 它接收一个 `ProcessingProgress` 对象来更新进度信息。
struct ProgressDisplayView: View {
    /// `progress` 属性存储当前的处理进度数据。
    let progress: ProcessingProgress

    /// `ProgressDisplayView` 的视图内容。
    var body: some View {
        /// 垂直堆栈布局，内容左对齐，间距为 4。
        VStack(alignment: .leading, spacing: 4) {
            /// 水平堆栈布局，用于显示进度条和百分比。
            HStack {
                /// `ProgressView` 显示线性进度条，其值由 `progress.fractionCompleted` 决定。
                ProgressView(value: progress.fractionCompleted)
                
                /// 显示完成百分比，使用等宽字体，固定宽度，右对齐。
                Text("\(progress.percentage)%")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 40, alignment: .trailing)
            }
            
            /// 水平堆栈布局，用于动态显示进度文本和预计剩余时间 (ETA)。
            HStack {
                /// 如果帧信息（当前帧和总帧数）可用，则显示帧进度。
                if let currentFrame = progress.currentFrame, let totalFrames = progress.totalFrames {
                    Text("\(currentFrame) / 共\(totalFrames)帧")
                } else {
                    /// 否则，显示当前时间和总时长。
                    Text("\(formatTime(seconds: progress.currentTime)) / \(formatTime(seconds: progress.totalDuration))")
                }
                
                Spacer() // 填充剩余空间，将后续内容推到右侧。
                
                /// 如果可以计算出预计剩余时间 (ETA)，则显示它。
                if let eta = progress.estimatedTimeRemaining {
                    Text("剩余: \(formatTime(seconds: eta))")
                }
            }
            .font(.caption) // 设置字体为标题样式。
            .foregroundColor(.secondary) // 设置前景色为辅助色。
        }
    }
    
    /// `formatTime` 辅助函数，将时间间隔（秒）格式化为 `HH:MM:SS` 或 `MM:SS` 字符串。
    /// - Parameter seconds: 要格式化的时间间隔（秒）。
    /// - Returns: 格式化的时间字符串。
    private func formatTime(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter() // 创建一个日期组件格式化器。
        formatter.allowedUnits = [.hour, .minute, .second] // 允许显示小时、分钟和秒。
        formatter.unitsStyle = .positional // 设置单位样式为位置（例如，01:02:03）。
        formatter.zeroFormattingBehavior = .pad // 用零填充小于两位数的数字。
        /// 当时间小于 1 小时（3600 秒）时，不显示“00:”小时部分，只显示分钟和秒。
        if seconds < 3600 {
            formatter.allowedUnits = [.minute, .second]
        }
        /// 格式化时间并返回字符串，如果格式化失败则返回“00:00”。
        return formatter.string(from: seconds) ?? "00:00"
    }
}

/// `ContentView` 结构体是应用程序的主内容视图。
/// 它包含 FFmpeg 命令执行界面和状态显示。
struct ContentView: View {
    /// `@StateObject` 属性包装器，用于创建和管理 `CommandRunner` 实例的生命周期。
    /// `CommandRunner` 负责执行 FFmpeg 命令并提供其输出和进度。
    @StateObject private var commandRunner = CommandRunner()
    
    // MARK: 状态变量（从 GeneralView 移动）
    /// `@State` 属性包装器，用于存储用户选择的输入文件的 URL。
    @State private var inputFile: URL?
    /// `@State` 属性包装器，用于存储用户选择的输出文件的 URL。
    @State private var outputFile: URL?
    
    /// `@State` 属性包装器，用于存储探测到的文件信息（视频和音频详细信息）。
    @State private var fileInfo: ProbedFileInfo?
    /// `@State` 属性包装器，用于存储输入文件的缩略图。
    @State private var thumbnailImage: NSImage?
    /// `@State` 属性包装器，用于存储视频的总帧数。
    @State private var totalFrames: Int?
    /// `@State` 属性包装器，用于存储视频的总时长。
    @State private var totalDuration: TimeInterval?

    /// `@State` 属性包装器，用于存储当前选择的编码模式（软件或硬件）。
    @State private var encodingMode: EncodingMode = .software
    /// `@State` 属性包装器，用于存储当前选择的视频编解码器。
    @State private var videoCodec = "HEVC"
    
    /// `@State` 属性包装器，用于存储当前选择的音频编解码器。
    @State private var audioCodec = "AAC"
    /// `@State` 属性包装器，用于存储当前选择的输出文件格式。
    @State private var outputFormat = "MP4"
    /// `@State` 属性包装器，用于存储视频比特率。
    @State private var videoBitrate = "1000"
    /// `@State` 属性包装器，用于存储音频比特率。
    @State private var audioBitrate = "128"
    /// `@State` 属性包装器，用于存储视频宽度。
    @State private var videoWidth = ""
    /// `@State` 属性包装器，用于存储视频高度。
    @State private var videoHeight = ""
    /// `@State` 属性包装器，用于存储视频帧率。
    @State private var videoFrameRate = ""
    /// `@State` 属性包装器，用于存储视频播放速度（百分比）。
    @State private var speed = "100"
    /// `@State` 属性包装器，布尔值，指示是否只输出音频。
    @State private var onlyAudio = false
    /// `@State` 属性包装器，布尔值，指示是否只输出视频。
    @State private var onlyVideo = false
    /// `@State` 属性包装器，用于存储当前选择的色彩空间。
    @State private var colorSpace: ColorSpace = .rec709
    
    ///SubtitleView
    @State private var subtitletype:SubtitleType = .hardsubtitle
    @State private var fontname = "苹方"
    @State private var fontsize = "18"
    @State private var alignment = "2"
    @State private var primaryColor = Color(hex: "2cc1a4") // BBGGRR format
    @State private var outlineColor = Color(hex: "100000000") // AABBGGRR format
    @State private var backColor = Color(hex: "000000") // AABBGGRR format
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderline = false
    @State private var isStrikeout = false
    @State private var outlineWidth = "1"
    @State private var shadowDepth = "0"
    @State private var borderStyle = "1 (边框+阴影)"
    @State private var inputSubtitleFile: URL?
    
    /// `@State` 属性包装器，用于存储 FFmpeg 命令预览字符串。
    @State private var commandPreview: String = "请选择输入和输出文件。"
    
    /// `ContentView` 的视图内容。
    var body: some View {
        mainContent
    }
    
    /// 主内容视图，封装水平堆栈布局。
    private var mainContent: some View {
        /// 水平堆栈布局，间距为 0，用于并排显示 Tab 视图和 FFmpeg 状态面板。
        HStack(spacing: 0) {
            /// 垂直堆栈布局，内容左对齐，间距为 16。
            VStack(alignment: .leading, spacing: 10) {
                fileSelectionButtons // 文件选择按钮区域
                
                /// 如果输入文件和文件信息存在，则显示文件详细信息视图。
                if let inputFile = inputFile, let info = fileInfo {
                    FileDetailView(url: inputFile, thumbnail: thumbnailImage, info: info)
                }
                
                Divider().padding(.vertical, 8) // 分隔线，带有垂直填充。
                
                conversionTabs // 选项卡式转换设置
                
                Divider().padding(.vertical, 8) // 分隔线，带有垂直填充。
                
                commandPreviewSection // 命令预览区域
                
                startButton // 开始转换按钮
            }
            
            .padding(10) // 添加内部填充。
            .frame(minWidth: 900, maxWidth: .infinity) // 设置最小和最大宽度。
            
            Divider() // 添加垂直分隔线。
            
            ffmpegStatusPanel // FFmpeg 状态和输出面板
        }
        .background(.ultraThickMaterial)
    
        .frame(minHeight: 480) // 设置最小高度。
        .onAppear(perform: updateCommand) // 视图出现时更新命令预览。
        /// 监听 `inputFile` 变化并调用 `handleInputFileChange` 方法。
        .onChange(of: inputFile) { url in handleInputFileChange(url: url) }
        /// 监听 `outputFile` 变化并更新命令预览。
        .onChange(of: outputFile) { _ in self.updateCommand() }
        /// 监听 `videoCodec` 变化并更新命令预览。
        .onChange(of: videoCodec) { _ in self.updateCommand() }
        /// 监听 `audioCodec` 变化并更新命令预览。
        .onChange(of: audioCodec) { _ in self.updateCommand() }
        /// 监听 `outputFormat` 变化。
        .onChange(of: outputFormat) { newValue in
            /// 如果输出格式是 MP3，则强制只输出音频并选择 MP3 音频编解码器。
            if newValue == "MP3" {
                onlyAudio = true
                onlyVideo = false
                audioCodec = "MP3"
            }
            self.updateCommand() // 更新命令预览。
        }
        /// 监听 `encodingMode` 变化。
        .onChange(of: encodingMode) { newMode in
            /// 根据新的编码模式调整视频编解码器。
            if newMode == .hardware {
                videoCodec = "HEVC (VideoToolbox)"
            } else {
                videoCodec = "HEVC"
            }
            self.updateCommand() // 更新命令预览。
        }
        /// 监听 `videoBitrate` 变化并更新命令预览。
        .onChange(of: videoBitrate) { _ in self.updateCommand() }
        /// 监听 `audioBitrate` 变化并更新命令预览。
        .onChange(of: audioBitrate) { _ in self.updateCommand() }
        /// 监听 `onlyAudio` 变化并更新命令预览。
        .onChange(of: onlyAudio) { _ in self.updateCommand() }
        /// 监听 `onlyVideo` 变化并更新命令预览。
        .onChange(of: onlyVideo) { _ in self.updateCommand() }
        /// 监听 `videoWidth` 变化并更新命令预览。
        .onChange(of: videoWidth) { _ in self.updateCommand() }
        /// 监听 `videoHeight` 变化并更新命令预览。
        .onChange(of: videoHeight) { _ in self.updateCommand() }
        /// 监听 `videoFrameRate` 变化并更新命令预览。
        .onChange(of: videoFrameRate) { _ in self.updateCommand() }
        /// 监听 `speed` 变化并更新命令预览。
        .onChange(of: speed) { _ in self.updateCommand() }
        /// 监听字幕相关参数变化并更新命令预览
        .onChange(of: subtitletype) { _ in self.updateCommand() }
        .onChange(of: fontname) { _ in self.updateCommand() }
        .onChange(of: fontsize) { _ in self.updateCommand() }
        .onChange(of: alignment) { _ in self.updateCommand() }
        .onChange(of: primaryColor) { _ in self.updateCommand() }
        .onChange(of: outlineColor) { _ in self.updateCommand() }
        .onChange(of: backColor) { _ in self.updateCommand() }
        .onChange(of: isBold) { _ in self.updateCommand() }
        .onChange(of: isItalic) { _ in self.updateCommand() }
        .onChange(of: isUnderline) { _ in self.updateCommand() }
        .onChange(of: isStrikeout) { _ in self.updateCommand() }
        .onChange(of: outlineWidth) { _ in self.updateCommand() }
        .onChange(of: shadowDepth) { _ in self.updateCommand() }
        .onChange(of: borderStyle) { _ in self.updateCommand() }
        .onChange(of: inputSubtitleFile) { _ in self.updateCommand() }
        // 修复：监听色彩空间变化，实时更新命令
        .onChange(of: colorSpace) { _ in self.updateCommand() }
    }
        
    /// 选项卡式转换设置视图。
    private var conversionTabs: some View {
        TabView {
            /// `GeneralView` 是文件转换功能的选项卡页面。
            GeneralView(
                encodingMode: $encodingMode,
                videoCodec: $videoCodec, audioCodec: $audioCodec, outputFormat: $outputFormat,
                videoBitrate: $videoBitrate, audioBitrate: $audioBitrate,
                videoWidth: $videoWidth, videoHeight: $videoHeight, videoFrameRate: $videoFrameRate,
                speed: $speed, onlyAudio: $onlyAudio, onlyVideo: $onlyVideo, colorSpace: $colorSpace
            )
            .tabItem { Text("通用") } // 设置选项卡页面标题和系统图标。
            
            SubtitleView(
                subtitletype: $subtitletype,
                fontname: $fontname,
                fontsize: $fontsize,
                alignment: $alignment,
                primaryColor: $primaryColor,
                outlineColor: $outlineColor,
                backColor: $backColor,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderline: $isUnderline,
                isStrikeout: $isStrikeout,
                outlineWidth: $outlineWidth,
                shadowDepth: $shadowDepth,
                borderStyle: $borderStyle,
                inputSubtitleFile: $inputSubtitleFile
            )
            .tabItem { Text("字幕") }
            
        }
        .tabViewStyle(.automatic) // 使用自动样式以获得更好的定位
        .frame(minWidth: 850, maxWidth: .infinity, minHeight: 100) // 设置最小和最大宽度。
        .padding(.bottom, 8) // 添加填充以与命令预览分隔
    }
    
    /// FFmpeg 状态和输出面板视图。
    private var ffmpegStatusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            /// 水平堆栈布局，用于显示标题和清除按钮。
            HStack {
                Text("FFmpeg 状态") // 状态面板的标题。
                    .font(.headline) // 设置字体为标题样式。
                Spacer() // 填充剩余空间。
                /// 清除输出内容的按钮。
                Button(action: { commandRunner.output = "" }) {
                    Image(systemName: "trash") // Uses system trash icon.
                }
                /// 当输出为空且命令未运行时禁用按钮。
                .disabled(commandRunner.output.isEmpty && !commandRunner.isRunning)
            }
            
            /// 如果命令正在运行且进度信息可用，则显示 `ProgressDisplayView`。
            if commandRunner.isRunning, let progress = commandRunner.progress {
                ProgressDisplayView(progress: progress) // 传递进度数据。
                    .padding(.bottom, 8) // 添加底部填充。
                Divider() // 添加分隔线。
            }
            
            /// `ScrollViewReader` 允许对 `ScrollView` 进行编程滚动。
            ScrollViewReader { scrollViewProxy in
                /// `ScrollView` 用于显示 FFmpeg 输出日志。
                ScrollView {
                    Text(commandRunner.output) // 显示 `commandRunner` 的输出内容。
                        .font(.system(.caption, design: .monospaced)) // 设置字体为标题等宽样式。
                        .frame(maxWidth: .infinity, alignment: .leading) // 设置最大宽度和左对齐。
                        .padding(8) // 添加内部填充。
                        .background(Color(NSColor.textBackgroundColor)) // 设置背景颜色。
                        .cornerRadius(6) // 设置圆角。
                        .textSelection(.enabled) // 启用文本选择。
                        .id("output_text_id") // 为 `Text` 视图添加 ID 以进行滚动。
                }
                .frame(minHeight: 250, maxHeight: .infinity) // 设置最小和最大高度。
                /// 监听 `commandRunner.output` 的变化。
                .onChange(of: commandRunner.output) { _ in
                    /// 当输出内容变化时，滚动到 `output_text_id` 视图的底部。
                    scrollViewProxy.scrollTo("output_text_id", anchor: .bottom)
                }
            }
        }
        .padding() // 添加内部填充。
        .frame(width: 300) // 设置固定宽度。
    }
    
    // MARK: - 作为计算属性的子视图（从 GeneralView 移动）
    
    /// 文件选择按钮视图。
    private var fileSelectionButtons: some View {
        HStack {
            /// 选择输入文件的按钮，点击时显示文件选择面板。
            Button("选择输入文件") { showInputFilePicker() }
            /// 选择输出位置的按钮，点击时显示保存面板。
            Button("选择输出位置") { showSavePanel() }
            Spacer() // 填充剩余空间。
        }
    }
    
    /// 命令预览区域视图。
    private var commandPreviewSection: some View {
        VStack(alignment: .leading) {
            Text("构建的命令:").font(.headline) // 命令预览标题。
            /// `TextEditor` 用于显示 FFmpeg 命令预览，内容不可编辑。
            TextEditor(text: .constant("ffmpeg " + commandPreview))
                .font(.system(.caption, design: .monospaced)) // 设置字体样式。
                .frame(height: 100) // 设置固定高度。
                .background(Color(.textBackgroundColor)) // 设置背景颜色。
                .cornerRadius(5) // 设置圆角。
                .border(Color.gray.opacity(0.2), width: 1) // 添加边框。
        }
    }
    
    /// 开始转换按钮视图。
    private var startButton: some View {
        /// 开始转换按钮，显示“开始转换”文本和播放图标。
        Button(action: executeCommand) { Label("开始转换", systemImage: "play.fill") }
            /// 按钮禁用条件：如果命令正在运行，或者输入文件、输出文件、总时长未确定。
            .disabled(commandRunner.isRunning || inputFile == nil || outputFile == nil || totalDuration == nil)
    }
    
    // MARK: - 逻辑方法（从 GeneralView 移动）
    
    /// 处理输入文件变化的逻辑。
    /// - Parameter url: 新的输入文件 URL，如果文件被清除则为 nil。
    private func handleInputFileChange(url: URL?) {
        /// 如果 URL 为 nil，则清除所有文件相关信息并更新命令。
        guard let url = url else {
            fileInfo = nil; thumbnailImage = nil; totalFrames = nil; totalDuration = nil
            updateCommand()
            return
        }
        
        /// 将文件信息、缩略图、总帧数和总时长初始化为 nil。
        self.fileInfo = ProbedFileInfo()
        self.thumbnailImage = nil
        self.totalFrames = nil
        self.totalDuration = nil
        
        /// 在全局并发队列上异步生成缩略图。
        DispatchQueue.global().async {
            let image = url.thumbnail()
            /// 在主队列上更新缩略图。
            DispatchQueue.main.async { self.thumbnailImage = image }
        }
        
        autoFillParameters(from: url) // 自动填充参数。
        updateCommand() // 更新命令预览。
    }
    
    /// 通过探测输入文件信息自动填充转换参数。
    /// - Parameter url: 输入文件的 URL。
    private func autoFillParameters(from url: URL) {
        /// 调用 `commandRunner` 的 `probe` 方法来探测文件信息。
        commandRunner.probe(fileURL: url) { result in
            switch result {
            case .success(let probeData):
                var newInfo = ProbedFileInfo() // 创建新的文件信息结构体。
                /// 查找包含时长的流（优先视频流，否则第一个流）。
                let streamWithDuration = probeData.streams.first(where: { $0.codec_type == "video" }) ?? probeData.streams.first
                /// 如果可以获取时长，则更新 `totalDuration`。
                if let durationStr = streamWithDuration?.duration, let duration = Double(durationStr) {
                    self.totalDuration = duration
                } else { self.totalDuration = nil }

                /// 如果视频流存在。
                if let videoStream = probeData.streams.first(where: { $0.codec_type == "video" }) {
                    self.videoWidth = "\(videoStream.width ?? 0)" // 更新视频宽度。
                    self.videoHeight = "\(videoStream.height ?? 0)" // 更新视频高度。
                    let fpsString: String
                    /// 计算并更新视频帧率。
                    if let frameRateStr = videoStream.avg_frame_rate, let frameRate = calculateFrameRate(from: frameRateStr) {
                        fpsString = String(format: "%.2f", frameRate)
                    } else { fpsString = "N/A" }
                    self.videoFrameRate = fpsString
                    /// 提取并更新视频比特率。
                    let rawVideoBitrate = videoStream.bit_rate?.filter("0123456789.".contains) ?? "0"
                    let bitrateKbps = (Int(rawVideoBitrate) ?? 0) / 1000
                    self.videoBitrate = "\(bitrateKbps)"
                    
                    self.encodingMode = .software // 默认为软件编码。
                    /// 根据视频编解码器名称设置 `videoCodec`。
                    switch videoStream.codec_name {
                    case "hevc": self.videoCodec = "HEVC"
                    case "h264": self.videoCodec = "H.264"
                    default: self.videoCodec = "H.264"
                    }
                    
                    /// 构造视频信息字符串。
                    newInfo.videoInfo = "\(videoStream.width ?? 0)x\(videoStream.height ?? 0) | \(videoStream.codec_name?.uppercased() ?? "UNKNOWN") | \(bitrateKbps)Kbps | \(fpsString)FPS"

                    /// 如果总时长和帧率存在，则计算并更新总帧数。
                    if let duration = self.totalDuration, let frameRateStr = videoStream.avg_frame_rate, let frameRate = calculateFrameRate(from: frameRateStr), frameRate > 0 {
                        self.totalFrames = Int((duration * frameRate).rounded())
                    } else { self.totalFrames = nil }
                }
                
                /// 如果音频流存在。
                if let audioStream = probeData.streams.first(where: { $0.codec_type == "audio" }) {
                    /// 提取并更新音频比特率。
                    let rawAudioBitrate = audioStream.bit_rate?.filter("0123456789.".contains) ?? "0"
                    let bitrateKbps = (Int(rawAudioBitrate) ?? 0) / 1000
                    self.audioBitrate = "\(bitrateKbps)"
                    /// 根据音频编解码器名称设置 `audioCodec`。
                    switch audioStream.codec_name {
                    case "aac": self.audioCodec = "AAC"
                    case "opus": self.audioCodec = "Opus"
                    case "mp3": self.audioCodec = "MP3"
                    default: self.audioCodec = "AAC"
                    }
                    /// 构造音频信息字符串。
                    newInfo.audioInfo = "\(audioStream.codec_name?.uppercased() ?? "UNKNOWN") | \(bitrateKbps)Kbps"
                }
                self.fileInfo = newInfo // 更新文件信息。
                self.updateCommand() // 更新命令预览。
            case .failure(let error):
                print("文件探测失败: \(error.localizedDescription)") // 打印探测失败错误。
                let errorDetails = "错误: \(error.localizedDescription)" // 错误详情。
                self.fileInfo = ProbedFileInfo(videoInfo: "获取失败", audioInfo: errorDetails) // 将文件信息设置为获取失败。
                self.totalFrames = nil // 清除总帧数。
                self.totalDuration = nil // 清除总时长。
                self.updateCommand() // 更新命令预览。
            }
        }
    }
    
    /// 构造 FFmpeg 命令字符串。
    /// - Returns: 构造的 FFmpeg 命令字符串。
    private func buildCommandString() -> String {
        /// 确保输入和输出文件都已选择。
        guard let inputPath = inputFile?.path, let baseOutputURL = outputFile else { return "" }
        /// 根据输出格式生成最终输出文件 URL。
        let finalOutputURL = baseOutputURL.deletingPathExtension().appendingPathExtension(outputFormat.lowercased())
        var components: [String] = [] // 用于存储命令组件的列表。
        
        components.append("-i \"\(inputPath)\"") // 添加输入文件路径。
        
        var videoFilters: [String] = [] // 视频滤镜列表。
        /// 如果设置了速度且不为 100%，则添加视频速度滤镜。
        if let speedValue = Double(speed), speedValue != 100 { let pts = 100.0 / speedValue; videoFilters.append("setpts=\(String(format: "%.4f", pts))*PTS") }
        var audioFilters: [String] = [] // 音频滤镜列表。
        /// 如果设置了速度且不为 100%，则添加音频速度滤镜。
        if let speedValue = Double(speed), speedValue != 100 { var tempo = speedValue / 100.0; while tempo > 100.0 { audioFilters.append("atempo=100.0"); tempo /= 100.0 }; while tempo < 0.5 && tempo > 0 { audioFilters.append("atempo=0.5"); tempo /= 0.5 }; if tempo >= 0.5 && tempo <= 100.0 { audioFilters.append("atempo=\(String(format: "%.4f", tempo))") } }
        
        // 字幕滤镜
        if let subtitlePath = inputSubtitleFile?.path, subtitletype == .hardsubtitle {
            var subtitleStyleComponents: [String] = []
            if !fontname.isEmpty { subtitleStyleComponents.append("FontName=\(fontname)") }
            if !fontsize.isEmpty { subtitleStyleComponents.append("FontSize=\(fontsize)") }
            subtitleStyleComponents.append("PrimaryColour=&H\(primaryColor.toAABBGGRRHex())")
            subtitleStyleComponents.append("OutlineColour=&H\(outlineColor.toAABBGGRRHex())")
            subtitleStyleComponents.append("BackColour=&H\(backColor.toAABBGGRRHex())")
            if isBold { subtitleStyleComponents.append("Bold=-1") }
            if isItalic { subtitleStyleComponents.append("Italic=-1") }
            if isUnderline { subtitleStyleComponents.append("Underline=-1") }
            if isStrikeout { subtitleStyleComponents.append("Strikeout=-1") }
            if !outlineWidth.isEmpty { subtitleStyleComponents.append("Outline=\(outlineWidth)") }
            if !shadowDepth.isEmpty { subtitleStyleComponents.append("Shadow=\(shadowDepth)") }
            if let bs = borderStyle.split(separator: " ").first { subtitleStyleComponents.append("BorderStyle=\(bs)") }
            if let align = alignment.split(separator: " ").first { subtitleStyleComponents.append("Alignment=\(align)") }
            
            let styleString = subtitleStyleComponents.joined(separator: ",")
            videoFilters.append("subtitles='\(subtitlePath)':force_style='\(styleString)'")
        }
        
        /// 如果不是仅音频且视频滤镜不为空，则添加视频滤镜。
        if !onlyAudio && !videoFilters.isEmpty { components.append("-filter:v \"\(videoFilters.joined(separator: ","))\"") }
        /// 如果不是仅视频且音频滤镜不为空，则添加音频滤镜。
        if !onlyVideo && !audioFilters.isEmpty { components.append("-filter:a \"\(audioFilters.joined(separator: ","))\"") }
        
        /// 如果是仅音频，则添加 `-vn` 参数（无视频）。
        if onlyAudio { components.append("-vn") }
        /// 如果是仅视频，则添加 `-an` 参数（无音频）。
        if onlyVideo { components.append("-an") }
        
        /// 如果不是仅音频。
        if !onlyAudio {
            switch encodingMode {
            case .software: // 软件编码模式。
                switch videoCodec {
                case "HEVC": // HEVC 编解码器。
                    components.append("-c:v libx265") // 使用 libx265 编解码器。
                    components.append("-pix_fmt yuv420p") // 设置像素格式。
                    components.append("-tag:v hvc1") // 添加视频标签。
                case "H.264": // H.264 编解码器。
                    components.append("-c:v libx264") // 使用 libx264 编解码器。
                    components.append("-pix_fmt yuv420p") // 设置像素格式。
                default: break // 其他情况未处理。
                }
                /// 如果视频比特率不为空且不为 0，则添加视频比特率参数。
                if !videoBitrate.isEmpty && videoBitrate != "0" { components.append("-b:v \(videoBitrate)k") }

            case .hardware: // 硬件编码模式。
                switch videoCodec {
                case "HEVC (VideoToolbox)": // HEVC (VideoToolbox) 编解码器。
                    components.append("-c:v hevc_videotoolbox") // 使用 hevc_videotoolbox 编解码器。
                    components.append("-q:v 70") // 设置视频质量。
                    components.append("-tag:v hvc1") // 添加视频标签。
                case "H.264 (VideoToolbox)": // H.264 (VideoToolbox) 编解码器。
                    components.append("-c:v h264_videotoolbox") // 使用 h264_videotoolbox 编解码器。
                    components.append("-q:v 65") // 设置视频质量。
                default: break // 其他情况未处理。
                }
            }
            
            /// 如果视频宽度和高度不为空，则添加分辨率参数。
            if !videoWidth.isEmpty && !videoHeight.isEmpty { components.append("-s \(videoWidth)x\(videoHeight)") }
            /// 如果视频帧率不为空且不为 0，则添加帧率参数。
            if !videoFrameRate.isEmpty && videoFrameRate != "0" { components.append("-r \(videoFrameRate)") }
            
            // 添加色彩空间参数
            if colorSpace != .rec709 {
                for (key, value) in colorSpace.ffmpegParams {
                    components.append("-\(key) \(value)")
                }
            }
        }
        
        /// 如果不是仅视频。
        if !onlyVideo {
            switch audioCodec {
            case "AAC": components.append("-c:a aac") // AAC 编解码器。
            case "Opus": components.append("-c:a libopus") // Opus 编解码器。
            case "MP3": components.append("-c:a libmp3lame") // MP3 编解码器。
            default: break // 其他情况未处理。
            }
            /// 如果音频比特率不为空且不为 0，则添加音频比特率参数。
            if audioBitrate.isEmpty && audioBitrate != "0" { components.append("-b:a \(audioBitrate)k") }
        }
        
        components.append("-y \"\(finalOutputURL.path)\"") // 添加输出文件路径和覆盖输出文件参数。
        return components.joined(separator: " ") // 将所有组件用空格连接成最终命令字符串。
    }
    
    /// 更新 FFmpeg 命令预览字符串。
    private func updateCommand() {
        let commandString = buildCommandString() // 构建命令字符串。
        /// 如果命令字符串为空，则根据文件选择显示提示。
        if commandString.isEmpty {
            if inputFile == nil { commandPreview = "请选择一个输入文件。" }
            else if outputFile == nil { commandPreview = "请选择输出文件的保存位置。" }
            else { commandPreview = "请选择输入和输出文件。" }
        } else {
            commandPreview = commandString // 否则，显示构造的命令字符串。
        }
    }
    
    /// 执行 FFmpeg 命令。
    private func executeCommand() {
        /// 确保总时长已确定。
        guard let duration = self.totalDuration else {
            print("错误：总时长未确定。无法开始转换。") // 打印错误消息。
            return
        }
        let commandString = buildCommandString() // 构建命令字符串。
        /// 如果命令字符串不为空，则运行命令。
        if !commandString.isEmpty {
            commandRunner.run(command: commandString, totalFrames: self.totalFrames, totalDuration: duration)
        }
    }
    
    /// 从字符串计算帧率。
    /// - Parameter string: 包含帧率的字符串，例如“30000/1001”。
    /// - Returns: 计算出的帧率（Double 类型），如果无法计算则为 nil。
    private func calculateFrameRate(from string: String) -> Double? {
        let components = string.split(separator: "/") // 按“/”分割字符串。
        /// 确保分割后有两部分，两部分都可以转换为 Double，并且分母不为 0。
        guard components.count == 2, let numerator = Double(components[0]), let denominator = Double(components[1]), denominator != 0 else { return nil }
        return numerator / denominator // 返回计算出的帧率。
    }
    
    /// 显示输入文件选择面板。
    private func showInputFilePicker() {
        let openPanel = NSOpenPanel() // 创建一个文件打开面板。
        openPanel.canChooseFiles = true // 允许选择文件。
        openPanel.allowsMultipleSelection = false // 不允许多选。
        openPanel.canChooseDirectories = false // 不允许选择目录。
        /// 开始显示面板并在用户选择后处理结果。
        openPanel.begin { response in
            /// 如果用户点击“确定”并选择一个文件，则更新 `inputFile`。
            if response == .OK, let url = openPanel.url { self.inputFile = url }
        }
    }
    
    /// 显示输出文件保存面板。
    private func showSavePanel() {
        let savePanel = NSSavePanel() // 创建一个文件保存面板。
        savePanel.canCreateDirectories = true // 允许创建新目录。
        /// 根据输入文件名和输出格式生成默认文件名。
        let baseName = inputFile?.deletingPathExtension().lastPathComponent ?? "output"
        let newExtension = outputFormat.lowercased()
        savePanel.nameFieldStringValue = "\(baseName)_converted.\(newExtension)"
        /// 如果可以从新扩展名创建 UTType，则设置允许的文件类型。
        if let type = UTType(filenameExtension: newExtension) {
            savePanel.allowedContentTypes = [type]
        }
        savePanel.isExtensionHidden = false // 显示文件扩展名。
        /// 开始显示面板并在用户选择后处理结果。
        savePanel.begin { response in
            /// 如果用户点击“确定”并选择一个保存位置，则更新 `outputFile`。
            if response == .OK, let url = savePanel.url { self.outputFile = url }
        }
    }
}

/// `ContentView_Previews` 结构体，用于 SwiftUI 预览。
struct ContentView_Previews: PreviewProvider {
    /// 预览内容。
    static var previews: some View {
        /// 为预览创建一个 `CommandRunner` 实例。
        let runner = CommandRunner()
        runner.isRunning = true // 设置为运行状态。
        /// 设置一个模拟的 `ProcessingProgress` 实例以显示进度条。
        runner.progress = ProcessingProgress(
            currentTime: 50, // 当前时间。
            totalDuration: 120, // 总时长。
            currentFrame: 1500, // 当前帧数。
            totalFrames: 3600, // 总帧数。
            speed: 1.5 // 速度。
        )
        /// 返回 `ContentView` 实例，注入模拟的 `CommandRunner` 环境对象。
        return ContentView()
            .environmentObject(runner)
    }
}
