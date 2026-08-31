import Foundation

nonisolated enum MediaKind: String, CaseIterable, Identifiable, Sendable {
    case screenshots = "スクリーンショット"
    case movies = "動画"

    var id: Self { self }

    /// 候補ディレクトリ。存在するものをすべて一覧する。
    var remoteDirs: [String] {
        switch self {
        case .screenshots:
            return ["/sdcard/Pictures/Screenshots", "/sdcard/DCIM/Screenshots"]
        case .movies:
            // Pixel の画面録画は /sdcard/Movies、Samsung は /sdcard/DCIM/Screen recordings
            return ["/sdcard/Movies", "/sdcard/DCIM/Screen recordings"]
        }
    }

    var fileExtensions: Set<String> {
        switch self {
        case .screenshots: return ["png", "jpg", "jpeg", "webp"]
        case .movies: return ["mp4", "webm", "mkv", "3gp"]
        }
    }

    /// ドロップイン時の push 先
    var pushDir: String { remoteDirs[0] + "/" }
}
