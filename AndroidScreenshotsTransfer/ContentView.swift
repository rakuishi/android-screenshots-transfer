import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = DeviceStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.serial.map { "接続中: \($0)" } ?? "端末が見つかりません")
                Spacer()
                Picker("種類", selection: $store.kind) {
                    ForEach(MediaKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Button("更新", action: store.refresh)
            }.padding()

            if let error = store.error {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .textSelection(.enabled)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .font(.callout)
                .foregroundStyle(.red)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            ScreenshotGridView(store: store)
        }
        // Finder からのドロップイン → adb push
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let serial = store.serial else { return false }
            let pushDir = store.kind.pushDir
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        try? ADB.push(
                            serial: serial, localPath: url.path,
                            toDir: pushDir)
                    }
                }
            }
            store.refresh()
            return true
        }
    }
}

#Preview {
    ContentView()
}
