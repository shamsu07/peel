import AVFoundation
import CoreImage
import ImageIO
import Flutter
import UIKit
import UniformTypeIdentifiers
import Vision

enum PeelNativeError: Error {
  case message(String)
}

/// Peel's native features on iOS. Pigeon (pigeon/messages.dart) generates the
/// channel code; heavy work runs off the main thread in detached tasks.
public class PeelNativePlugin: NSObject, FlutterPlugin, PeelNativeApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    PeelNativeApiSetup.setUp(binaryMessenger: registrar.messenger(), api: PeelNativePlugin())
  }

  func prepareSegmenter() throws {
    // Vision's model ships with iOS; nothing to download.
  }

  // MARK: Subject cut-out (Vision, iOS 17+)

  func segmentSubject(imagePath: String, outPath: String, maxSide: Int64) async throws
    -> SegmentResult
  {
    try await Task.detached(priority: .userInitiated) {
      // Decode straight to the size needed, upright and 8-bit, instead of
      // decoding the full photo and redrawing it.
      guard let cg = Self.uprightThumbnail(path: imagePath, maxSide: Int(maxSide)) else {
        return SegmentResult(status: "error", width: 0, height: 0)
      }
      let request = VNGenerateForegroundInstanceMaskRequest()
      let handler = VNImageRequestHandler(cgImage: cg, options: [:])
      do {
        try handler.perform([request])
      } catch {
        return SegmentResult(status: "error", width: 0, height: 0)
      }
      guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
        return SegmentResult(status: "noSubject", width: 0, height: 0)
      }
      let buffer = try observation.generateMaskedImage(
        ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
      let ci = CIImage(cvPixelBuffer: buffer)
      guard let out = Self.ciContext.createCGImage(ci, from: ci.extent),
        let png = UIImage(cgImage: out).pngData()
      else {
        return SegmentResult(status: "error", width: 0, height: 0)
      }
      try png.write(to: URL(fileURLWithPath: outPath))
      return SegmentResult(
        status: "ok", path: outPath, width: Int64(out.width), height: Int64(out.height))
    }.value
  }

  /// One Core Image context for the app's lifetime; they're costly to make.
  static let ciContext = CIContext()

  /// The photo at [path], upright (EXIF applied), longest side at most
  /// [maxSide], decoded directly at that size.
  static func uprightThumbnail(path: String, maxSide: Int) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      return nil
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  // MARK: Video

  func videoInfo(path: String) async throws -> VideoInfo {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let duration = try await asset.load(.duration)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw PeelNativeError.message("No video track")
    }
    let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
    let shown = natural.applying(transform)
    let hasAudio = !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
    return VideoInfo(
      durationMs: Int64(duration.seconds * 1000),
      width: Int64(abs(shown.width).rounded()),
      height: Int64(abs(shown.height).rounded()),
      hasAudio: hasAudio)
  }

  func videoThumbnail(path: String, timeMs: Int64, maxSide: Int64) async throws
    -> FlutterStandardTypedData
  {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: CGFloat(maxSide), height: CGFloat(maxSide))
    let (cg, _) = try await generator.image(at: CMTime(value: timeMs, timescale: 1000))
    guard let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) else {
      throw PeelNativeError.message("Could not encode thumbnail")
    }
    return FlutterStandardTypedData(bytes: jpeg)
  }

  func extractFrames(job: FrameJob) async throws -> Int64 {
    let info = try await videoInfo(path: job.videoPath)
    let asset = AVURLAsset(url: URL(fileURLWithPath: job.videoPath))
    let outDir = URL(fileURLWithPath: job.outDir)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let count = max(1, Int((Double(job.durationMs) * Double(job.fps) / 1000).rounded()))
    let times = (0..<count).map { i in
      CMTime(value: job.startMs + Int64((Double(i) * 1000 / Double(job.fps)).rounded()), timescale: 1000)
    }

    // Decode just big enough that the crop still has outSize pixels.
    let shortSide = Double(min(info.width, info.height))
    let cropSide = max(1, job.crop.size * shortSide)
    let scale = min(1, Double(job.outSize) / cropSide)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(
      width: Double(info.width) * scale, height: Double(info.height) * scale)
    let tolerance = CMTime(value: 1, timescale: 60)
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance

    var index: [CMTime: Int] = [:]
    for (i, t) in times.enumerated() { index[t] = i }

    var written = 0
    for await result in generator.images(for: times) {
      guard let i = index[result.requestedTime] else { continue }
      let cg = try result.image
      let data = try Self.squareRGBA(cg, crop: job.crop, outSize: Int(job.outSize))
      try data.write(to: outDir.appendingPathComponent(String(format: "frame_%05d.rgba", i)))
      written += 1
    }
    return Int64(written)
  }

  /// Crops a square out of [image] and scales it to outSize x outSize RGBA.
  static func squareRGBA(_ image: CGImage, crop: SquareCrop, outSize: Int) throws -> Data {
    let w = Double(image.width)
    let h = Double(image.height)
    let side = crop.size * min(w, h)
    let x = min(max(0, crop.left * w), w - side)
    let y = min(max(0, crop.top * h), h - side)
    let k = Double(outSize) / side

    var data = Data(count: outSize * outSize * 4)
    try data.withUnsafeMutableBytes { raw in
      guard
        let ctx = CGContext(
          data: raw.baseAddress, width: outSize, height: outSize, bitsPerComponent: 8,
          bytesPerRow: outSize * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { throw PeelNativeError.message("No bitmap context") }
      ctx.interpolationQuality = .high
      // Core Graphics' origin is bottom-left.
      ctx.draw(
        image,
        in: CGRect(x: -x * k, y: -(h - y - side) * k, width: w * k, height: h * k))
    }
    return data
  }

  // MARK: Sound-sticker MP4 (spec P0-5)

  func exportHandoffVideo(job: HandoffJob) async throws -> String {
    var tempFiles: [URL] = []
    defer { for url in tempFiles { try? FileManager.default.removeItem(at: url) } }
    let out = URL(fileURLWithPath: job.outPath)
    try? FileManager.default.removeItem(at: out)
    let duration = CMTime(value: job.durationMs, timescale: 1000)
    let range = CMTimeRange(start: .zero, duration: duration)
    let size: CGFloat = 720

    let composition = AVMutableComposition()
    guard
      let videoTrack = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw PeelNativeError.message("No video track") }

    var videoComposition: AVMutableVideoComposition?

    if let imagePath = job.imagePath {
      let still = FileManager.default.temporaryDirectory
        .appendingPathComponent("peel_still_\(UUID().uuidString).mp4")
      tempFiles.append(still)
      try await StillVideoWriter.write(
        imagePath: imagePath, to: still, duration: duration, size: Int(size))
      let stillAsset = AVURLAsset(url: still)
      guard let source = try await stillAsset.loadTracks(withMediaType: .video).first else {
        throw PeelNativeError.message("Still video has no track")
      }
      let sourceRange = try await source.load(.timeRange)
      try videoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, sourceRange.duration)),
        of: source, at: .zero)
    } else if let videoPath = job.videoPath {
      let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
      guard let source = try await asset.loadTracks(withMediaType: .video).first else {
        throw PeelNativeError.message("Video has no track")
      }
      let start = CMTime(value: job.videoStartMs, timescale: 1000)
      let sourceRange = try await source.load(.timeRange)
      let take = CMTimeMinimum(duration, CMTimeSubtract(sourceRange.end, start))
      guard take > .zero else { throw PeelNativeError.message("Trim starts after the video ends") }
      try videoTrack.insertTimeRange(CMTimeRange(start: start, duration: take), of: source, at: .zero)

      if job.audioMode == "original",
        let audio = try await asset.loadTracks(withMediaType: .audio).first,
        let audioTrack = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      {
        let audioRange = try await audio.load(.timeRange)
        let take = CMTimeMinimum(duration, CMTimeSubtract(audioRange.end, start))
        if take > .zero {
          try audioTrack.insertTimeRange(CMTimeRange(start: start, duration: take), of: audio, at: .zero)
        }
      }

      let (natural, transform) = try await source.load(.naturalSize, .preferredTransform)
      let shown = natural.applying(transform)
      let w = abs(shown.width)
      let h = abs(shown.height)
      let crop = job.crop ?? SquareCrop(left: 0, top: 0, size: 1)
      let side = crop.size * min(w, h)
      let k = size / side
      let move = transform
        .concatenating(CGAffineTransform(translationX: -crop.left * w, y: -crop.top * h))
        .concatenating(CGAffineTransform(scaleX: k, y: k))

      let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
      layer.setTransform(move, at: .zero)
      let instruction = AVMutableVideoCompositionInstruction()
      instruction.timeRange = range
      instruction.layerInstructions = [layer]
      let vc = AVMutableVideoComposition()
      vc.renderSize = CGSize(width: size, height: size)
      vc.frameDuration = CMTime(value: 1, timescale: 30)
      vc.instructions = [instruction]
      // Draw the sticker's white edge, corners and text over the video.
      if let overlayPath = job.overlayPath,
        let overlayImage = UIImage(contentsOfFile: overlayPath)?.cgImage
      {
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        let parent = CALayer()
        parent.frame = frame
        let videoLayer = CALayer()
        videoLayer.frame = frame
        let overlay = CALayer()
        overlay.frame = frame
        overlay.contents = overlayImage
        overlay.contentsGravity = .resize
        parent.addSublayer(videoLayer)
        parent.addSublayer(overlay)
        vc.animationTool = AVVideoCompositionCoreAnimationTool(
          postProcessingAsVideoLayer: videoLayer, in: parent)
      }
      videoComposition = vc
    }

    if job.audioMode == "replace", let audioPath = job.audioPath {
      let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
      if let audio = try await audioAsset.loadTracks(withMediaType: .audio).first,
        let audioTrack = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      {
        let total = try await audioAsset.load(.duration)
        let start = CMTime(value: job.audioStartMs, timescale: 1000)
        let available = CMTimeSubtract(total, start)
        let take = CMTimeMinimum(duration, available)
        if take > .zero {
          try audioTrack.insertTimeRange(CMTimeRange(start: start, duration: take), of: audio, at: .zero)
        }
      }
    }

    guard
      let export = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetHighestQuality)
    else { throw PeelNativeError.message("Could not start export") }
    export.outputURL = out
    export.outputFileType = .mp4
    export.videoComposition = videoComposition
    export.timeRange = range
    await export.export()
    guard export.status == .completed else {
      throw export.error ?? PeelNativeError.message("Export failed")
    }
    return job.outPath
  }

  // MARK: Clipboard

  func copyStickerToClipboard(webpPath: String, pngPath: String) throws -> Bool {
    var item: [String: Any] = [:]
    if let webp = FileManager.default.contents(atPath: webpPath) {
      item["org.webmproject.webp"] = webp
      item["public.webp"] = webp
    }
    if let png = FileManager.default.contents(atPath: pngPath) {
      item[UTType.png.identifier] = png
    }
    guard !item.isEmpty else { return false }
    UIPasteboard.general.setItems([item])
    return true
  }
}

