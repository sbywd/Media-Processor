import Foundation
import SwiftUI
import Combine

class ProcessingViewModel: ObservableObject, Identifiable {
    // 整体进度
    @Published var overallProgress: Double = 0.0
    @Published var overallProgressText: String = String(NSLocalizedString("整体进度: (0/0)", comment: "整体进度: (0/0)"))
    
    // 当前项目进度
    @Published var currentItemProgress: Double = 0.0
    @Published var currentItemProgressText: String = "0%"
    @Published var currentItemName: String = String(NSLocalizedString("准备中...", comment: "准备中..."))
    
    // 预计剩余时间
    @Published var estimatedTimeRemainingString: String = ""
    
    // 状态
    @Published var isProcessing: Bool = false
    @Published var hasFailed: Bool = false // 新增：处理失败状态
    @Published var errorMessage: String = "" // 新增：存储错误信息
    
    private var commandRunner = CommandRunner()
    private var videoItems: [VideoItem] = []
    private var outputDirectory: URL?
    private var currentIndex: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var etrUpdateTimer: Timer?
    
    private var batchStartTime: Date?
    private var totalBatchDuration: TimeInterval = 0

    init() {
        // 监听 CommandRunner 的进度
        commandRunner.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self, self.isProcessing, let progress = progress else { return }
                if !(progress.fractionCompleted == 0){
                    self.currentItemProgress = progress.fractionCompleted
                }
                self.currentItemProgressText = "\(progress.percentage)%"
                
                if !self.videoItems.isEmpty {
                    let completedItems = Double(self.currentIndex)
                    let totalItems = Double(self.videoItems.count)
                    if !((completedItems + self.currentItemProgress) / totalItems == 0){
                        self.overallProgress = (completedItems + self.currentItemProgress) / totalItems
                    }
                }
            }
            .store(in: &cancellables)

