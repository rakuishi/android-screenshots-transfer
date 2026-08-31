import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// サムネイルグリッド。キーボード操作と複数選択が標準で効くよう NSCollectionView を使う。
struct ScreenshotGridView: NSViewRepresentable {
    @ObservedObject var store: DeviceStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 150, height: 150)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(
            ThumbnailCollectionItem.self,
            forItemWithIdentifier: ThumbnailCollectionItem.identifier)
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        // 外部アプリへはコピーとして渡す
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        context.coordinator.collectionView = collectionView

        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.store = store
        // 一覧が変わったときだけ再読み込みし、選択状態を保つ
        if coordinator.files != store.files {
            coordinator.files = store.files
            (scrollView.documentView as? NSCollectionView)?.reloadData()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate,
        NSFilePromiseProviderDelegate
    {
        var store: DeviceStore
        var files: [ScreenshotFile] = []
        weak var collectionView: NSCollectionView?

        nonisolated let promiseQueue = OperationQueue()

        init(store: DeviceStore) { self.store = store }

        // MARK: DataSource

        func collectionView(
            _ collectionView: NSCollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            files.count
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            let item =
                collectionView.makeItem(
                    withIdentifier: ThumbnailCollectionItem.identifier,
                    for: indexPath) as! ThumbnailCollectionItem
            item.configure(file: files[indexPath.item], store: store)
            return item
        }

        // MARK: Drag out

        func collectionView(
            _ collectionView: NSCollectionView,
            canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent
        ) -> Bool {
            true
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            pasteboardWriterForItemAt indexPath: IndexPath
        ) -> NSPasteboardWriting? {
            let file = files[indexPath.item]
            let ext = (file.name as NSString).pathExtension
            let uti = UTType(filenameExtension: ext) ?? .data
            let provider = NSFilePromiseProvider(fileType: uti.identifier, delegate: self)
            provider.userInfo = file   // 書き出し時に元ファイルを特定する
            return provider
        }

        // MARK: NSFilePromiseProviderDelegate

        nonisolated func filePromiseProvider(
            _ filePromiseProvider: NSFilePromiseProvider,
            fileNameForType fileType: String
        ) -> String {
            (filePromiseProvider.userInfo as? ScreenshotFile)?.name ?? "screenshot"
        }

        nonisolated func filePromiseProvider(
            _ filePromiseProvider: NSFilePromiseProvider,
            writePromiseTo url: URL,
            completionHandler: @escaping (Error?) -> Void
        ) {
            guard let file = filePromiseProvider.userInfo as? ScreenshotFile else {
                completionHandler(nil); return
            }
            do {
                // ドロップ先へフル解像度を直接 pull する
                try ADB.pull(serial: file.serial, remotePath: file.remotePath, to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

        nonisolated func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
            promiseQueue
        }
    }
}

// MARK: - Item

final class ThumbnailCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ThumbnailCollectionItem")

    private let thumbnailView = NSImageView()
    private let playBadge = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var loadTask: Task<Void, Never>?
    private var file: ScreenshotFile?

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        nameLabel.font = .systemFont(ofSize: 11)

        playBadge.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "動画")
        playBadge.symbolConfiguration = .init(pointSize: 28, weight: .regular)
        playBadge.contentTintColor = .white
        playBadge.translatesAutoresizingMaskIntoConstraints = false
        playBadge.isHidden = true

        view.addSubview(thumbnailView)
        view.addSubview(playBadge)
        view.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            playBadge.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),
            thumbnailView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            thumbnailView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            thumbnailView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            nameLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            nameLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
    }

    func configure(file: ScreenshotFile, store: DeviceStore) {
        self.file = file
        nameLabel.stringValue = file.name
        thumbnailView.image = NSImage(
            systemSymbolName: file.isVideo ? "video" : "photo",
            accessibilityDescription: nil)
        playBadge.isHidden = !file.isVideo

        let id = file.id
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            let image = await store.thumbnail(for: file)
            // セルが別ファイルに再利用されていたら捨てる
            guard let self, self.file?.id == id else { return }
            self.thumbnailView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        thumbnailView.image = nil
        playBadge.isHidden = true
        file = nil
    }

    override var isSelected: Bool {
        didSet { updateSelectionHighlight() }
    }

    private func updateSelectionHighlight() {
        view.layer?.backgroundColor =
            isSelected
            ? NSColor.selectedContentBackgroundColor.cgColor
            : NSColor.clear.cgColor
        nameLabel.textColor = isSelected ? .white : .labelColor
    }
}
