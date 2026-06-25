import Foundation
import UIKit
import Vision

/// 小票/商品 OCR 服务。
///
/// 基于 Apple Vision 框架（VNRecognizeTextRequest），纯设备端识别，不上传图片。
/// 模拟器也可运行（纯软件实现，不依赖神经引擎）。
///
/// 流程：选图 → 识别文字行 → 正则解析金额 → 用户选择填入。
enum OCRService {

    /// 识别图片中的文字，返回按从上到下排列的文本行。
    static func recognize(image: UIImage) async -> [String] {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: [])
                return
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // 中文小票优先简体，兼容繁体与英文
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: texts)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// 从文本行中解析出疑似金额，返回去重后的列表。
    /// 覆盖常见小票写法：¥19.9 / 19.90元 / 合计:19.9 / 19.9
    static func parseAmounts(from lines: [String]) -> [Double] {
        var amounts: [Double] = []
        // 把逗号小数点统一（欧洲/中文混用）
        let patterns: [String] = [
            #"¥\s*￥?\s*(\d+[.,]\d{1,2})"#,                       // ¥19.9
            #"(\d+[.,]\d{2})\s*元?"#,                              // 19.90元
            #"(?:合计|总额|实付|应付|总计|总计|小计)\s*[:：]?\s*(\d+[.,]\d{1,2})"#, // 合计19.9
            #"(\d+[.,]\d{2})"#                                    // 兜底：任意两位小数
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                regex.enumerateMatches(in: line, range: range) { match, _, _ in
                    guard let match = match,
                          let r = Range(match.range(at: 1), in: line) else { return }
                    let cleaned = line[r].replacingOccurrences(of: ",", with: ".")
                    if let v = Double(cleaned), v > 0 {
                        if !amounts.contains(v) { amounts.append(v) }
                    }
                }
            }
        }
        return amounts.sorted()
    }
}
