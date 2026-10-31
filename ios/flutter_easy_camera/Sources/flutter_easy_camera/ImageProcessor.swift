import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns a raw capture into an upright, optionally mirrored, cropped, resized
/// and re-encoded JPEG.
enum ImageProcessor {
  struct Output {
    let url: URL
    let data: Data
    let width: Int
    let height: Int
  }

  enum ProcessingError: Error {
    case decodeFailed
    case encodeFailed
  }

  static func process(
    data: Data,
    options: PlatformCaptureOptions,
    mirror: Bool,
    outputURL: URL
  ) throws -> Output {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int,
      let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int
    else { throw ProcessingError.decodeFailed }

    // EXIF orientations 5-8 swap width and height once applied.
    let exifOrientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
    let swapped = exifOrientation >= 5
    let uprightWidth = swapped ? rawHeight : rawWidth
    let uprightHeight = swapped ? rawWidth : rawHeight
    let crop = cropSize(width: uprightWidth, height: uprightHeight, aspectRatio: options.cropAspectRatio)

    // Let ImageIO rotate and downsample in one pass, sized so the crop ends
    // up at most `maxDimension` on its long side.
    var scale = 1.0
    if let maxDimension = options.maxDimension {
      scale = min(1.0, Double(maxDimension) / Double(max(crop.width, crop.height)))
    }
    let thumbnailMax = Int((Double(max(uprightWidth, uprightHeight)) * scale).rounded(.up))
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: max(thumbnailMax, 1),
    ]
    guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    else { throw ProcessingError.decodeFailed }

    let scaledCrop = cropSize(width: upright.width, height: upright.height, aspectRatio: options.cropAspectRatio)
    let rect = CGRect(
      x: (upright.width - scaledCrop.width) / 2,
      y: (upright.height - scaledCrop.height) / 2,
      width: scaledCrop.width,
      height: scaledCrop.height
    )
    guard var image = upright.cropping(to: rect) else { throw ProcessingError.decodeFailed }
    if mirror, let mirrored = mirrorHorizontally(image) {
      image = mirrored
    }

    let encoded = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        encoded, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw ProcessingError.encodeFailed }

    var outputProperties: [CFString: Any] = [:]
    if !options.stripMetadata {
      for key in [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary, kCGImagePropertyTIFFDictionary] {
        if let value = properties[key] { outputProperties[key] = value }
      }
      if var tiff = outputProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
        tiff[kCGImagePropertyTIFFOrientation] = 1
        outputProperties[kCGImagePropertyTIFFDictionary] = tiff
      }
    }
    outputProperties[kCGImagePropertyOrientation] = 1
    outputProperties[kCGImageDestinationLossyCompressionQuality] =
      Double(min(max(options.jpegQuality, 1), 100)) / 100.0

    CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw ProcessingError.encodeFailed }

    let output = encoded as Data
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try output.write(to: outputURL, options: .atomic)
    return Output(url: outputURL, data: output, width: image.width, height: image.height)
  }

  /// Largest centered crop with `aspectRatio`. The ratio is flipped to follow
  /// the image's orientation, so a 3:4 request on a landscape photo yields 4:3.
  static func cropSize(width: Int, height: Int, aspectRatio: Double?) -> (width: Int, height: Int) {
    guard var ratio = aspectRatio, ratio > 0 else { return (width, height) }
    if (width > height) != (ratio > 1), ratio != 1 { ratio = 1 / ratio }
    let current = Double(width) / Double(height)
    if current > ratio {
      return (min(max(Int((Double(height) * ratio).rounded()), 1), width), height)
    }
    return (width, min(max(Int((Double(width) / ratio).rounded()), 1), height))
  }

  private static func mirrorHorizontally(_ image: CGImage) -> CGImage? {
    guard
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    else { return nil }
    context.translateBy(x: CGFloat(image.width), y: 0)
    context.scaleBy(x: -1, y: 1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage()
  }
}
