import Foundation
import SwiftUI
import Combine

class ProcessingViewModel: ObservableObject, Identifiable {
    // 整体进度
    @Published var overallProgress: Double = 0.0
    @Published var overallProgressText: String = "整体进度: (0/0)"
    
    // 当前项目进度
    @Published var currentItemProgress: Double = 0.0
    @Published var currentItemProgressText: String = "0%"
    @Published var currentItemName: String = "准备中..."
    
    // 预计剩余时间
    @Published var estimatedTimeRemainingString: String = ""
    
    // 状态
    @Published var isProcessing: Bool = false
    
    private var commandRunner = CommandRunner()
    private var videoItems: [VideoItem] = []
    private var outputDirectory: URL?
    private var currentIndex: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // --- 新增：用于计算平均速度 ETR 的属性 ---
    private var batchStartTime: Date?
    private var totalBatchDuration: TimeInterval = 0

    init() {
        // 监听 CommandRunner 的进度
        commandRunner.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self, self.isProcessing, let progress = progress else { return }
                
                self.currentItemProgress = progress.fractionCompleted
                self.currentItemProgressText = "\(progress.percentage)%"
                
                if !self.videoItems.isEmpty {
                    let completedItems = Double(self.currentIndex)
                    let totalItems = Double(self.videoItems.count)
                    self.overallProgress = (completedItems + self.currentItemProgress) / totalItems
                }
                
                // ETR 计算 (新算法)
                self.updateEstimatedTimeRemaining(with: progress)
            }
            .store(in: &cancellables)

        // 监听 CommandRunner 的运行状态以链接命令
        commandRunner.$isRunning
            .receive(on: DispatchQueue.main)
            .filter { !$0 && self.isProcessing } 
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processNextItem()
            }
            .store(in: &cancellables)
    }

    func start(items: [VideoItem], outputDirectory: URL) {
        self.videoItems = items
        self.outputDirectory = outputDirectory
        self.currentIndex = -1
        self.isProcessing = true
        
        // 重置状态
        self.currentItemProgress = 0.0
        self.currentItemProgressText = "0%"
        self.overallProgress = 0.0
        self.overallProgressText = "整体进度: (0/\(items.count))"
        self.currentItemName = "正在准备..."
        self.estimatedTimeRemainingString = "剩余时间: 正在计算..."
        
        // 1. 在开始处理前，先探测所有文件的时长
        let group = DispatchGroup()
        for item in items {
            group.enter()
            commandRunner.probe(fileURL: item.url) { result in
                switch result {
                case .success(let probeResult):
                    let stream = probeResult.streams.first { $0.codec_type == "video" } ?? probeResult.streams.first
                    item.duration = Double(stream?.duration ?? "0")
                case .failure(let error):
                    print("探测失败 \(item.url.lastPathComponent): \(error.localizedDescription)")
                    item.duration = 0
                }
                group.leave()
            }
        }
        
        // 2. 所有文件探测完毕后，再开始处理队列
        group.notify(queue: .main) {
            // --- 为新 ETR 算法做准备 ---
            self.totalBatchDuration = self.videoItems.reduce(0) { $0 + ($1.duration ?? 0) }
            self.batchStartTime = Date()
            
            // 在开始处理前，获取对输出目录的访问权限
            guard self.outputDirectory?.startAccessingSecurityScopedResource() ?? false else {
                print("错误：无法获取对输出目录的访问权限。")
                // 在这里可以设置一个错误状态并告知用户
                self.finishProcessing(cancelled: true) // 以取消状态结束
                return
            }
            
            self.processNextItem()
        }
    }

    private func processNextItem() {
        currentIndex += 1
        
        if !videoItems.isEmpty {
            overallProgress = Double(currentIndex) / Double(videoItems.count)
            overallProgressText = "整体进度: (\(currentIndex)/\(videoItems.count))"
        }

        guard currentIndex < videoItems.count else {
            finishProcessing()
            return
        }

        let item = videoItems[currentIndex]
        currentItemName = "正在处理: \(item.url.lastPathComponent)"
        currentItemProgress = 0.0
        currentItemProgressText = "0%"

        guard let outputDir = self.outputDirectory, let duration = item.duration else {
            print("错误: 未设置输出目录或未获取到视频时长。")
            finishProcessing()
            return
        }
        
        let command = item.buildCommand(outputDirectory: outputDir)
        commandRunner.run(command: command, totalFrames: nil, totalDuration: duration)
    }
    
    private func updateEstimatedTimeRemaining(with progress: ProcessingProgress) {
        // 使用基于总用时和总时长的平均速度算法
        guard let startTime = self.batchStartTime, totalBatchDuration > 0 else {
            self.estimatedTimeRemainingString = "剩余时间: 正在计算..."
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        guard elapsedTime > 2 else { // 至少经过2秒，避免初期计算不准
            self.estimatedTimeRemainingString = "剩余时间: 正在计算..."
            return
        }
        
        // 1. 计算已处理的总时长 (所有已完成视频 + 当前视频已处理部分)
        let durationOfCompletedItems = videoItems.prefix(currentIndex).reduce(0) { $0 + ($1.duration ?? 0) }
        let durationOfCurrentItemProcessed = progress.currentTime
        let totalProcessedDuration = durationOfCompletedItems + durationOfCurrentItemProcessed
        
        // 2. 计算平均处理速度 (处理的视频秒数 / 花费的真实秒数)
        let averageSpeed = totalProcessedDuration / elapsedTime
        
        guard averageSpeed > 0 else { return }
        
        // 3. 计算剩余的总时长
        let remainingDuration = totalBatchDuration - totalProcessedDuration
        
        // 4. 计算预计剩余时间
        let etr = remainingDuration / averageSpeed
        
        if etr > 0 {
            self.estimatedTimeRemainingString = "剩余时间: 约 \(formatTime(seconds: etr))"
        } else {
            self.estimatedTimeRemainingString = "剩余时间: 即将完成..."
        }
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2 // 最多显示两个单位，如“1小时15分钟”或“15分钟30秒”
        return formatter.string(from: seconds) ?? ""
    }

    func cancelProcessing() {
        commandRunner.stop()
        finishProcessing(cancelled: true)
    }

    private func finishProcessing(cancelled: Bool = false) {
        // 停止访问安全范围资源
        self.outputDirectory?.stopAccessingSecurityScopedResource()
        
        DispatchQueue.main.async {
            self.estimatedTimeRemainingString = ""
            if cancelled {
                self.currentItemName = "已取消"
            } else {
                self.currentItemName = "全部任务已完成"
                self.overallProgress = 1.0
                if !self.videoItems.isEmpty {
                    self.overallProgressText = "整体进度: (\(self.videoItems.count)/\(self.videoItems.count))"
                }
            }
            self.isProcessing = false
        }
    }
}