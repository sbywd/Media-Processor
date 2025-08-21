import SwiftUI

struct ProcessingView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    var onDone: () -> Void // 用于关闭视图的闭包

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.hasFailed {
                // MARK: - 失败状态视图
                Text(NSLocalizedString("任务失败！", comment: "任务失败！"))
                    .font(.largeTitle)
                    .foregroundColor(.red)
                    .padding(.top)
                
                // 显示错误信息的可滚动、可选择文本区域
                TextEditor(text: .constant(viewModel.errorMessage))
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray.opacity(0.2), width: 1)
                    .cornerRadius(6)
                    .padding(.horizontal, 4)
                    .shadow(radius: 1)
                
                Spacer()
                
                // 底部按钮栏
                HStack {
                    Button(NSLocalizedString("拷贝报错信息", comment: "拷贝报错信息")) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(viewModel.errorMessage, forType: .string)
                    }
                    
                    Spacer()
                    
                    Button(NSLocalizedString("完成", comment: "完成")) {
                        onDone()
                    }
                    .keyboardShortcut(.defaultAction)
                }

            } else {
                // MARK: - 正常处理状态视图
                Text(viewModel.isProcessing ? NSLocalizedString("正在处理...", comment: "正在处理...") : NSLocalizedString("处理完成", comment: "处理完成"))
                    .font(.largeTitle)
                    .padding(.top)

                // 当前项目进度
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.currentItemName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 12) {
                        ProgressView(value: viewModel.currentItemProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(viewModel.currentItemProgress * 100))%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                // 整体进度
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.overallProgressText)
                        .font(.headline)

                    HStack(spacing: 12) {
                        ProgressView(value: viewModel.overallProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    if viewModel.isProcessing && !viewModel.estimatedTimeRemainingString.isEmpty {
                        Text(viewModel.estimatedTimeRemainingString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                if viewModel.isProcessing {
                    Button(NSLocalizedString("取消", comment: "取消")) {
                        viewModel.cancelProcessing()
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button(NSLocalizedString("完成", comment: "完成")) {
                        onDone()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical)
        .frame(minWidth: 480, idealWidth: 500, minHeight: 320, idealHeight: 350)
        .onChange(of: viewModel.isProcessing) { isProcessing in
            // 当处理完成、未被取消且未失败时，延迟一段时间自动关闭窗口
            if !isProcessing && !viewModel.hasFailed && viewModel.currentItemName != NSLocalizedString("已取消", comment: "已取消") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onDone()
                }
            }
        }
    }
}

struct ProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        // 正常处理预览
        let normalVM = ProcessingViewModel()
        normalVM.isProcessing = true
        normalVM.currentItemName = "正在处理: My_Awesome_Movie_File_Name_Is_Very_Long.mp4"
        normalVM.currentItemProgress = 0.65
        normalVM.overallProgress = 0.33
        normalVM.overallProgressText = "整体进度: (2/6)"
        normalVM.estimatedTimeRemainingString = "剩余时间: 约 5 分 22 秒"
        
        // 失败状态预览
        let failedVM = ProcessingViewModel()
        failedVM.hasFailed = true
        failedVM.errorMessage = "ffmpeg version 6.0 Copyright (c) 2000-2023 the FFmpeg developers\n...\n[libx264 @ 0x13c00b800] Error initializing output stream: Invalid argument\nError opening output file output.mp4.\nError opening output files: Invalid argument"

        return Group {
            ProcessingView(viewModel: normalVM, onDone: {})
                .previewDisplayName("正常处理")
            
            ProcessingView(viewModel: failedVM, onDone: {})
                .previewDisplayName("任务失败")
        }
    }
}
