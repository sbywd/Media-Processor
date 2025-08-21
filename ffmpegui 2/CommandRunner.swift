import Foundation // 导入 Foundation 框架，提供基本数据类型和系统服务

// MARK: - 混合类型 JSON 的辅助工具
/// `JSONValue` 枚举用于健壮地解码包含混合值类型（如字符串、数字、布尔值、空值）的 JSON 对象。
/// 它实现了 `Codable` 和 `Hashable` 协议，以便进行编码、解码和哈希操作。
enum JSONValue: Codable, Hashable {
    case string(String) // 字符串类型
    case int(Int) // 整型
    case double(Double) // 双精度浮点型
    case bool(Bool) // 布尔型
    case null // 空值

    /// 从解码器初始化 `JSONValue`。
    /// 尝试按顺序解码为 Int, Double, String, Bool，如果都失败则检查是否为 null，否则抛出类型不匹配错误。
    /// - Parameter decoder: 用于解码的解码器。
    /// - Throws: 如果值类型不支持或解码失败，则抛出 `DecodingError`。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer() // 获取单值容器
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "不支持的 JSON 值类型"))
        }
    }

    /// 将 `JSONValue` 编码到编码器。
    /// 根据枚举的实际类型，将对应的值编码到单值容器中。
    /// - Parameter encoder: 用于编码的编码器。
    /// - Throws: 如果编码失败，则抛出 `EncodingError`。
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer() // 获取单值容器
        switch self {
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}


// MARK: - 数据结构
/// `FFProbeResult` 结构体用于解码 FFprobe 命令的 JSON 输出。
/// 包含程序信息、流组信息和流信息列表。
struct FFProbeResult: Codable {
    let programs: [String]? // 程序列表，可选
    let stream_groups: [String]? // 流组列表，可选
    let streams: [StreamInfo] // 流信息列表，必需
}

/// `StreamInfo` 结构体用于解码 FFprobe 输出中单个媒体流的详细信息。
struct StreamInfo: Codable {
    let codec_type: String // 编解码器类型（如 "video", "audio"）
    let codec_name: String? // 编解码器名称（如 "hevc", "aac"），可选，以兼容没有 codec_name 的数据流
    let bit_rate: String? // 比特率，可选
    let width: Int? // 视频宽度，可选
    let height: Int? // 视频高度，可选
    let avg_frame_rate: String? // 平均帧率，可选
    let duration: String? // 流时长，可选
    let disposition: [String: Int]? // 处理方式，可选
    let tags: [String: String]? // 标签，可选
    let color_space: String? // 色彩空间，可选
    let side_data_list: [[String: JSONValue]]? // 侧边数据列表，使用自定义 `JSONValue` 处理混合类型，可选
}

/// `ProcessingProgress` 结构体用于跟踪 FFmpeg 命令的执行进度。
/// 包含当前时间、总时长、当前帧、总帧数和处理速度。
struct ProcessingProgress {
    var currentTime: TimeInterval = 0 // 当前处理时间（秒）
    var totalDuration: TimeInterval = 1 // 总时长（秒），默认为1以避免除零
    var currentFrame: Int? // 当前处理的帧数，可选
    var totalFrames: Int? // 总帧数，可选
    var speed: Double = 0.0 // 处理速度（倍速）
    
    /// 计算属性，表示任务完成的百分比（0.0到1.0之间）。
    var fractionCompleted: Double {
        guard totalDuration > 0 else { return 0 } // 避免除零错误
        return currentTime / totalDuration
    }
    
    /// 计算属性，表示任务完成的百分比（整数）。
    var percentage: Int {
        Int(fractionCompleted * 100)
    }
    
    /// 计算属性，表示估计的剩余时间。
    /// 如果速度为0或当前时间为0，或者当前时间已超过总时长，则返回nil。
    var estimatedTimeRemaining: TimeInterval? {
        guard speed > 0 && currentTime > 0 && totalDuration > currentTime else {
            return nil
        }
        let remainingDuration = totalDuration - currentTime // 计算剩余时长
        return remainingDuration / speed // 剩余时长除以速度得到估计剩余时间
    }
}

// MARK: - 新增错误类型
/// `CommandError` 枚举用于定义命令执行过程中可能发生的特定错误。
enum CommandError: Error {
    /// 表示进程执行失败，并附带从 stderr 捕获的错误信息。
    case processFailed(stderr: String)
}


import Combine // 导入 Combine 框架

