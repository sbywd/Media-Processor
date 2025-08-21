//AI编程工具请不要删除注释
//此文件包含主视图和命令构建函数
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Models

struct ProcessingProperties {
    var resolutionEnabled: Bool, frameRateEnabled: Bool, videoBitrateEnabled: Bool, audioBitrateEnabled: Bool, containerEnabled: Bool, speedEnabled: Bool, subtitleEnabled: Bool, exportAudioOnlyEnabled: Bool, exportVideoOnlyEnabled: Bool
    var resolutionWidth: String, resolutionHeight: String, keepAspectRatio: Bool, frameRate: String, videoBitrate: String, videoEncoder: String, audioBitrate: String, audioEncoder: String, containerFormat: String
    var speedPercentage: String
    var subtitleFilePath: String, subtitlePosition: String, subtitleColor: Color, subtitleFont: String, subtitleFontSize: String, subtitleOutlineColor: Color, subtitleOutlineWidth: String
}

class VideoItem: ObservableObject, Identifiable, Equatable {
    let id: UUID
    let url: URL
    
    // MARK: - Published Properties
    @Published var thumbnail: NSImage?
    @Published var videoInfo: String = "正在加载信息..."
    @Published var audioInfo: String = ""
    @Published var duration: TimeInterval?
    
    // --- 处理设置 ---
    @Published var resolutionEnabled: Bool = false
    @Published var frameRateEnabled: Bool = false
    @Published var videoBitrateEnabled: Bool = false
    @Published var audioBitrateEnabled: Bool = false
    @Published var containerEnabled: Bool = false
    @Published var speedEnabled: Bool = false
    @Published var subtitleEnabled: Bool = false
    @Published var exportAudioOnlyEnabled: Bool = false
    @Published var exportVideoOnlyEnabled: Bool = false

    // --- 修正：将 didSet 观察者添加到现有声明上 ---
    @Published var resolutionWidth: String = "1920" {
        didSet {
            guard !isAdjustingAspectRatio, keepAspectRatio else { return }
            guard let newWidth = Int(resolutionWidth),
                  let oWidth = originalWidth, oWidth > 0,
                  let oHeight = originalHeight, oHeight > 0 else { return }
            
            isAdjustingAspectRatio = true
            let newHeight = Int(round(Double(newWidth) * (Double(oHeight) / Double(oWidth))))
            self.resolutionHeight = "\(newHeight)"
            isAdjustingAspectRatio = false
        }
    }
    
    @Published var resolutionHeight: String = "1080" {
        didSet {
            guard !isAdjustingAspectRatio, keepAspectRatio else { return }
            guard let newHeight = Int(resolutionHeight),
                  let oWidth = originalWidth, oWidth > 0,
                  let oHeight = originalHeight, oHeight > 0 else { return }

            isAdjustingAspectRatio = true
            let newWidth = Int(round(Double(newHeight) * (Double(oWidth) / Double(oHeight))))
            self.resolutionWidth = "\(newWidth)"
            isAdjustingAspectRatio = false
        }
    }
    
    @Published var keepAspectRatio: Bool = true // 保持比例复选框的状态
    @Published var frameRate: String = "60"
    @Published var videoBitrate: String = "1600"
    @Published var videoEncoder: String = "HEVC (硬件)"
    @Published var audioBitrate: String = "32"
    @Published var audioEncoder: String = "AAC"
    @Published var containerFormat: String = "MP4"

    @Published var speedPercentage: String = "100"
    @Published var subtitleFilePath: String = ""
    @Published var subtitlePosition: String = "中下"
    @Published var subtitleColor: Color = .white
    @Published var subtitleFont: String = "PingFang SC" // Default to PingFang SC (苹方-简)
    @Published var subtitleFontSize: String = "24"
    @Published var subtitleOutlineColor: Color = .black
    @Published var subtitleOutlineWidth: String = "2"
    
