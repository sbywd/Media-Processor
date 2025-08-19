# Gemini Project Documentation: ffmpegui

This document provides a comprehensive overview of the `ffmpegui` macOS application for future sessions. It outlines the project's architecture, key components, and core workflows.

## 1. Project Overview

`ffmpegui` is a SwiftUI-based macOS application that provides a graphical user interface (GUI) for the `ffmpeg` command-line tool. It allows users to add multiple video files, configure various processing and encoding settings for each file, and run them as a batch process. The application displays real-time progress for both individual tasks and the overall batch.

## 2. Core Technologies

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Platform**: macOS
- **Key Dependencies**: The application relies on an `ffmpeg` and `ffprobe` executable being present in the app's bundle.

## 3. Key Files & Architecture

The application follows a modern SwiftUI architecture, with state management handled by `ObservableObject` view models.

### `MainView.swift`
This is the most critical file, containing the main UI and the primary data models and view models.

-   **`VideoItem` Class**: An `ObservableObject` representing a single video file in the list. It holds all processing settings (resolution, bitrate, codecs, etc.) and metadata (`videoInfo`, `audioInfo`). Its `loadMetadata()` method uses `CommandRunner` to fetch real video data via `ffprobe`.
-   **`ProcessingProperties` Struct**: A plain struct that holds all the processing settings of a `VideoItem`. It acts as a data transfer object (DTO) for the copy/paste functionality.
-   **`MainViewModel` Class**: The main view model. It manages the array of `videoItems` (`@Published var videoItems: [VideoItem]`). It also handles all user interactions like selection management (`selection` set), property copy/paste (`propertiesClipboard`), and item deletion.
-   **`MainView` Struct**: The primary view. It assembles the UI, including the list of videos, and uses computed properties (`videoListView`, `bottomBar`, etc.) to keep the `body` property simple and avoid compiler issues. It handles user input via `.onTapGesture`, `.contextMenu`, and `.keyboardShortcut` modifiers, delegating the logic to `MainViewModel`.
-   **Sheet Management**: Uses a single `@State private var activeSheet: ActiveSheet?` with an `enum` to manage presenting different sheets (for processing progress or item configuration), which is a robust SwiftUI pattern.

### `ProcessingViewModel.swift` & `ProcessingView.swift`
These two files manage the batch processing workflow.

-   **`ProcessingViewModel` Class**: The engine for the batch process. When its `start()` method is called, it first pre-probes all `VideoItem`s to get their durations. It then processes items sequentially. It calculates the overall progress and the Estimated Time Remaining (ETR) based on the *average speed* of the entire batch processing so far. It uses an instance of `CommandRunner` to execute the actual `ffmpeg` commands.
-   **`ProcessingView` Struct**: A SwiftUI view that is presented modally as a sheet. It observes the `ProcessingViewModel` to display real-time progress of the current item and the overall batch, including the ETR string.

### `CommandRunner.swift`
This is the low-level bridge between the SwiftUI application and the command-line tools.

-   **`probe()` Method**: Executes `ffprobe` with JSON output flags, and decodes the output into Swift structs (`FFProbeResult`, `StreamInfo`).
-   **`run()` Method**: Executes `ffmpeg`. It intelligently injects the `-progress pipe:1` argument to capture progress data from the standard output stream. It parses this output in real-time to publish `ProcessingProgress` updates.

### `ffmpegui.entitlements`
This file configures the application's security sandbox.
-   It allows the app to read/write files and folders selected by the user (`com.apple.security.files.user-selected.read-write`).
-   Crucially, it enables the use of app-scoped security bookmarks (`com.apple.security.files.bookmarks.app-scope`), which is essential for the output path persistence feature.

## 4. Core Workflows

-   **Adding & Configuring Videos**: The user adds videos via an `NSOpenPanel`. For each video, a `VideoItem` is created, and its `loadMetadata()` method is called to asynchronously fetch real data using `ffprobe`.
-   **Copy/Paste Settings**: The user can right-click or use `⌘+C` on a selected item to copy its settings into `MainViewModel`'s `propertiesClipboard`. `⌘+V` or the context menu then applies these stored properties to all currently selected items.
-   **Batch Processing**: The user clicks "Start All". This triggers `ProcessingViewModel.start()`. The view model then takes over the entire queue, and the `ProcessingView` sheet is displayed to show progress.
-   **Output Path Persistence**: When the user selects an output directory, the app creates a security-scoped bookmark and saves its `Data` representation in `UserDefaults`. On subsequent launches, the app restores the URL from this bookmark data, allowing it to retain write access to that specific directory across restarts.