// MARK: - CommandRunner 类
/// `CommandRunner` 类负责执行 FFmpeg 和 FFprobe 命令，并管理其输出和进度。
/// 它是一个 `ObservableObject`，以便 SwiftUI 视图可以观察其发布的状态变化。
class CommandRunner: ObservableObject {
    /// `@Published` 属性包装器，用于存储 FFmpeg 命令的实时输出。
    @Published var output: String = ""
    /// `@Published` 属性包装器，布尔值，表示命令是否正在运行。
    @Published var isRunning: Bool = false
    /// `@Published` 属性包装器，用于存储当前处理进度信息。
    @Published var progress: ProcessingProgress?
    
    /// 新增：一个 Combine Subject，用于在发生错误时发布事件。
    let errorPublisher = PassthroughSubject<CommandError, Never>()
    
    private var process: Process? // 当前正在运行的进程实例
    /// 计算属性，获取 FFmpeg 可执行文件的路径。
    private var ffmpegPath: String? { Bundle.main.path(forResource: "ffmpeg", ofType: nil) }
    /// 计算属性，获取 FFprobe 可执行文件的路径。
    private var ffprobePath: String? { Bundle.main.path(forResource: "ffprobe", ofType: nil) }

    private var progressValues: [String: String] = [:] // 用于存储 FFmpeg 进度输出的键值对
    private let maxOutputLines = 500 // 限制最大输出行数，防止内存占用过高
    private var accumulatedErrorOutput: String = "" // 新增：用于累积 stderr 的输出

    // MARK: - 公共方法
    
    /// 运行 FFmpeg 命令。
    /// - Parameters:
    ///   - command: 要执行的 FFmpeg 命令字符串。
    ///   - totalFrames: 视频的总帧数，可选。用于计算进度。
    ///   - totalDuration: 视频的总时长（秒）。用于计算进度。
    func run(command: String, totalFrames: Int?, totalDuration: TimeInterval) {
        /// 确保 FFmpeg 可执行文件存在。
        guard let path = ffmpegPath else {
            DispatchQueue.main.async {
                self.appendOutput("错误：在App Bundle中找不到 ffmpeg 可执行文件。")
                self.isRunning = false
            }
            return
        }
        
        var arguments = self.parse(command: command) // 解析命令字符串为参数数组
        
        // --- 核心修正：智能判断是否添加硬件解码 ---
        
        // 1. 首先检查命令中是否使用了硬件编码器。
        //    硬件编码器通常在名称中包含 "_videotoolbox"。
        let isUsingHardwareEncoder = arguments.contains { $0.contains("_videotoolbox") }
        
        // 2. 仅在以下条件下启用输入端硬件解码 (-hwaccel):
        //    - 这是一个视频任务 (totalFrames != nil)
        //    - 并且，我们没有使用硬件编码器 (以避免冲突)
        if totalFrames != nil && !isUsingHardwareEncoder {
             arguments.insert(contentsOf: ["-hwaccel", "videotoolbox"], at: 0) // 在参数开头插入硬件加速选项
        }
       
        // `-progress pipe:1` 参数总是需要的，用于将进度信息输出到标准输出
        arguments.insert(contentsOf: ["-progress", "pipe:1"], at: 0)

        self.progressValues = [:] // 清空进度值字典
        self.accumulatedErrorOutput = "" // 清空累积的错误输出

        /// 在全局并发队列中异步执行 FFmpeg 进程，避免阻塞主线程。
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process() // 创建一个新的进程实例
            self.process = task // 存储进程实例以便后续控制
            task.launchPath = path // 设置可执行文件路径
            task.arguments = arguments // 设置命令行参数

            let outputPipe = Pipe() // 创建用于捕获标准输出的管道
            let errorPipe = Pipe() // 创建用于捕获标准错误的管道
            task.standardOutput = outputPipe // 将进程的标准输出重定向到 outputPipe
            task.standardError = errorPipe // 将进程的标准错误重定向到 errorPipe

            /// 设置标准输出管道的可读性处理器。
            /// 当有新数据可用时，此闭包会被调用。
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData // 读取可用数据
                if let line = String(data: data, encoding: .utf8) {
                    self.parseProgress(from: line, totalFrames: totalFrames, totalDuration: totalDuration) // 解析进度信息
                }
            }
            