    // --- 新增：用于处理分辨率比例联动的属性 ---
    private var isAdjustingAspectRatio = false
    private var originalWidth: Int?
    private var originalHeight: Int?

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool { lhs.id == rhs.id }
    init(url: URL) { self.id = UUID(); self.url = url }
    
    var processingSummary: String {
        if exportAudioOnlyEnabled {
            return "仅导出音频"
        }
        if exportVideoOnlyEnabled {
            return "仅导出视频"
        }
        
        var enabledItems: [String] = []
        if resolutionEnabled {
            enabledItems.append(NSLocalizedString("分辨率", comment: "分辨率"))
        }
        if frameRateEnabled {
            enabledItems.append(NSLocalizedString("帧速率", comment: "帧速率"))
        }
        if videoBitrateEnabled {
            enabledItems.append(NSLocalizedString("视频比特率", comment: "视频比特率"))
        }
        if audioBitrateEnabled {
            enabledItems.append(NSLocalizedString("音频比特率", comment: "音频比特率"))
        }
        if containerEnabled {
            enabledItems.append(NSLocalizedString("容器格式", comment: "容器格式"))
        }
        if speedEnabled {
            enabledItems.append(NSLocalizedString("变速", comment: "变速"))
        }
        if subtitleEnabled {
            enabledItems.append(NSLocalizedString("字幕", comment: "字幕"))
        }

        if enabledItems.isEmpty {
            return String(NSLocalizedString("无处理项", comment: "无处理项"))
        }

        switch enabledItems.count {
        case 1...3:
            return enabledItems.joined(separator: "、")
        default:
            let firstTwo = enabledItems.prefix(2).joined(separator: "、")
            let otherCount = enabledItems.count - 2
            return String(format: NSLocalizedString("%1$@ 和另外 %2$d 个处理项", comment: "%1$@ 和另外 %2$d 个处理项"), firstTwo, otherCount)
        }
    }
    
    var properties: ProcessingProperties {
        ProcessingProperties(resolutionEnabled: resolutionEnabled, frameRateEnabled: frameRateEnabled, videoBitrateEnabled: videoBitrateEnabled, audioBitrateEnabled: audioBitrateEnabled, containerEnabled: containerEnabled, speedEnabled: speedEnabled, subtitleEnabled: subtitleEnabled, exportAudioOnlyEnabled: exportAudioOnlyEnabled, exportVideoOnlyEnabled: exportVideoOnlyEnabled, resolutionWidth: resolutionWidth, resolutionHeight: resolutionHeight, keepAspectRatio: keepAspectRatio, frameRate: frameRate, videoBitrate: videoBitrate, videoEncoder: videoEncoder, audioBitrate: audioBitrate, audioEncoder: audioEncoder, containerFormat: containerFormat, speedPercentage: speedPercentage, subtitleFilePath: subtitleFilePath, subtitlePosition: subtitlePosition, subtitleColor: subtitleColor, subtitleFont: subtitleFont, subtitleFontSize: subtitleFontSize, subtitleOutlineColor: subtitleOutlineColor, subtitleOutlineWidth: subtitleOutlineWidth)
    }
    
    func apply(properties: ProcessingProperties) {
        resolutionEnabled = properties.resolutionEnabled; frameRateEnabled = properties.frameRateEnabled; videoBitrateEnabled = properties.videoBitrateEnabled; audioBitrateEnabled = properties.audioBitrateEnabled; containerEnabled = properties.containerEnabled; speedEnabled = properties.speedEnabled; subtitleEnabled = properties.subtitleEnabled; exportAudioOnlyEnabled = properties.exportAudioOnlyEnabled; exportVideoOnlyEnabled = properties.exportVideoOnlyEnabled; resolutionWidth = properties.resolutionWidth; resolutionHeight = properties.resolutionHeight; keepAspectRatio = properties.keepAspectRatio; frameRate = properties.frameRate; videoBitrate = properties.videoBitrate; videoEncoder = properties.videoEncoder; audioBitrate = properties.audioBitrate; audioEncoder = properties.audioEncoder; containerFormat = properties.containerFormat; speedPercentage = properties.speedPercentage; subtitleFilePath = properties.subtitleFilePath; subtitlePosition = properties.subtitlePosition; subtitleColor = properties.subtitleColor; subtitleFont = properties.subtitleFont; subtitleFontSize = properties.subtitleFontSize; subtitleOutlineColor = properties.subtitleOutlineColor; subtitleOutlineWidth = properties.subtitleOutlineWidth
    }
    