/// Writes a silent H.264 video that shows one picture for [duration].
enum StillVideoWriter {
  static func write(imagePath: String, to url: URL, duration: CMTime, size: Int) async throws {
    guard let image = UIImage(contentsOfFile: imagePath) else {
      throw PeelNativeError.message("Could not read image")
    }
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size,
        AVVideoHeightKey: size,
      ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: size,
        kCVPixelBufferHeightKey as String: size,
      ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    guard let buffer = pixelBuffer(for: image, size: size) else {
      throw PeelNativeError.message("Could not draw image")
    }
    // A frame every half second, plus one just before the end, so the
    // video lasts exactly as long as the sound.
    let step = CMTime(value: 1, timescale: 2)
    let last = CMTimeSubtract(duration, CMTime(value: 1, timescale: 30))
    var times: [CMTime] = []
    var t = CMTime.zero
    while t < last {
      times.append(t)
      t = CMTimeAdd(t, step)
    }
    times.append(max(.zero, last))
    for time in times {
      while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
      if !adaptor.append(buffer, withPresentationTime: time) {
        throw writer.error ?? PeelNativeError.message("Could not write frame")
      }
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: duration)
    await writer.finishWriting()
    if writer.status != .completed {
      throw writer.error ?? PeelNativeError.message("Still video failed")
    }
  }

  /// White square with the sticker drawn to fit (transparent areas show white).
  private static func pixelBuffer(for image: UIImage, size: Int) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(
      kCFAllocatorDefault, size, size, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        as CFDictionary, &buffer)
    guard let buffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard
      let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
      let cg = image.cgImage
    else { return nil }
    ctx.setFillColor(UIColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    let s = CGFloat(size)
    let fit = min(s / CGFloat(cg.width), s / CGFloat(cg.height))
    let w = CGFloat(cg.width) * fit
    let h = CGFloat(cg.height) * fit
    ctx.draw(cg, in: CGRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
    return buffer
  }
}

extension UIImage {
  /// The image drawn upright (EXIF orientation applied), longest side at most maxSide.
  func uprightScaled(maxSide: CGFloat) -> UIImage {
    let longest = max(size.width, size.height)
    let s = longest > maxSide ? maxSide / longest : 1
    let target = CGSize(width: (size.width * s).rounded(), height: (size.height * s).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
