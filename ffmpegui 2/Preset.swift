
import SwiftUI

// A wrapper to make Color Codable
struct CodableColor: Codable, Hashable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(color: Color) {
        let uiColor = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct Preset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String

    // Processing settings from ProcessingProperties, minus file-specific ones
    var resolutionEnabled: Bool
    var frameRateEnabled: Bool
    var videoBitrateEnabled: Bool
    var audioBitrateEnabled: Bool
    var containerEnabled: Bool
    var speedEnabled: Bool
    var subtitleEnabled: Bool
    var exportAudioOnlyEnabled: Bool
    var exportVideoOnlyEnabled: Bool

    var resolutionWidth: String
    var resolutionHeight: String
    var keepAspectRatio: Bool
    var frameRate: String
    var videoBitrate: String
    var videoEncoder: String
    var audioBitrate: String
    var audioEncoder: String
    var containerFormat: String

    var speedPercentage: String

    // Subtitle styling
    var subtitlePosition: String
    var subtitleColor: CodableColor
    var subtitleFont: String
    var subtitleFontSize: String
    var subtitleOutlineColor: CodableColor
    var subtitleOutlineWidth: String
    
    // Add a static default preset
    static func newDefault() -> Preset {
        Preset(
            name: NSLocalizedString("新预设", comment: "新预设"),
            resolutionEnabled: false,
            frameRateEnabled: false,
            videoBitrateEnabled: false,
            audioBitrateEnabled: false,
            containerEnabled: false,
            speedEnabled: false,
            subtitleEnabled: false,
            exportAudioOnlyEnabled: false,
            exportVideoOnlyEnabled: false,
            resolutionWidth: "1920",
            resolutionHeight: "1080",
            keepAspectRatio: true,
            frameRate: "60",
            videoBitrate: "1600",
            videoEncoder: "HEVC (硬件)",
            audioBitrate: "32",
            audioEncoder: "AAC",
            containerFormat: "MP4",
            speedPercentage: "100",
            subtitlePosition: "中下",
            subtitleColor: CodableColor(color: .white),
            subtitleFont: "PingFang SC",
            subtitleFontSize: "24",
            subtitleOutlineColor: CodableColor(color: .black),
            subtitleOutlineWidth: "2"
        )
    }

    func toProcessingProperties() -> ProcessingProperties {
        return ProcessingProperties(
            resolutionEnabled: resolutionEnabled,
            frameRateEnabled: frameRateEnabled,
            videoBitrateEnabled: videoBitrateEnabled,
            audioBitrateEnabled: audioBitrateEnabled,
            containerEnabled: containerEnabled,
            speedEnabled: speedEnabled,
            subtitleEnabled: subtitleEnabled,
            exportAudioOnlyEnabled: exportAudioOnlyEnabled,
            exportVideoOnlyEnabled: exportVideoOnlyEnabled,
            resolutionWidth: resolutionWidth,
            resolutionHeight: resolutionHeight,
            keepAspectRatio: keepAspectRatio,
            frameRate: frameRate,
            videoBitrate: videoBitrate,
            videoEncoder: videoEncoder,
            audioBitrate: audioBitrate,
            audioEncoder: audioEncoder,
            containerFormat: containerFormat,
            speedPercentage: speedPercentage,
            subtitleFilePath: "", // Not part of a preset
            subtitlePosition: subtitlePosition,
            subtitleColor: subtitleColor.color,
            subtitleFont: subtitleFont,
            subtitleFontSize: subtitleFontSize,
            subtitleOutlineColor: subtitleOutlineColor.color,
            subtitleOutlineWidth: subtitleOutlineWidth
        )
    }

    mutating func update(from properties: ProcessingProperties) {
        self.resolutionEnabled = properties.resolutionEnabled
        self.frameRateEnabled = properties.frameRateEnabled
        self.videoBitrateEnabled = properties.videoBitrateEnabled
        self.audioBitrateEnabled = properties.audioBitrateEnabled
        self.containerEnabled = properties.containerEnabled
        self.speedEnabled = properties.speedEnabled
        self.subtitleEnabled = properties.subtitleEnabled
        self.exportAudioOnlyEnabled = properties.exportAudioOnlyEnabled
        self.exportVideoOnlyEnabled = properties.exportVideoOnlyEnabled
        self.resolutionWidth = properties.resolutionWidth
        self.resolutionHeight = properties.resolutionHeight
        self.keepAspectRatio = properties.keepAspectRatio
        self.frameRate = properties.frameRate
        self.videoBitrate = properties.videoBitrate
        self.videoEncoder = properties.videoEncoder
        self.audioBitrate = properties.audioBitrate
        self.audioEncoder = properties.audioEncoder
        self.containerFormat = properties.containerFormat
        self.speedPercentage = properties.speedPercentage
        // subtitleFilePath is ignored
        self.subtitlePosition = properties.subtitlePosition
        self.subtitleColor = CodableColor(color: properties.subtitleColor)
        self.subtitleFont = properties.subtitleFont
        self.subtitleFontSize = properties.subtitleFontSize
        self.subtitleOutlineColor = CodableColor(color: properties.subtitleOutlineColor)
        self.subtitleOutlineWidth = properties.subtitleOutlineWidth
    }
}
