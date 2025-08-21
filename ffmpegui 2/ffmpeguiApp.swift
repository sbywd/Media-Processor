//
//  ffmpeguiApp.swift
//  ffmpegui
//
//  Created by 邵泊源 on 2025/6/26.
//

import SwiftUI // 导入 SwiftUI 框架，用于构建用户界面

/// `ffmpeguiApp` 是应用程序的入口点。
/// 符合 `App` 协议，定义了应用程序的结构和行为。
@main // @main 属性表示这是应用程序的入口点
struct ffmpeguiApp: App {
    @StateObject private var presetViewModel = PresetViewModel()
    
    /// 应用程序的主体内容。
    /// 定义了应用程序的场景（Scene）结构。
    var body: some Scene {
        /// `WindowGroup` 定义了一个窗口组，其中包含应用程序的主要内容视图。
        WindowGroup {
            MainView() // 设置 `ContentView` 为应用程序的根视图
                .environmentObject(presetViewModel)
                
        }
        /// `.windowStyle(HiddenTitleBarWindowStyle())` 设置窗口样式为隐藏标题栏。
        /// 这使得应用程序窗口看起来更简洁，通常用于自定义标题栏或无边框窗口。
        .windowStyle(HiddenTitleBarWindowStyle())
        
        Settings {
            SettingsView()
                .environmentObject(presetViewModel)
        }
    }
}
