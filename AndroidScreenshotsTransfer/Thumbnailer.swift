import Foundation
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

nonisolated enum Thumbnailer {
    /// ImageIO のサムネイル生成を使い、フル解像度をメモリに展開せずに縮小する。
    static func downsampledJPEG(at url: URL, maxPixel: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // 撮影向きを反映
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return jpegData(from: cgImage)
    }

    /// 動画の先頭フレームを切り出す。
    static func downsampledVideoJPEG(at url: URL, maxPixel: CGFloat) async -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true   // 撮影向きを反映
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        return jpegData(from: cgImage)
    }

    private static func jpegData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(
                data, UTType.jpeg.identifier as CFString, 1, nil
            )
        else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