    var adjustedDuration: TimeInterval? {
        guard let originalDuration = duration else { return nil }
        if speedEnabled, let percentage = Double(speedPercentage), percentage > 0 {
            let speedMultiplier = percentage / 100.0
            return originalDuration / speedMultiplier
        }
        return originalDuration
    }
    
    func loadMetadata() {
        // 异步生成缩略图（这部分保持不变）
        DispatchQueue.global().async {
            let image = self.generateThumbnail(for: self.url)
            DispatchQueue.main.async { self.thumbnail = image }
        }

        // 使用 CommandRunner 的 probe 方法获取真实的元数据
        let commandRunner = CommandRunner()
        commandRunner.probe(fileURL: self.url) { [weak self] result in
            guard let self = self else { return }
            
            // 确保所有UI更新都在主线程上进行
            DispatchQueue.main.async {
                switch result {
                case .success(let probeData):
                    // 处理视频流信息
                    if let videoStream = probeData.streams.first(where: { $0.codec_type == "video" }) {
                        let width = videoStream.width ?? 0
                        let height = videoStream.height ?? 0
                        
                        // --- 修正：在这里设置原始尺寸 ---
                        self.originalWidth = width
                        self.originalHeight = height
                        
                        self.resolutionWidth = "\(width)"
                        self.resolutionHeight = "\(height)"
                        
                        let frameRateString = videoStream.avg_frame_rate ?? "0/1"
                        let frameRate = self.calculateFrameRate(from: frameRateString) ?? 0.0
                        self.frameRate = String(format: "%.2f", frameRate)
                        
                        let bitrateKbps = (Int(videoStream.bit_rate ?? "0") ?? 0) / 1000
                        self.videoBitrate = "\(bitrateKbps)"
                        
                        let probedCodecName = videoStream.codec_name ?? "N/A"
                        let codecNameForInfo = probedCodecName.uppercased()

                        // Set default encoder based on probed codec, preferring hardware options
                        switch probedCodecName.lowercased() {
                        case "hevc":
                            self.videoEncoder = "HEVC (硬件)"
                        case "h.264":
                            self.videoEncoder = "H.264 (硬件)"
                        default:
                            // Fallback for other codecs to a sensible default
                            self.videoEncoder = "H.264 (硬件)"
                        }
                        
                        self.videoInfo = String(format: NSLocalizedString("视频: %1$dx%2$d | %3$@ | %4$dKbps | %5$@FPS", comment: "视频详细信息"), width, height, codecNameForInfo, bitrateKbps, String(describing: self.frameRate))
                        
                        
                    } else {
                        self.videoInfo = String(NSLocalizedString("视频: 未找到视频流", comment: "视频: 未找到视频流"))
                        
                    }
                    
                    // 处理音频流信息
                    if let audioStream = probeData.streams.first(where: { $0.codec_type == "audio" }) {
                        let bitrateKbps = (Int(audioStream.bit_rate ?? "0") ?? 0) / 1000
                        self.audioBitrate = "\(bitrateKbps)"
                        
                        let codecName = audioStream.codec_name?.uppercased() ?? "N/A"
                        self.audioEncoder = codecName
                        
                        self.audioInfo = String(format: NSLocalizedString("音频: %1$@ | %2$dKbps", comment: "音频详细信息"), codecName, bitrateKbps)
                    } else {
                        self.audioInfo = String(NSLocalizedString("音频: 未找到音频流", comment: "音频: 未找到音频流"))
                    }

                case .failure(let error):
                    self.videoInfo = String(NSLocalizedString("错误: 无法读取元数据", comment: "错误: 无法读取元数据"))
                    self.audioInfo = error.localizedDescription
                }
            }
        }
    }
    
