import CoreGraphics
import UIKit
import Vision

/// 端侧 OCR：Vision 框架，中英混排，完全离线。
enum TextRecognizer {
    enum RecognizeError: LocalizedError {
        case noImage
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .noImage: String(localized: "无法读取图像数据")
            case .emptyResult: String(localized: "没有识别到文字，请确认截图包含文本内容")
            }
        }
    }

    /// 识别图片中的文字，按行返回。语言组合跟随设置。
    static func recognize(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw RecognizeError.noImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = RecognitionLanguageOption.current.languages

        let lines: [String] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let results = request.results ?? []
                    let lines = results.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw RecognizeError.emptyResult }
        return text
    }
}

/// 图片预处理：超大截图先缩放，控制 OCR 与内存开销（分享扩展内存上限较低）。
enum ImagePreprocessor {
    static let maxDimension: CGFloat = 2048

    static func downscale(_ image: UIImage, maxDimension: CGFloat = ImagePreprocessor.maxDimension) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 压缩为 JPEG 用于入库，控制数据库体积。
    static func jpegData(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        downscale(image, maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    /// 感知哈希（aHash）：缩到 8×8 灰度后按均值出 64 位指纹，用于重复截图检测。
    static func averageHash(_ image: UIImage) -> Int64 {
        guard let cgImage = image.cgImage else { return 0 }
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        let average = pixels.reduce(0) { $0 + Int($1) } / (side * side)
        var hash: UInt64 = 0
        for (index, pixel) in pixels.enumerated() where Int(pixel) > average {
            hash |= (1 << UInt64(index))
        }
        return Int64(bitPattern: hash)
    }
}
