import Foundation
import CryptoKit

nonisolated struct ScreenshotFile: Identifiable, Hashable, Sendable {
    let serial: String
    let remotePath: String
    var id: String { remotePath }
    var name: String { (remotePath as NSString).lastPathComponent }
    var isVideo: Bool {
        MediaKind.movies.fileExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// ディスクキャッシュ用のファイル名。端末側の名前をそのまま使うと
    /// 別ディレクトリの同名ファイルが衝突するため、リモートパスのハッシュにする。
    var cacheFileName: String {
        let hash = SHA256.hash(data: Data(remotePath.utf8))
            .prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? hash : "\(hash).\(ext)"
    }
}
