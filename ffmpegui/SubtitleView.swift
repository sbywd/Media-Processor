//
//  SubtitleView.swift
//  ffmpegui
//
//  Created by 邵泊源 on 2025/7/2.
//

import SwiftUI
import AppKit // Import AppKit for NSFont and NSFontManager
import CoreText // Import CoreText for localized font names

// MARK: - 主视图

/// `SubtitleView` 结构体是应用程序中负责字幕设置的视图。
/// 它允许用户选择字幕文件，并配置字幕的字体、大小、颜色、对齐方式等参数。
struct SubtitleView: View {
    // MARK: 状态变量 (现在通过Binding从ContentView获取)
    @Binding var subtitletype: SubtitleType
    @Binding var fontname: String
    @Binding var fontsize: String
    @Binding var alignment: String
    @Binding var primaryColor: Color
    @Binding var outlineColor: Color
    @Binding var backColor: Color
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var isStrikeout: Bool
    @Binding var outlineWidth: String
    @Binding var shadowDepth: String
    @Binding var borderStyle: String
    
    @Binding var inputSubtitleFile: URL?
    
    /// 边框样式选项列表。
    let borderStyleOptions = ["1 (边框+阴影)", "3 (纯色背景)"]
    /// 对齐方式选项列表。
    let alignmentOptions = ["1 (左对齐)", "2 (居中)", "3 (右对齐)", "5 (顶部左对齐)", "6 (顶部居中)", "7 (顶部右对齐)", "9 (中间左对齐)", "10 (中间居中)", "11 (中间右对齐)"]
    
    @State private var fontFamilies: [String] = [] // State to hold font family names
    
    private func showInputSubtitleFilePicker() {
        let openPanel = NSOpenPanel() // Creates a file open panel.
        openPanel.canChooseFiles = true // Allows selecting files.
        openPanel.allowsMultipleSelection = false // Does not allow multiple selection.
        openPanel.canChooseDirectories = false // Does not allow selecting directories.
        /// Begins displaying the panel and processes the result after user selection.
        openPanel.begin { response in
            /// If user clicks OK and selects a file, update `inputFile`.
            if response == .OK, let url = openPanel.url { self.inputSubtitleFile = url }
        }
    }

    // MARK: 视图主体
    
    /// `SubtitleView` 的视图内容。
    var body: some View {
        /// 垂直堆栈布局，内容左对齐，间距为 16。
        VStack(alignment: .leading, spacing: 16) {
            /// 字幕类型选择器。
            Picker("字幕类型", selection: $subtitletype) {
                /// 遍历所有 `SubtitleType` 枚举值，为每个模式创建一个文本标签。
                ForEach(SubtitleType.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented) // 设置选择器样式为分段控制。
            .padding(.bottom, 8) // 添加底部内边距。

            /// 字幕参数表单视图。
            SubtitleForm(
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
                inputSubtitleFile: $inputSubtitleFile,
                borderStyleOptions: borderStyleOptions,
                alignmentOptions: alignmentOptions,
                fontFamilies: fontFamilies, // Pass fontFamilies to SubtitleForm
                showInputSubtitleFilePicker: showInputSubtitleFilePicker
            )
        }
        .padding() // 为整个视图添加内边距。
        .onAppear {
            // Populate fontFamilies when the view appears
            self.fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
        }
    }
}

// MARK: - 表单子视图
/// `SubtitleForm` 结构体定义了字幕参数的表单视图。
/// 它使用 `@Binding` 来与父视图的状态变量进行双向绑定。
private struct SubtitleForm: View {
    // MARK: Bindings
    @Binding var subtitletype: SubtitleType
    @Binding var fontname: String
    @Binding var fontsize: String
    @Binding var alignment: String
    @Binding var primaryColor: Color
    @Binding var outlineColor: Color
    @Binding var backColor: Color
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var isStrikeout: Bool
    @Binding var outlineWidth: String
    @Binding var shadowDepth: String
    @Binding var borderStyle: String
    @Binding var inputSubtitleFile: URL?
    
    // MARK: Properties
    let borderStyleOptions: [String]
    let alignmentOptions: [String]
    let fontFamilies: [String]
    let showInputSubtitleFilePicker: () -> Void

    /// A helper function to get the localized name of a font family.
    /// It uses CoreText to find the name that best matches the user's system language.
    /// - Parameter familyName: The system name of the font family (e.g., "PingFang SC").
    /// - Returns: The localized display name (e.g., "苹方-简" on a Chinese system).
    private func localizedFontName(for familyName: String) -> String {
        let attributes = [kCTFontFamilyNameAttribute: familyName] as CFDictionary
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes)
        