    /// 辅助方法，用于将 "30000/1001" 这样的字符串转换为 Double
    private func calculateFrameRate(from string: String) -> Double? {
        let components = string.split(separator: "/")
        if components.count == 2, let numerator = Double(components[0]), let denominator = Double(components[1]), denominator != 0 {
            return numerator / denominator
        }
        // 同时处理像 "30" 这样的整数帧率
        return Double(string)
    }
    
    private func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url), imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = false
        do { return NSImage(cgImage: try imageGenerator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil), size: .zero) } catch { print("生成缩略图失败: \(error.localizedDescription)"); return NSImage(systemSymbolName: "film", accessibilityDescription: "thumbnail placeholder") }
    }
    // MARK: - buildCommand

    func buildCommand(outputDirectory: URL) -> String {
        let inputPath = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        let originalFileName = url.deletingPathExtension().lastPathComponent
        let outputExtension = containerEnabled || videoEncoder.contains("Apple ProRes") ? containerFormat.lowercased() : url.pathExtension
        let outputFileName = "\(originalFileName)_converted.\(outputExtension)"
        let outputPath = outputDirectory.appendingPathComponent(outputFileName).path.replacingOccurrences(of: "\"", with: "\\\"")

        var components: [String] = ["-i \"\(inputPath)\""]
        var videoFilters: [String] = []
        var audioFilters: [String] = []
        var Filters: [String] = []
        
        func videoOperations(){
            // --- 视频设置 ---
            let needsVideoReEncoding = resolutionEnabled || frameRateEnabled || videoBitrateEnabled || speedEnabled || subtitleEnabled
            
            if needsVideoReEncoding {
                // 分辨率
                if resolutionEnabled, let w = Int(resolutionWidth), let h = Int(resolutionHeight), w > 0, h > 0 {
                    videoFilters.append("scale=\(w):\(h)")
                }
                // 帧率
                if frameRateEnabled, let fr = Double(frameRate), fr > 0 {
                    components.append("-r \(String(format: "%.2f", fr))")
                }
                // 编码器和比特率
                if videoBitrateEnabled {
                    switch videoEncoder {
                    case "HEVC (硬件)": components.append("-vcodec hevc_videotoolbox -tag:v hvc1")
                    case "H.264 (硬件)": components.append("-vcodec h264_videotoolbox")
                    case "HEVC (软件)", "HEVC": components.append("-vcodec libx265 -tag:v hvc1")
                    case "H.264 (软件)", "H.264": components.append("-vcodec libx264")
                    case "AV1":components.append("-vcodec libsvtav1")
                    case "MPEG-4":components.append("-vcodec mpeg4")
                    case "Apple ProRes(软件)":components.append("-vcodec prores")
                    default: break
                    }
                    if let bitrate = Int(videoBitrate), bitrate > 0 {
                        components.append("-b:v \(bitrate)k")
                    }
                } else {
                    // 如果启用了字幕但没有指定视频比特率，则需要选择一个默认编码器
                    if subtitleEnabled {
                        components.append("-vcodec libx264")
                    }
                }
                
                // 变速
                if speedEnabled, let percentage = Double(speedPercentage), percentage > 0 {
                    let speedMultiplier = percentage / 100.0        // 速度倍率
                    let setptsValue = 1.0 / speedMultiplier        // PTS前的数值
                    videoFilters.append("setpts=\(setptsValue)*PTS")
                    if !exportVideoOnlyEnabled{
                        audioFilters.append("atempo=\(speedMultiplier)")  //只有在不勾选仅导出视频的情况下才会给音频添加变速
                    }
                }
                
                // 字幕
                if subtitleEnabled, !subtitleFilePath.isEmpty {
                    let subtitlePath = subtitleFilePath.replacingOccurrences(of: ":", with: "\\")
                    var styleOptions: [String] = []
                    
                    // 位置
                    styleOptions.append("Alignment=\(mapPositionToAlignment(subtitlePosition))")
                    // 颜色
                    styleOptions.append("PrimaryColour=\(subtitleColor.toFFmpegColorString())")
                    // 字体
                    if !subtitleFont.isEmpty {
                        styleOptions.append("FontName=\(subtitleFont)")
                    }
                    // 字号
                    if let size = Int(subtitleFontSize), size > 0 {
                        styleOptions.append("FontSize=\(size)")
                    }
                    // 描边颜色
                    styleOptions.append("OutlineColour=\(subtitleOutlineColor.toFFmpegColorString())")
                    // 描边宽度
                    if let width = Int(subtitleOutlineWidth), width >= 0 {
                        styleOptions.append("Outline=\(width)")
                    }
                    
                    let forceStyle = styleOptions.joined(separator: ",")
                    videoFilters.append("subtitles=\(subtitlePath):force_style='\(forceStyle)'")
                }

            } else {
                components.append("-c:v copy")
            }
        }

        // --- 音频设置 ---
        if exportAudioOnlyEnabled {//如果仅导出音频
            components.append("-vn") // 无视频
            // 为仅音频导出选择编码器和比特率
            switch audioEncoder {
            case "AAC": components.append("-c:a aac")
            case "Opus": components.append("-c:a libopus")
            case "MP3": components.append("-c:a libmp3lame")
            default: components.append("-c:a aac")
            }
            if let bitrate = Int(audioBitrate), bitrate > 0 {
                components.append("-b:a \(bitrate)k")
            }
        } else if exportVideoOnlyEnabled {//如果仅导出视频
            components.append("-an") // 无音频
            videoOperations()
        } else {//如果视频和音频都导出
            videoOperations()

            // --- 音频设置 (视频+音频模式) ---
            if audioBitrateEnabled {
                switch audioEncoder {
                case "AAC": components.append("-c:a aac")
                case "Opus": components.append("-c:a libopus")
                case "MP3": components.append("-c:a libmp3lame");
                default: break
                }
                if let bitrate = Int(audioBitrate), bitrate > 0 {
                    components.append("-b:a \(bitrate)k")
                }
            }
            
        }
        var mapComponents: [String] = []

        if !videoFilters.isEmpty {
            Filters.append("[0:v]\(videoFilters.joined(separator: ","))[v]")
            mapComponents.append("-map \"[v]\"")
        }
        if !audioFilters.isEmpty {
            Filters.append("[0:a]\(audioFilters.joined(separator: ","))[a]")
            mapComponents.append("-map \"[a]\"")

        }
        if !Filters.isEmpty{
            components.append("-filter_complex \"\(Filters.joined(separator: ";"))\" \(mapComponents.joined(separator: " "))")
        }
        components.append("-y \"\(outputPath)\"")
        let command = components.joined(separator: " ")
        print("Generated FFmpeg Command: \(command)") // Print the command for debugging
        return command
    }

   

    private func mapPositionToAlignment(_ position: String) -> Int {
        switch position {
        case "中上": return 8 // Top center
        case "中下": return 2 // Bottom center
        case "顶部": return 5 // Top left (assuming, as ffmpeg alignment is complex)
        case "底部": return 1 // Bottom left (assuming)
        default: return 2 // Default to bottom center
        }
    }
}

