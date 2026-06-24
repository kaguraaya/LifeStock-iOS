import Foundation
import UIKit
import SwiftUI

/// 图片存储服务。
///
/// 策略（对应报告）：
/// - 原图落盘到 Application Support/LifeStockImages，模型只存相对路径
/// - 缩略图缓存到模型 thumbnailData（Data?），列表/卡片直接用
/// - 详情页异步读原图
/// - 不上传任何图片
enum ImageStore {

    /// 目录
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("LifeStockImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 保存 UIImage 为原图，返回相对路径与缩略图 Data
    @discardableResult
    static func save(image: UIImage, maxThumbnail: CGFloat = 240) -> (relativePath: String, thumbnail: Data)? {
        let id = UUID().uuidString
        let filename = "\(id).jpg"
        let url = directory().appendingPathComponent(filename)

        guard let fullData = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try fullData.write(to: url, options: .atomic)
        } catch {
            return nil
        }

        let thumb = makeThumbnail(image: image, max: maxThumbnail)
        return (filename, thumb)
    }

    /// 读取原图（异步）
    static func load(relativePath: String) -> UIImage? {
        let url = directory().appendingPathComponent(relativePath)
        return UIImage(contentsOfFile: url.path)
    }

    /// 删除原图
    static func remove(relativePath: String?) {
        guard let path = relativePath else { return }
        let url = directory().appendingPathComponent(path)
        try? FileManager.default.removeItem(at: url)
    }

    private static func makeThumbnail(image: UIImage, max: CGFloat) -> Data {
        let size = image.size
        let scale = min(max / size.width, max / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return thumb.jpegData(compressionQuality: 0.7) ?? Data()
    }

    // MARK: - 演示用：由 SF Symbol 生成缩略图 Data
    /// 演示数据没有真实照片，这里用 SF Symbol 渲染成一张占位缩略图，
    /// 让详情页/卡片在模拟器里也能"有图可看"。
    static func demoThumbnail(symbol: String, background: Color = .orange) -> Data {
        let size = CGSize(width: 240, height: 240)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { ctx in
            // 背景
            let cgCtx = ctx.cgContext
            cgCtx.setFillColor(UIColor(background).withAlphaComponent(0.18).cgColor)
            cgCtx.fill(CGRect(origin: .zero, size: size))

            // SF Symbol
            let config = UIImage.SymbolConfiguration(pointSize: 90, weight: .regular)
            if let symbolImg = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(UIColor(background), renderingMode: .alwaysOriginal) {
                let symbolSize = symbolImg.size
                let origin = CGPoint(x: (size.width - symbolSize.width) / 2,
                                     y: (size.height - symbolSize.height) / 2)
            symbolImg.draw(at: origin)
            }
        }
        return img.jpegData(compressionQuality: 0.7) ?? Data()
    }
}
