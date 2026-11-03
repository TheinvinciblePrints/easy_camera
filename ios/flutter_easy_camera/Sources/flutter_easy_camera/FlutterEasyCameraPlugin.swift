import Flutter
import UIKit

/// Entry point that wires the Pigeon host API to an AVFoundation `CameraSession`.
public final class FlutterEasyCameraPlugin: NSObject, FlutterPlugin {
  private let session: CameraSession

  init(session: CameraSession) {
    self.session = session
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let session = CameraSession(
      textures: registrar.textures(),
      flutterApi: CameraFlutterApi(binaryMessenger: registrar.messenger())
    )
    CameraHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: session)
    registrar.publish(FlutterEasyCameraPlugin(session: session))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    CameraHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    session.dispose()
  }
}