extension Color {
    func toFFmpegColorString() -> String {
        guard let cgColor = self.cgColor, let components = cgColor.components, components.count >= 3 else {
            return "&HFFFFFFFF" // 默认白色
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        let a = components.count > 3 ? Int((1 - components[3]) * 255) : 0 // FFmpeg alpha is 00 (opaque) to FF (transparent)
        
        return String(format: "&H%02X%02X%02X%02X", a, b, g, r)
    }
}

// MARK: - ViewModel
class MainViewModel: ObservableObject {
    @Published var videoItems: [VideoItem] = []
    @Published var outputLocation: URL? {
        didSet {
            guard let url = outputLocation else {
                UserDefaults.standard.removeObject(forKey: "outputLocationBookmark")
                return
            }
            do {
                // 将 URL 转换为带安全范围的书签数据并保存
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "outputLocationBookmark")
            } catch {
                print("错误：保存输出路径书签失败: \(error.localizedDescription)")
            }
        }
    }
    @Published var selection = Set<VideoItem.ID>()
    private var propertiesClipboard: ProcessingProperties?

    init() {
        // 从 UserDefaults 读取书签数据并解析为可用的 URL
        guard let bookmarkData = UserDefaults.standard.data(forKey: "outputLocationBookmark") else {
            return
        }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                // 如果书签过期，理想情况下应提示用户重新选择，但此处我们暂时忽略
                print("警告：输出路径书签已过期。")
            }
            self.outputLocation = url
        } catch {
            print("错误：解析输出路径书签失败: \(error.localizedDescription)")
        }
    }
    func selectItem(withID id: VideoItem.ID, isCommandPressed: Bool) { if isCommandPressed { if selection.contains(id) { selection.remove(id) } else { selection.insert(id) } } else { selection = [id] } }
    func selectAll() { selection = Set(videoItems.map { $0.id }) }
    func deselectAll() { selection.removeAll() }
    func copyProperties(from item: VideoItem) { propertiesClipboard = item.properties }
    func pasteProperties() { guard let clipboard = propertiesClipboard, !selection.isEmpty else { return }; videoItems.filter { selection.contains($0.id) }.forEach { $0.apply(properties: clipboard) } }
    func deleteSelection() { guard !selection.isEmpty else { return }; videoItems.removeAll { selection.contains($0.id) }; selection.removeAll() }
}

