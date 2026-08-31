import SwiftUI
import Combine

@MainActor
final class DeviceStore: ObservableObject {
    @Published var serial: String?
    @Published var files: [ScreenshotFile] = []
    @Published var error: String?
    @Published var kind: MediaKind = .screenshots {
        didSet {
            guard kind != oldValue else { return }
            files = []
            refresh()
        }
    }

    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("adb-screenshots")

    private let thumbnailCache = NSCache<NSString, NSImage>()
    /// サムネイルの最大辺（pt 120 × Retina 想定）
    private let thumbnailMaxPixel: CGFloat = 320

    init() {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        let kind = self.kind
        Task.detached {
            do {
                let serial = try ADB.devices().first
                let files = try serial.map { try ADB.listFiles(serial: $0, kind: kind) } ?? []
                await MainActor.run {
                    self.serial = serial; self.files = files; self.error = nil
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    /// メモリキャッシュ → ディスク（未取得なら pull）→ 縮小 の順に解決する。
    func thumbnail(for file: ScreenshotFile) async -> NSImage? {
        let key = file.id as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }

        let cacheDir = self.cacheDir
        let maxPixel = thumbnailMaxPixel
        let jpeg = await Task.detached(priority: .utility) { () -> Data? in
            let dest = cacheDir.appendingPathComponent(file.cacheFileName)
            if !FileManager.default.fileExists(atPath: dest.path) {
                do {
                    try ADB.pull(serial: file.serial, remotePath: file.remotePath, to: dest)
                } catch {
                    // 中断された pull が壊れたファイルとして残らないよう片付ける
                    try? FileManager.default.removeItem(at: dest)
                    return nil
                }
            }
            guard FileManager.default.fileExists(atPath: dest.path) else { return nil }
            if file.isVideo {
                return await Thumbnailer.downsampledVideoJPEG(at: dest, maxPixel: maxPixel)
            }
            return Thumbnailer.downsampledJPEG(at: dest, maxPixel: maxPixel)
        }.value

        guard let jpeg, let image = NSImage(data: jpeg) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }
}
