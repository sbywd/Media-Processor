import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - 数据结构和枚举

/// `ProbedFileInfo` 结构体用于存储探测到的文件信息。
/// 包含视频和音频的详细信息字符串。
struct ProbedFileInfo {
    var videoInfo: String? = nil
    var audioInfo: String? = nil
}

/// `EncodingMode` 枚举定义了视频编码的模式。
/// 包括软件编码和硬件编码两种选项，并提供对应的中文描述。
enum EncodingMode: String, CaseIterable, Identifiable {
    case software = "软件编码器(兼容性更好)"
    case hardware = "硬件编码器(更快)"
    /// `id` 属性用于 `Identifiable` 协议，使其可以在 `ForEach` 中使用。
    var id: String { self.rawValue }
}

enum SubtitleType: String, CaseIterable, Identifiable {
    case hardsubtitle = "硬字幕"
    case softsubtitle = "软字幕"
    /// `id` 属性用于 `Identifiable` 协议，使其可以在 `ForEach` 中使用。
    var id: String { self.rawValue }
}

/// `ColorSpace` 枚举定义了视频色彩空间的选项。
/// 包含常见的色彩空间，并提供对应的中文描述。
enum ColorSpace: String, CaseIterable, Identifiable {
    case rec709 = "Rec.709"
    case rec2020 = "Rec.2020"
    case bt2100pq = "BT.2100 PQ"
    case bt2100hlg = "BT.2100 HLG"
    case srgb = "sRGB"
    
    /// `id` 属性用于 `Identifiable` 协议，使其可以在 `ForEach` 中使用。
    var id: String { self.rawValue }
    
    /// FFmpeg参数映射
    var ffmpegParams: [(String, String)] {
        switch self {
        case .rec709:
            return [("color_primaries", "bt709"), ("color_trc", "bt709"), ("colorspace", "bt709")]
        case .rec2020:
            return [("color_primaries", "bt2020"), ("color_trc", "bt2020-10"), ("colorspace", "bt2020nc")]
        case .bt2100pq:
            return [("color_primaries", "bt2020"), ("color_trc", "smpte2084"), ("colorspace", "bt2020nc")]
        case .bt2100hlg:
            return [("color_primaries", "bt2020"), ("color_trc", "arib-std-b67"), ("colorspace", "bt2020nc")]
        case .srgb:
            return [("color_primaries", "bt709"), ("color_trc", "iec61966-2-1"), ("colorspace", "bt709")]
        }
    }
}

// MARK: - 颜色转换扩展
extension Color {
    /// 将 SwiftUI `Color` 转换为 FFmpeg 所需的 `AABBGGRR` 格式的十六进制字符串。
    /// FFmpeg 的 ASS 颜色格式为 `&HAABBGGRR`，其中 AA 是 Alpha，BB 是 Blue，GG 是 Green，RR 是 Red。
    func toAABBGGRRHex() -> String {
        let nsColor = NSColor(self) // 将 SwiftUI Color 转换为 NSColor
        
        // 获取 NSColor 的 RGBA 分量
        guard let convertedColor = nsColor.usingColorSpace(.deviceRGB) else {
            return "00000000" // 无法转换时返回默认值
        }
        
        let red = Int(convertedColor.redComponent * 255)
        let green = Int(convertedColor.greenComponent * 255)
        let blue = Int(convertedColor.blueComponent * 255)
        let alpha = Int(convertedColor.alphaComponent * 255)
        
        // 格式化为 BBGGRR 字符串 (FFmpeg ASS 颜色格式为 &HBBGGRR)
        return String(format: "%02X%02X%02X", blue, green, red)
    }
    
    /// 从十六进制字符串初始化 SwiftUI `Color`。
    /// 支持 `RRGGBB` 和 `AARRGGBB` 格式。
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            
        } else if length == 8 {
            a = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x000000FF) / 255.0
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - 视频信息显示条目
/// `FileDetailView` 结构体用于显示输入视频文件的详细信息，包括缩略图、文件名、视频和音频信息。
struct FileDetailView: View {
    let url: URL // 输入文件的URL。
    let thumbnail: NSImage? // 文件的缩略图。
    let info: ProbedFileInfo // 探测到的文件信息。
    
    /// `FileDetailView` 的视图内容。
    var body: some View {
        HStack {
            /// 缩略图显示区域。
            HStack(spacing: 16) {
                /// 如果有缩略图，则显示图像并设置其大小和内容模式。
                if let nsImage = thumbnail {
                    Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
                } else {
                    /// 如果没有缩略图，则显示一个灰色矩形并叠加一个进度指示器。
                    Rectangle().fill(Color.gray.opacity(0.1)).overlay(ProgressView())
                }
            }
            .frame(width: 120, height: 67.5) // 设置缩略图区域的固定大小。
            .cornerRadius(4) // 设置圆角。
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5), lineWidth: 1)) // 添加边框。
            
            /// 文件信息显示区域。
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(.headline).lineLimit(1) // 显示文件名，设置字体和行数限制。
                Text("视频: \(info.videoInfo ?? "正在获取...")").font(.subheadline).foregroundColor(.secondary) // 显示视频信息，如果为空则显示“正在获取...”。
                Text("音频: \(info.audioInfo ?? "正在获取...")").font(.subheadline).foregroundColor(.secondary) // 显示音频信息，如果为空则显示“正在获取...”。
            }
        }
    }
}

/// `URL` 扩展，添加生成视频缩略图的功能。
extension URL {
    /// 生成视频文件的缩略图。
    /// - Returns: 视频第一帧的 `NSImage`，如果生成失败则返回 `nil`。
    func thumbnail() -> NSImage? {
        let asset = AVAsset(url: self) // 根据URL创建AVAsset。
        let generator = AVAssetImageGenerator(asset: asset) // 创建AVAssetImageGenerator。
        generator.appliesPreferredTrackTransform = true // 应用首选轨道变换，确保图像方向正确。
        let time = CMTime(seconds: 0.0, preferredTimescale: 600) // 设置生成缩略图的时间点为0秒。
        do {
            let imageRef = try generator.copyCGImage(at: time, actualTime: nil) // 尝试生成CGImage。
            return NSImage(cgImage: imageRef, size: .zero) // 将CGImage转换为NSImage并返回。
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)") // 打印生成缩略图的错误。
            return nil // 返回nil表示生成失败。
        }
    }
}
