import SwiftUI

struct ProcessingView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    var onDone: () -> Void // 用于关闭视图的闭包

    var body: some View {
        VStack(spacing: 24) {
            Text(viewModel.isProcessing ? "正在处理..." : "处理完成")
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
                Button("取消") {
                    viewModel.cancelProcessing()
                }
                .keyboardShortcut(.cancelAction)
            } else {
                Button("完成") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical)
        .frame(minWidth: 480, idealWidth: 500, minHeight: 280, idealHeight: 300)
        .onChange(of: viewModel.isProcessing) { isProcessing in
            // 当处理完成且未被取消时，延迟一段时间自动关闭窗口
            if !isProcessing && viewModel.currentItemName != "已取消" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onDone()
                }
            }
        }
    }
}

struct ProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ProcessingViewModel()
        vm.isProcessing = true
        vm.currentItemName = "正在处理: My_Awesome_Movie_File_Name_Is_Very_Long.mp4"
        vm.currentItemProgress = 0.65
        vm.currentItemProgressText = "65%"
        vm.overallProgress = 0.33
        vm.overallProgressText = "整体进度: (2/6)"
        
        return ProcessingView(viewModel: vm, onDone: {})
    }
}
