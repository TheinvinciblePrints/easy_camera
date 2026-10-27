import AVFoundation
import Flutter
import UIKit

/// AVFoundation implementation of `CameraHostApi`. One camera is open at a time.
///
/// Preview frames are delivered already rotated to the interface orientation
/// and mirrored for front cameras, so Dart never has to rotate the texture.
final class CameraSession: NSObject, CameraHostApi {
  private let textures: FlutterTextureRegistry
  private let flutterApi: CameraFlutterApi
  private let sessionQueue = DispatchQueue(label: "flutter_easy_camera.session")
  private let videoQueue = DispatchQueue(label: "flutter_easy_camera.video")

  private var captureSession: AVCaptureSession?
  private var device: AVCaptureDevice?
  private var videoOutput: AVCaptureVideoDataOutput?
  private var photoOutput: AVCapturePhotoOutput?
  private var texture: PreviewTexture?
  private var textureId: Int64?
  private var lens: PlatformLens = .back
  private var flashMode: PlatformFlashMode = .off
  private var deviceOrientation: UIDeviceOrientation = .portrait
  private var videoOrientation: AVCaptureVideoOrientation = .portrait
  private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]
  private var observers: [NSObjectProtocol] = []

  init(textures: FlutterTextureRegistry, flutterApi: CameraFlutterApi) {
    self.textures = textures
    self.flutterApi = flutterApi
  }

  // MARK: Permissions

  func checkPermission() async throws -> PlatformPermissionStatus {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return .granted
    case .notDetermined: return .notDetermined
    default: return .permanentlyDenied  // iOS never shows the prompt twice.
    }
  }

  func requestPermission() async throws -> PlatformPermissionStatus {
    if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
      _ = await AVCaptureDevice.requestAccess(for: .video)
    }
    return try await checkPermission()
  }

  func openAppSettings() throws -> Bool {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
    UIApplication.shared.open(url)
    return true
  }

  // MARK: Camera lifecycle

  func availableCameras() async throws -> [PlatformCameraInfo] {
    discoverDevices().map { device in
      PlatformCameraInfo(
        id: device.uniqueID,
        lens: Self.lens(of: device),
        sensorOrientation: 90,
        hasFlash: device.hasFlash
      )
    }
  }

  func open(cameraId: String, resolution: PlatformResolution) async throws -> PlatformCameraDescription {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      throw PigeonError(code: "permission_denied", message: "Camera permission has not been granted.", details: nil)
    }
    guard let device = discoverDevices().first(where: { $0.uniqueID == cameraId }) else {
      throw PigeonError(code: "camera_not_found", message: "No camera with id \(cameraId).", details: nil)
    }
    releaseCamera()

    let session = AVCaptureSession()
    session.beginConfiguration()
    session.sessionPreset = .photo

    let input: AVCaptureDeviceInput
    do {
      input = try AVCaptureDeviceInput(device: device)
    } catch {
      throw PigeonError(code: "camera_open_failed", message: error.localizedDescription, details: nil)
    }
    guard session.canAddInput(input) else {
      throw PigeonError(code: "camera_open_failed", message: "Cannot add camera input.", details: nil)
    }
    session.addInput(input)

    let texture = PreviewTexture { [weak self] in
      guard let self, let id = self.textureId else { return }
      self.textures.textureFrameAvailable(id)
    }
    let video = AVCaptureVideoDataOutput()
    video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    video.alwaysDiscardsLateVideoFrames = true
    video.setSampleBufferDelegate(texture, queue: videoQueue)
    guard session.canAddOutput(video) else {
      throw PigeonError(code: "camera_open_failed", message: "Cannot add preview output.", details: nil)
    }
    session.addOutput(video)

    let photo = AVCapturePhotoOutput()
    guard session.canAddOutput(photo) else {
      throw PigeonError(code: "camera_open_failed", message: "Cannot add photo output.", details: nil)
    }
    session.addOutput(photo)
    if #available(iOS 16.0, *) {
      if let dimensions = Self.photoDimensions(for: device, resolution: resolution) {
        photo.maxPhotoDimensions = dimensions
      }
    }
    session.commitConfiguration()

    lens = Self.lens(of: device)
    self.device = device
    self.captureSession = session
    self.videoOutput = video
    self.photoOutput = photo
    self.texture = texture
    textureId = textures.register(texture)
    flashMode = .off

    startObservingOrientation()
    applyPreviewOrientation()
    observeInterruptions(of: session)

    await withCheckedContinuation { continuation in
      sessionQueue.async {
        session.startRunning()
        continuation.resume()
      }
    }

    return PlatformCameraDescription(
      textureId: textureId ?? -1,
      preview: previewInfo(),
      minZoom: Double(device.minAvailableVideoZoomFactor),
      maxZoom: Double(min(device.maxAvailableVideoZoomFactor, 10)),
      minExposureOffset: Double(device.minExposureTargetBias),
      maxExposureOffset: Double(device.maxExposureTargetBias),
      hasFlash: device.hasFlash
    )
  }

  func pausePreview() async throws {
    guard let session = captureSession else { return }
    sessionQueue.async { session.stopRunning() }
  }

  func resumePreview() async throws {
    guard let session = captureSession else { return }
    sessionQueue.async { if !session.isRunning { session.startRunning() } }
  }

  func close() async throws {
    releaseCamera()
  }

  func dispose() {
    releaseCamera()
  }

  private func releaseCamera() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    if let session = captureSession {
      sessionQueue.async { session.stopRunning() }
    }
    videoOutput?.setSampleBufferDelegate(nil, queue: nil)
    if let id = textureId {
      textures.unregisterTexture(id)
    }
    captureSession = nil
    device = nil
    videoOutput = nil
    photoOutput = nil
    texture = nil
    textureId = nil
  }

  // MARK: Controls

  func setFlashMode(mode: PlatformFlashMode) async throws {
    let device = try requireDevice()
    try configure(device) {
      if device.hasTorch {
        device.torchMode = mode == .torch ? .on : .off
      }
    }
    flashMode = mode
  }

  func setZoom(zoom: Double) async throws {
    let device = try requireDevice()
    let clamped = min(max(CGFloat(zoom), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
    try configure(device) { device.videoZoomFactor = clamped }
  }

  func setFocusPoint(x: Double, y: Double) async throws {
    let device = try requireDevice()
    let point = sensorPoint(x: x, y: y)
    try configure(device) {
      if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
        device.focusPointOfInterest = point
        device.focusMode = .autoFocus
      }
      if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
        device.exposurePointOfInterest = point
        device.exposureMode = .autoExpose
      }
    }
  }

  func setExposureOffset(offset: Double) async throws {
    let device = try requireDevice()
    let bias = min(max(Float(offset), device.minExposureTargetBias), device.maxExposureTargetBias)
    try configure(device) { device.setExposureTargetBias(bias, completionHandler: nil) }
  }

  func takePicture(options: PlatformCaptureOptions) async throws -> PlatformCaptureResult {
    guard let photoOutput, let device else {
      throw PigeonError(code: "camera_not_open", message: "No camera is open. Call open() first.", details: nil)
    }
    let settings: AVCapturePhotoSettings
    if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
      settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    } else {
      settings = AVCapturePhotoSettings()
    }
    if device.hasFlash {
      let wanted: AVCaptureDevice.FlashMode
      switch flashMode {
      case .auto: wanted = .auto
      case .on: wanted = .on
      case .off, .torch: wanted = .off
      }
      if photoOutput.supportedFlashModes.contains(wanted) {
        settings.flashMode = wanted
      }
    }
    if #available(iOS 16.0, *) {
      settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
    }
    if let connection = photoOutput.connection(with: .video) {
      // Photos follow the physical orientation, even if the UI is locked.
      Self.setOrientation(of: connection, to: Self.videoOrientation(for: deviceOrientation) ?? videoOrientation)
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
      }
    }

    let capturedLens = lens
    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let delegate = PhotoCaptureDelegate { [weak self] result in
        self?.inFlightCaptures[settings.uniqueID] = nil
        continuation.resume(with: result)
      }
      inFlightCaptures[settings.uniqueID] = delegate
      photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("flutter_easy_camera", isDirectory: true)
    let url = directory.appendingPathComponent("IMG_\(timestamp).jpg")
    let output: ImageProcessor.Output
    do {
      output = try await Task.detached(priority: .userInitiated) {
        try ImageProcessor.process(
          data: data,
          options: options,
          mirror: options.mirrorFront && capturedLens == .front,
          outputURL: url
        )
      }.value
    } catch {
      throw PigeonError(code: "processing_failed", message: "Could not process the capture: \(error)", details: nil)
    }

    return PlatformCaptureResult(
      path: output.url.path,
      bytes: options.includeBytes ? FlutterStandardTypedData(bytes: output.data) : nil,
      width: Int64(output.width),
      height: Int64(output.height),
      lens: capturedLens,
      timestampMs: timestamp
    )
  }

  // MARK: Orientation

  private func startObservingOrientation() {
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    updateDeviceOrientation(UIDevice.current.orientation)
    observers.append(
      NotificationCenter.default.addObserver(
        forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.updateDeviceOrientation(UIDevice.current.orientation)
        // The interface rotates slightly after the device; re-read it then.
        DispatchQueue.main.async { self.applyPreviewOrientation() }
      })
  }

  private func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
    guard let platform = Self.platformOrientation(for: orientation), orientation != deviceOrientation else { return }
    deviceOrientation = orientation
    Task { @MainActor in try? await flutterApi.onDeviceOrientationChanged(orientation: platform) }
  }

  /// Rotates preview frames to match the interface and tells Dart when the
  /// buffer's shape changes.
  private func applyPreviewOrientation() {
    guard let connection = videoOutput?.connection(with: .video) else { return }
    let target = Self.interfaceVideoOrientation()
    let changed = target != videoOrientation
    videoOrientation = target
    Self.setOrientation(of: connection, to: target)
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = lens == .front
    }
    if changed {
      let info = previewInfo()
      Task { @MainActor in try? await flutterApi.onPreviewChanged(preview: info) }
    }
  }

  private func previewInfo() -> PlatformPreviewInfo {
    var width = 1280.0
    var height = 960.0
    if let device {
      let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
      width = Double(max(dimensions.width, dimensions.height))
      height = Double(min(dimensions.width, dimensions.height))
    }
    let portrait = videoOrientation == .portrait || videoOrientation == .portraitUpsideDown
    return PlatformPreviewInfo(
      width: portrait ? height : width,
      height: portrait ? width : height,
      rotationDegrees: 0,
      mirror: false
    )
  }

  /// Converts a normalized point in the upright, mirrored preview into the
  /// sensor's landscape-right coordinate space used by points of interest.
  private func sensorPoint(x: Double, y: Double) -> CGPoint {
    let px = lens == .front ? 1 - x : x
    switch videoOrientation {
    case .portrait: return CGPoint(x: y, y: 1 - px)
    case .portraitUpsideDown: return CGPoint(x: 1 - y, y: px)
    case .landscapeLeft: return CGPoint(x: 1 - px, y: 1 - y)
    default: return CGPoint(x: px, y: y)
    }
  }

  private func observeInterruptions(of session: AVCaptureSession) {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: .main) { [weak self] note in
        let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
        Task { @MainActor in
          try? await self?.flutterApi.onError(code: "runtime_error", message: error?.localizedDescription ?? "Camera error.")
        }
      })
    observers.append(
      center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: .main) { [weak self] _ in
        Task { @MainActor in
          try? await self?.flutterApi.onError(code: "interrupted", message: "The camera was interrupted by the system.")
        }
      })
    observers.append(
      center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: .main) { [weak self] _ in
        guard let self, let session = self.captureSession else { return }
        self.sessionQueue.async { if !session.isRunning { session.startRunning() } }
      })
  }

  // MARK: Helpers

  private func discoverDevices() -> [AVCaptureDevice] {
    var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    if #available(iOS 17.0, *) {
      types.append(.external)
    }
    return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
  }

  private func requireDevice() throws -> AVCaptureDevice {
    guard let device else {
      throw PigeonError(code: "camera_not_open", message: "No camera is open. Call open() first.", details: nil)
    }
    return device
  }

  private func configure(_ device: AVCaptureDevice, _ change: () -> Void) throws {
    do {
      try device.lockForConfiguration()
    } catch {
      throw PigeonError(code: "configuration_failed", message: error.localizedDescription, details: nil)
    }
    change()
    device.unlockForConfiguration()
  }

  private static func lens(of device: AVCaptureDevice) -> PlatformLens {
    switch device.position {
    case .front: return .front
    case .back: return .back
    default: return .external
    }
  }

  @available(iOS 16.0, *)
  private static func photoDimensions(
    for device: AVCaptureDevice, resolution: PlatformResolution
  ) -> CMVideoDimensions? {
    let supported = device.activeFormat.supportedMaxPhotoDimensions
      .sorted { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
    let bound: Int32
    switch resolution {
    case .low: bound = 640
    case .medium: bound = 1280
    case .high: bound = 1920
    case .veryHigh: bound = 2560
    case .max: return supported.last
    }
    return supported.last(where: { max($0.width, $0.height) <= bound }) ?? supported.first
  }

  private static func interfaceVideoOrientation() -> AVCaptureVideoOrientation {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    switch scene?.interfaceOrientation {
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return .portrait
    }
  }

  /// Device and video orientations name landscape from opposite sides.
  private static func videoOrientation(for orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
    switch orientation {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return nil
    }
  }

  private static func platformOrientation(for orientation: UIDeviceOrientation) -> PlatformDeviceOrientation? {
    switch orientation {
    case .portrait: return .portraitUp
    case .portraitUpsideDown: return .portraitDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return nil
    }
  }

  private static func setOrientation(of connection: AVCaptureConnection, to orientation: AVCaptureVideoOrientation) {
    if #available(iOS 17.0, *) {
      let angle: CGFloat
      switch orientation {
      case .portrait: angle = 90
      case .portraitUpsideDown: angle = 270
      case .landscapeLeft: angle = 180
      default: angle = 0
      }
      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    } else if connection.isVideoOrientationSupported {
      connection.videoOrientation = orientation
    }
  }
}

/// Bridges `AVCapturePhotoCaptureDelegate` callbacks to a single result.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let completion: (Result<Data, Error>) -> Void

  init(completion: @escaping (Result<Data, Error>) -> Void) {
    self.completion = completion
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if let error {
      completion(.failure(PigeonError(code: "capture_failed", message: error.localizedDescription, details: nil)))
    } else if let data = photo.fileDataRepresentation() {
      completion(.success(data))
    } else {
      completion(.failure(PigeonError(code: "capture_failed", message: "No photo data.", details: nil)))
    }
  }
}
