import Foundation

nonisolated struct ADB {
    // 環境に合わせて調整
    static let path = "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb"

    struct Failure: Error, LocalizedError {
        let command: String
        let status: Int32
        let output: String

        var errorDescription: String? {
            output.isEmpty
                ? "adb \(command) が失敗しました（終了コード \(status)）"
                : "adb \(command) が失敗しました（終了コード \(status)）: \(output)"
        }
    }

    @discardableResult
    static func run(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        // waitUntilExit より先に読み切らないとパイプが詰まる
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw Failure(
                command: args.joined(separator: " "),
                status: process.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    static func devices() throws -> [String] {
        try run(["devices"])
            .split(separator: "\n").dropFirst()   // 先頭行は "List of devices attached"
            .compactMap { line in
                let parts = line.split(separator: "\t")
                return (parts.count == 2 && parts[1] == "device") ? String(parts[0]) : nil
            }
    }

    static func listFiles(serial: String, kind: MediaKind) throws -> [ScreenshotFile] {
        var files: [ScreenshotFile] = []
        for dir in kind.remoteDirs {
            // 引数は端末側シェルに空白連結で渡るため、空白を含むパスはクォートが必要
            let out: String
            do {
                out = try run(["-s", serial, "shell", "ls", "-1", "'\(dir)'"])
            } catch let failure as Failure where failure.output.contains("No such file") {
                continue   // その端末に無いディレクトリ（機種差）
            }
            if out.contains("No such file") { continue }   // 終了コード 0 で返す adb 向け
            files += out.split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { kind.fileExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .map { ScreenshotFile(serial: serial, remotePath: "\(dir)/\($0)") }
        }
        // ファイル名がゼロ埋めタイムスタンプなので、名前降順 = 新しい順
        return files.sorted { $0.name > $1.name }
    }

    static func pull(serial: String, remotePath: String, to localURL: URL) throws {
        try run(["-s", serial, "pull", remotePath, localURL.path])
    }

    static func push(serial: String, localPath: String, toDir remoteDir: String) throws {
        try run(["-s", serial, "push", localPath, remoteDir])
    }
}