        // CTFontDescriptorCopyLocalizedAttribute returns CFTypeRef?, which can be a CFString.
        // We safely cast it to a Swift String.
        if let localized = CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontFamilyNameAttribute, nil) {
            if let localizedString = localized as? String {
                return localizedString
            }
        }
        
        // Fallback to the original name if localization fails.
        return familyName
    }
    
    /// `SubtitleForm` 的视图内容。
    var body: some View {
        /// `Grid` 布局，内容左对齐，水平间距20，垂直间距12。
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
             
            VStack(alignment: .leading){
                Button("选择输入文件") { showInputSubtitleFilePicker() }
                if let inputFile = inputSubtitleFile {
                    Text(inputFile.path)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("未选择字幕文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
             
            /// 字体设置行。
            GridRow(alignment: .firstTextBaseline) {
                HStack {
                    Text("字体名称:")
                    Picker("", selection: $fontname) {
                        ForEach(fontFamilies, id: \.self) { familyName in
                            // Call the helper function to get the localized font name for display.
                            Text(localizedFontName(for: familyName))
                                .font(.custom(familyName, size: 14)) // Preview the font
                                .tag(familyName) // The tag must be the original, non-localized name
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                HStack { Text("字体大小:"); TextField("例如: 18", text: $fontsize).frame(width: 60).multilineTextAlignment(.trailing) }
                HStack { Text("对齐方式:"); Picker("", selection: $alignment) { ForEach(alignmentOptions, id: \.self) { Text($0) } }.labelsHidden().frame(width: 180) }
            }
             
            /// 颜色设置行。
            GridRow(alignment: .firstTextBaseline) {
                HStack { Text("主要颜色:"); ColorPicker("", selection: $primaryColor).labelsHidden().frame(width: 100) }
                HStack { Text("轮廓颜色:"); ColorPicker("", selection: $outlineColor).labelsHidden().frame(width: 100) }
                HStack { Text("阴影颜色:"); ColorPicker("", selection: $backColor).labelsHidden().frame(width: 100) }
            }
             
            /// 样式开关行。
            GridRow(alignment: .firstTextBaseline) {
                HStack(spacing: 20) {
                    Toggle(isOn: $isBold) { Text("粗体") }
                    Toggle(isOn: $isItalic) { Text("斜体") }
                    Toggle(isOn: $isUnderline) { Text("下划线") }
                    Toggle(isOn: $isStrikeout) { Text("删除线") }
                }
            }
             
            /// 轮廓/阴影/边框样式行。
            GridRow(alignment: .firstTextBaseline) {
                HStack { Text("轮廓宽度:"); TextField("例如: 1", text: $outlineWidth).frame(width: 50).multilineTextAlignment(.trailing) }
                HStack { Text("阴影深度:"); TextField("例如: 0", text: $shadowDepth).frame(width: 50).multilineTextAlignment(.trailing) }
                HStack { Text("边框样式:"); Picker("", selection: $borderStyle) { ForEach(borderStyleOptions, id: \.self) { Text($0) } }.labelsHidden().frame(width: 180) }
            }
             
        }
        .disabled(subtitletype == .softsubtitle) // 如果是软字幕，则禁用所有字幕样式设置
    }
}

/// `SubtitleView_Previews` 结构体用于 SwiftUI 预览。
struct SubtitleView_Previews: PreviewProvider {

    // CORRECT: The helper struct is declared here, outside the `previews` property.
    /// A helper view to provide state and bindings for the preview.
    struct PreviewWrapper: View {
        @State var subtitletype: SubtitleType = .hardsubtitle
        @State var fontname: String = "PingFang SC"
        @State var fontsize: String = "18"
        @State var alignment: String = "2"
        @State var primaryColor: Color = .red
        @State var outlineColor: Color = .black
        @State var backColor: Color = .clear
        @State var isBold: Bool = false
        @State var isItalic: Bool = false
        @State var isUnderline: Bool = false
        @State var isStrikeout: Bool = false
        @State var outlineWidth: String = "1"
        @State var shadowDepth: String = "0"
        @State var borderStyle: String = "1 (边框+阴影)"
        @State var inputSubtitleFile: URL? = nil
        
        var body: some View {
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
        }
    }
    
    /// 预览内容。
    static var previews: some View {
        // Now, we just create an instance of the PreviewWrapper.
        PreviewWrapper()
            .frame(width: 850)
    }
}