            /// 设置标准错误管道的可读性处理器。
            /// 当有新数据可用时，此闭包会被调用。
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData // 读取可用数据
                if let line = String(data: data, encoding: .utf8) {
                    // 将错误信息同时追加到累积错误输出和实时输出中
                    self.accumulatedErrorOutput += line
                    DispatchQueue.main.async {
                        self.appendOutput(line)
                    }
                }
            }
            
            /// 设置进程终止处理器。
            /// 当进程结束时，此闭包会被调用。
            task.terminationHandler = { process in
                DispatchQueue.main.async {
                    self.isRunning = false // 更新运行状态为 false
                    self.process = nil // 清除进程实例
                    if process.terminationStatus == 0 { // 如果进程正常退出（退出码为0）
                        self.progress = ProcessingProgress( // 设置最终进度为100%
                            currentTime: totalDuration,
                            totalDuration: totalDuration,
                            currentFrame: totalFrames,
                            totalFrames: totalFrames,
                            speed: 1.0
                        )
                        self.appendOutput("\n\n✅ 任务成功完成！") // 追加成功消息
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.progress = nil // 延迟1秒后清除进度显示
                        }
                    } else { // 如果进程异常退出
                        self.progress = nil // 清除进度显示
                        if process.terminationReason == .uncaughtSignal { // 如果是由于未捕获的信号终止（通常是用户手动停止）
                            self.appendOutput("\n\n🛑 任务被用户手动停止。") // 追加手动停止消息
                        } else {
                            // 发送一个包含详细 stderr 的错误事件
                            self.errorPublisher.send(.processFailed(stderr: self.accumulatedErrorOutput))
                            self.appendOutput("\n\n❌ 任务失败，退出码：\(process.terminationStatus).") // 追加失败消息和退出码
                        }
                    }
                }
            }
            
            /// 在主队列中更新 UI 状态，表示命令即将开始执行。
            DispatchQueue.main.async {
                self.isRunning = true // 设置运行状态为 true
                self.output = "" // 清空之前的输出
                self.appendOutput("🚀 开始执行命令: ffmpeg \(arguments.joined(separator: " "))\n\n") // 追加开始执行命令的提示
                self.progress = ProcessingProgress(totalDuration: totalDuration, totalFrames: totalFrames) // 初始化进度信息
            }


            do {
                try task.run() // 尝试启动进程
            } catch {
                /// 如果启动进程失败，在主队列中更新错误信息。
                DispatchQueue.main.async {
                    self.appendOutput("启动进程时出错: \(error.localizedDescription)")
                    self.isRunning = false
                    self.process = nil
                    self.progress = nil
                }
            }
        }
    }
    
    /// 停止当前正在运行的 FFmpeg 进程。
    func stop() {
        /// 确保有正在运行的进程且 `isRunning` 为 true。
        guard let runningProcess = self.process, self.isRunning else { return }
        runningProcess.terminate() // 终止进程
    }
    
    /// 探测指定文件的媒体信息（使用 FFprobe）。
    /// - Parameters:
    ///   - fileURL: 要探测的文件的 URL。
    ///   - completion: 探测完成后的回调闭包，返回 `Result<FFProbeResult, Error>`。
    func probe(fileURL: URL, completion: @escaping (Result<FFProbeResult, Error>) -> Void) {
        /// 确保 FFprobe 可执行文件存在。
        guard let path = ffprobePath else {
            completion(.failure(NSError(domain: "CommandRunner", code: 404, userInfo: [NSLocalizedDescriptionKey: "ffprobe 未找到"])))
            return
        }
        
        /// 在全局并发队列中异步执行 FFprobe 进程。
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process() // 创建新的进程实例
            task.launchPath = path // 设置可执行文件路径
            /// 设置 FFprobe 命令行参数，以 JSON 格式输出流信息。
            task.arguments = ["-v", "quiet", "-print_format", "json", "-show_streams", "-show_entries", "stream=duration,avg_frame_rate,codec_type,codec_name,bit_rate,width,height,color_space", fileURL.path]
            
            let outputPipe = Pipe() // 创建用于捕获标准输出的管道
            task.standardOutput = outputPipe // 将进程的标准输出重定向到 outputPipe
            
            do {
                try task.run() // 尝试启动进程
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile() // 读取所有输出数据
                task.waitUntilExit() // 等待进程退出
                
                // 打印原始 ffprobe 输出用于调试
                if let rawOutput = String(data: data, encoding: .utf8) {
                    print("ffprobe 原始输出: \(rawOutput)")
                }

                // 注意：ffprobe 有时会在 JSON 前后输出一些非 JSON 文本，这里做一个简单的清理
                if let jsonString = String(data: data, encoding: .utf8),
                   let jsonStartIndex = jsonString.firstIndex(of: "{"),
                   let jsonEndIndex = jsonString.lastIndex(of: "}") {
                    let trimmedJsonString = String(jsonString[jsonStartIndex...jsonEndIndex]) // 提取纯 JSON 字符串
                    if let jsonData = trimmedJsonString.data(using: .utf8) {
                        // 使用修正后的 Codable 结构体进行解码
                        let result = try JSONDecoder().decode(FFProbeResult.self, from: jsonData)
                        DispatchQueue.main.async { completion(.success(result)) } // 在主队列中回调成功结果
                    } else {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "CommandRunner", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法将提取的 JSON 字符串转换为数据。"]))) }
                    }
                } else {
                     // 如果解码失败，返回更具体的错误信息
                    do {
                        _ = try JSONDecoder().decode(FFProbeResult.self, from: data)
                    } catch let decodingError as DecodingError {
                        // 打印详细的解码错误，方便调试
                        print("JSON 解码错误: \(decodingError)")
                        DispatchQueue.main.async { completion(.failure(decodingError)) } // 在主队列中回调解码错误
                        return
                    } catch {
                         DispatchQueue.main.async { completion(.failure(error)) } // 在主队列中回调其他错误
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) } // 在主队列中回调进程启动或数据读取错误
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    /// 将新的行追加到输出文本中，并限制总行数。
    /// - Parameter newLine: 要追加的新行字符串。
    private func appendOutput(_ newLine: String) {
        var lines = output.components(separatedBy: .newlines) // 将当前输出按行分割
        lines.append(contentsOf: newLine.components(separatedBy: .newlines)) // 追加新行
        
        // 移除空行，使输出更整洁
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 限制输出行数，只保留最新的 `maxOutputLines` 行
        if lines.count > maxOutputLines {
            lines = Array(lines.suffix(maxOutputLines))
        }
        
        output = lines.joined(separator: "\n") // 将处理后的行重新连接成字符串
    }
    
    /// 解析 FFmpeg 进度输出字符串，并更新 `ProcessingProgress`。
    /// - Parameters:
    ///   - string: FFmpeg 进程输出的字符串。
    ///   - totalFrames: 视频的总帧数，可选。
    ///   - totalDuration: 视频的总时长（秒）。
    private func parseProgress(from string: String, totalFrames: Int?, totalDuration: TimeInterval) {
        let lines = string.components(separatedBy: .newlines) // 将输入字符串按行分割
        
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) } // 按 "=" 分割键值对
            if parts.count == 2 {
                progressValues[parts[0]] = parts[1] // 将键值对存储到 `progressValues` 字典中
            }
            
            /// 如果行以 "progress=" 开头，表示这是一条进度更新信息。
            if line.hasPrefix("progress=") {
                
                var currentTime: TimeInterval = 0 // 初始化当前时间
                /// 从 `progressValues` 中获取 `out_time_us`（微秒），并转换为秒。
                if let timeUsStr = progressValues["out_time_us"], let timeUs = Double(timeUsStr) {
                    currentTime = timeUs / 1_000_000
                }
                
                var currentFrame: Int? = nil // 初始化当前帧数
                /// 从 `progressValues` 中获取 `frame`，并转换为整数。
                if let frameStr = progressValues["frame"], let frame = Int(frameStr) {
                    currentFrame = frame
                }
                
                var speed: Double = 0.0 // 初始化速度
                /// 从 `progressValues` 中获取 `speed`，移除 "x" 后转换为双精度浮点数。
                if let speedStr = progressValues["speed"]?.replacingOccurrences(of: "x", with: ""), let speedValue = Double(speedStr) {
                    speed = speedValue
                }

                /// 在主队列中更新 `progress` 属性，触发 UI 更新。
                DispatchQueue.main.async {
                    self.progress = ProcessingProgress(
                        currentTime: currentTime,
                        totalDuration: totalDuration,
                        currentFrame: currentFrame,
                        totalFrames: totalFrames,
                        speed: speed
                    )
                }
            } else {
                // 将非进度行添加到输出，并进行行数限制
                DispatchQueue.main.async {
                    self.appendOutput(line)
                }
            }
        }
    }
    
    /// 解析命令行字符串为参数数组。
    /// 处理带引号的参数，确保它们被视为单个参数。
    /// - Parameter command: 完整的命令行字符串。
    /// - Returns: 解析后的参数字符串数组。
    private func parse(command: String) -> [String] {
        var arguments: [String] = [] // 存储解析后的参数
        var currentArgument = "" // 当前正在构建的参数
        var inQuotes = false // 标记是否在引号内部

        for character in command {
            if character == "\"" {
                inQuotes.toggle() // 切换引号状态
                // 当引号结束时，如果累积的参数不为空，则添加
                if !inQuotes, !currentArgument.isEmpty { arguments.append(currentArgument); currentArgument = "" }
            } else if character == " " && !inQuotes {
                // 如果遇到空格且不在引号内部，则当前参数结束，添加到列表中
                if !currentArgument.isEmpty { arguments.append(currentArgument); currentArgument = "" }
            } else {
                currentArgument.append(character) // 将字符追加到当前参数
            }
        }
        /// 循环结束后，如果 `currentArgument` 不为空，则将其作为最后一个参数添加。
        if !currentArgument.isEmpty { arguments.append(currentArgument) }
        return arguments // 返回解析后的参数数组
    }
}