        // 监听 CommandRunner 的运行状态以链接命令
        commandRunner.$isRunning
            .receive(on: DispatchQueue.main)
            .filter { !$0 && self.isProcessing && !self.hasFailed } // 仅在未失败时处理
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processNextItem()
            }
            .store(in: &cancellables)
        
        // 新增：监听 CommandRunner 的错误发布器
        commandRunner.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] commandError in
                self?.handleProcessingFailure(error: commandError)
            }
            .store(in: &cancellables)
    }

    func start(items: [VideoItem], outputDirectory: URL) {
        self.videoItems = items
        self.outputDirectory = outputDirectory
        self.currentIndex = -1
        self.isProcessing = true
        self.hasFailed = false // 重置失败状态
        self.errorMessage = "" // 重置错误信息
        
        self.currentItemProgress = 0.0
        self.currentItemProgressText = "0%"
        self.overallProgress = 0.0
        self.overallProgressText = String(format: NSLocalizedString("整体进度: %d", comment: "整体进度"), items.count)

        self.currentItemName = String(NSLocalizedString("正在准备...", comment: "正在准备..."))
        self.estimatedTimeRemainingString = String(NSLocalizedString("剩余时间: 正在计算...", comment: "剩余时间: 正在计算..."))
        
        startETRUpdateTimer()
        
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
        
        group.notify(queue: .main) {
            guard !self.hasFailed else { return } // 如果在探测阶段已失败，则不继续
            
            self.totalBatchDuration = self.videoItems.reduce(0) { $0 + ($1.adjustedDuration ?? 0) }
            self.batchStartTime = Date()
            
            guard self.outputDirectory?.startAccessingSecurityScopedResource() ?? false else {
                print("错误：无法获取对输出目录的访问权限。")
                self.handleProcessingFailure(error: .processFailed(stderr: "无法获取对输出目录的访问权限。请重新选择输出目录。"))
                return
            }
            
            self.processNextItem()
        }
    }

    private func processNextItem() {
        guard !hasFailed else { return } // 如果已失败，则停止处理队列

        currentIndex += 1
        
        if !videoItems.isEmpty {
            overallProgress = Double(currentIndex) / Double(videoItems.count)
            overallProgressText = String(
                format: NSLocalizedString("整体进度: (%d/%d)", comment: "整体进度: (%d/%d)"),
                currentIndex,
                videoItems.count
            )
        }

        guard currentIndex < videoItems.count else {
            finishProcessing()
            return
        }

        let item = videoItems[currentIndex]
        currentItemName = String(format: NSLocalizedString("正在处理: %@", comment: "正在处理"), item.url.lastPathComponent)
        currentItemProgress = 0.0
        currentItemProgressText = "0%"

        guard let outputDir = self.outputDirectory, let adjustedDuration = item.adjustedDuration else {
            print("错误: 未设置输出目录或未获取到视频时长。")
            handleProcessingFailure(error: .processFailed(stderr: "未能获取视频 \(item.url.lastPathComponent) 的时长信息。"))
            return
        }
        
        let command = item.buildCommand(outputDirectory: outputDir)
        commandRunner.run(command: command, totalFrames: nil, totalDuration: adjustedDuration)
    }
    
    private func handleProcessingFailure(error: CommandError) {
        guard !hasFailed else { return } // 防止重复处理错误
        
        self.hasFailed = true
        self.isProcessing = false // 停止处理状态
        stopETRUpdateTimer()
        
        switch error {
        case .processFailed(let stderr):
            self.errorMessage = stderr
        }
        
        // 确保安全书签被释放
        self.outputDirectory?.stopAccessingSecurityScopedResource()
    }
    
    private func calculateETR() -> TimeInterval? {
        guard let startTime = self.batchStartTime, totalBatchDuration > 0 else {
            return nil
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        guard elapsedTime > 2 else {
            return nil
        }
        
        let durationOfCompletedItems = videoItems.prefix(currentIndex).reduce(0) { $0 + ($1.duration ?? 0) }
        let durationOfCurrentItemProcessed = commandRunner.progress?.currentTime ?? 0
        let totalProcessedDuration = durationOfCompletedItems + durationOfCurrentItemProcessed
        
        let averageSpeed = totalProcessedDuration / elapsedTime
        
        guard averageSpeed > 0 else { return nil }
        
        let remainingDuration = totalBatchDuration - totalProcessedDuration
        
        let etr = remainingDuration / averageSpeed
        
        return etr > 0 ? etr : nil
    }
    
    private func startETRUpdateTimer() {
        stopETRUpdateTimer()
        etrUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateETRDisplay()
        }
        RunLoop.main.add(etrUpdateTimer!, forMode: .common)
    }
    
    private func stopETRUpdateTimer() {
        etrUpdateTimer?.invalidate()
        etrUpdateTimer = nil
    }
    
    private func updateETRDisplay() {
        if let etr = calculateETR() {
            self.estimatedTimeRemainingString = String(format: NSLocalizedString("剩余时间: 约 %@", comment: "剩余时间"), formatTime(seconds: etr))
        } else {
            self.estimatedTimeRemainingString = String(NSLocalizedString("剩余时间: 正在计算...", comment: "剩余时间: 正在计算..."))
        }
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? ""
    }

    func cancelProcessing() {
        commandRunner.stop()
        finishProcessing(cancelled: true)
    }

    private func finishProcessing(cancelled: Bool = false) {
        guard !hasFailed else { return } // 如果已失败，则不执行正常的完成逻辑
        
        stopETRUpdateTimer()
        self.outputDirectory?.stopAccessingSecurityScopedResource()
        
        DispatchQueue.main.async {
            self.estimatedTimeRemainingString = ""
            if cancelled {
                self.currentItemName = String(NSLocalizedString("已取消", comment: "已取消"))
            }
            else {
                self.currentItemName = String(NSLocalizedString("全部任务已完成", comment: "全部任务已完成"))
                self.overallProgress = 1.0
                if !self.videoItems.isEmpty {
                    self.overallProgressText = String(
                        format: NSLocalizedString("整体进度: (%d/%d)", comment: "整体进度: (%d/%d)"),
                        self.videoItems.count,
                        self.videoItems.count
                    )
                }
            }
            self.isProcessing = false
        }
    }
}
