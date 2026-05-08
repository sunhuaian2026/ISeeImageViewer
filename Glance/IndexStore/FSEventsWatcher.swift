//
//  FSEventsWatcher.swift
//  Glance
//
//  Slice G — CoreServices FSEventStream 的 Swift 薄包装。每个 root 一个 watcher
//  实例（lifecycle 跟 root 一致：root 注册时 start，root 删除时 stop + invalidate）。
//
//  flags 组合（标准 watch-root 文件级）：
//    - FileEvents：文件级 events（不只是目录）
//    - WatchRoot：root 自身被改名/移动会派发 RootChanged event
//    - NoDefer：events 立即派发不延迟（结合 latency=1.0s 做 batch）
//    - UseCFTypes：eventPaths 走 CFArray<CFString>（Swift toll-free bridge 到 [String]）
//
//  Callback 在指定 dispatch queue 派发 events 数组（caller 自定义后续处理；Slice G.2
//  处理 Created，G.3 加 Removed + Modified）。
//

import Foundation
import CoreServices

struct FSEvent {
    let path: String
    let flags: FSEventStreamEventFlags

    var isFile: Bool       { flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 }
    var isCreated: Bool    { flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 }
    var isRemoved: Bool    { flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 }
    var isRenamed: Bool    { flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 }
    var isModified: Bool   { flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 }
    var isInodeMetaMod: Bool { flags & UInt32(kFSEventStreamEventFlagItemInodeMetaMod) != 0 }
    /// root 被改名/移动 — 当前 watcher 失效，caller 应 stop + 重启 watch
    var isRootChanged: Bool { flags & UInt32(kFSEventStreamEventFlagRootChanged) != 0 }
}

final class FSEventsWatcher {

    private var stream: FSEventStreamRef?
    private let dispatchQueue: DispatchQueue
    /// 每次 callback 接收一批 events（已切到 dispatchQueue 上派发）。
    private let onEvents: ([FSEvent]) -> Void

    init(queue: DispatchQueue, onEvents: @escaping ([FSEvent]) -> Void) {
        self.dispatchQueue = queue
        self.onEvents = onEvents
    }

    deinit { stop() }

    /// 启动监听 root 路径下的所有 file events。已 start 过则先 stop 再重启。
    func start(rootPath: String, latency: CFTimeInterval = 1.0) {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagWatchRoot
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagUseCFTypes
        )

        let callback: FSEventStreamCallback = { _, clientInfo, numEvents, eventPaths, eventFlags, _ in
            guard let clientInfo else { return }
            let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(clientInfo).takeUnretainedValue()

            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            guard let paths = cfArray as? [String] else { return }

            var events: [FSEvent] = []
            events.reserveCapacity(numEvents)
            for i in 0..<numEvents {
                events.append(FSEvent(path: paths[i], flags: eventFlags[i]))
            }
            // dispatch queue 已由 FSEventStreamSetDispatchQueue 设置，callback 已在该 queue
            watcher.onEvents(events)
        }

        let pathsToWatch = [rootPath] as CFArray
        guard let createdStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            print("[FSEvents] FSEventStreamCreate FAILED for \(rootPath)")
            return
        }

        FSEventStreamSetDispatchQueue(createdStream, dispatchQueue)
        guard FSEventStreamStart(createdStream) else {
            print("[FSEvents] FSEventStreamStart FAILED for \(rootPath)")
            FSEventStreamInvalidate(createdStream)
            FSEventStreamRelease(createdStream)
            return
        }

        stream = createdStream
        print("[FSEvents] watching \(rootPath)")
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }
}
