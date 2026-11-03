import AVFoundation
import Flutter

/// Hands the most recent camera frame to Flutter's texture registry.
final class PreviewTexture: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let lock = NSLock()
  private var latest: CVPixelBuffer?
  private let onFrame: () -> Void

  init(onFrame: @escaping () -> Void) {
    self.onFrame = onFrame
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let buffer = latest else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    lock.lock()
    latest = buffer
    lock.unlock()
    onFrame()
  }
}