// MARK: - Views
struct VideoItemRowView: View {
    @ObservedObject var item: VideoItem
    var isSelected: Bool
    var onConfigure: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack{
                VStack(alignment: .leading,spacing: 15){
                    HStack(spacing: 15) { 
                        ZStack {
                            if let t = item.thumbnail {
                                Image(nsImage: t)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                                    .frame(width: 110, height: 68)
                                    .cornerRadius(4)
                            } else {
                                Rectangle()
                                    .fill(Color(nsColor: .windowBackgroundColor))
                                    .frame(width: 120, height: 67.5)
                                    .cornerRadius(4)
                                    .overlay(ProgressView())
                            }
                        }
                        VStack(alignment: .leading, spacing: 5) { Text(item.url.lastPathComponent).font(.system(size: 16, weight: .bold)); Text(item.videoInfo).font(.system(size: 12)).foregroundColor(.secondary); Text(item.audioInfo).font(.system(size: 12)).foregroundColor(.secondary) }
                        Spacer()
                    }
                    
                    Text(item.processingSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary);
                }
                Button("处理项...") { onConfigure() }

                
            }.padding(12)
                
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 8)
        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        
    }
}

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var processingViewModel = ProcessingViewModel()
    
    enum ActiveSheet: Identifiable {
        case processing, configure(VideoItem)
        var id: String { switch self { case .processing: return "p"; case .configure(let i): return i.id.uuidString } }
    }
    @State private var activeSheet: ActiveSheet?

    // --- Pre-initialized File Pickers for Performance ---
    private let inputFilePicker: NSOpenPanel
    private let outputDirectoryPicker: NSOpenPanel

    init() {
        // Configure input file picker
        let inputPicker = NSOpenPanel()
        inputPicker.canChooseFiles = true
        inputPicker.allowsMultipleSelection = true
        inputPicker.allowedContentTypes = [UTType.movie]
        self.inputFilePicker = inputPicker

        // Configure output directory picker
        let outputPicker = NSOpenPanel()
        outputPicker.canChooseFiles = false
        outputPicker.canChooseDirectories = true
        outputPicker.prompt = "选择"
        self.outputDirectoryPicker = outputPicker
    }

    // MARK: - Body and Subviews
    var body: some View {
        VStack(spacing: 0) {
            shortcutButtons
            videoListView
            bottomBar
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers -> Bool in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            if !viewModel.videoItems.contains(where: { $0.url == url }) {
                                let newItem = VideoItem(url: url)
                                newItem.loadMetadata()
                                viewModel.videoItems.append(newItem)
                            }
                        }
                    }
                }
            }
            return true
        }
        .frame(minWidth: 600, idealWidth: 750, minHeight: 400, idealHeight: 550)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .processing:
                ProcessingView(viewModel: processingViewModel) { activeSheet = nil }
            case .configure(let item):
                if let index = viewModel.videoItems.firstIndex(where: { $0.id == item.id }) {
                    ProcessSettingView(item: viewModel.videoItems[index])
                } else {
                    Text("错误：未找到视频条目")
                }
            }
        }
    }
    
    private var shortcutButtons: some View {
        HStack {
            Button("Copy") { if let item = viewModel.videoItems.first(where: { viewModel.selection.contains($0.id) }) { viewModel.copyProperties(from: item) } }.keyboardShortcut("c", modifiers: .command)
            Button("Paste") { viewModel.pasteProperties() }.keyboardShortcut("v", modifiers: .command)
            Button("Select All") { viewModel.selectAll() }.keyboardShortcut("a", modifiers: .command)
            Button("Delete") { viewModel.deleteSelection() }.keyboardShortcut(.delete, modifiers: [])
        }.hidden().frame(height: 0)
    }
    
    private var videoListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.videoItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.videoItems) { item in
                        videoRow(for: item)
                    }
                }
                Button(action: showInputFilePicker) { HStack { Image(systemName: "plus"); Text("添加条目") }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(14) }.buttonStyle(PlainButtonStyle())
            }.padding()
        }
    }
    
        
    private func videoRow(for item: VideoItem) -> some View {
        VideoItemRowView(item: item, isSelected: viewModel.selection.contains(item.id)) { activeSheet = .configure(item) }
            .onTapGesture {
                // 修正：从 NSApp.currentEvent 获取当前的组合键状态
                let isCommandPressed = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
                viewModel.selectItem(withID: item.id, isCommandPressed: isCommandPressed)
            }
            .contextMenu {
                Button("拷贝属性") { viewModel.copyProperties(from: item) }
                Button("粘贴属性") { viewModel.pasteProperties() }.disabled(viewModel.selection.isEmpty)
                Divider()
                Button("删除", role: .destructive) { viewModel.deleteSelection() }
            }
    }
    
    private var bottomBar: some View {
        HStack {
            Text("输出位置: \(viewModel.outputLocation?.path(percentEncoded: false) ?? "未设置")").font(.callout).lineLimit(1).truncationMode(.middle)
            Button("更改") { showOutputDirectoryPicker() }
            Spacer()
            Button("全部开始") {
                guard let outputDir = viewModel.outputLocation else { return }
                processingViewModel.start(items: viewModel.videoItems, outputDirectory: outputDir)
                activeSheet = .processing
            }.disabled(viewModel.videoItems.isEmpty).keyboardShortcut(.defaultAction)
        }.padding().background(.bar)
    }
    
    private var emptyStateView: some View {
        VStack { Image(systemName: "film.stack").font(.system(size: 40)).padding(.bottom, 10); Text("尚未添加视频").font(.title3); Text("点击“添加条目”或直接拖拽视频文件到这里。").foregroundColor(.secondary) }.padding(.vertical, 50)
    }

    private func showInputFilePicker() {
        inputFilePicker.begin { response in
            if response == .OK {
                for url in self.inputFilePicker.urls {
                    if !viewModel.videoItems.contains(where: { $0.url == url }) {
                        let newItem = VideoItem(url: url)
                        newItem.loadMetadata()
                        viewModel.videoItems.append(newItem)
                    }
                }
            }
        }
    }

    private func showOutputDirectoryPicker() {
        outputDirectoryPicker.begin { response in
            if response == .OK, let url = self.outputDirectoryPicker.url {
                viewModel.outputLocation = url
            }
        }
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
