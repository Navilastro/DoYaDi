import Flutter
import UIKit
import AVFoundation // ÇOK ÖNEMLİ: Ses donanımına erişmek için bu kütüphane şart!

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let volumeChannel = FlutterMethodChannel(name: "Navilastro.DoYaDi/volume_keys",binaryMessenger: controller.binaryMessenger)
    
    volumeChannel.setMethodCallHandler({
      [weak self] (call, result) -> Void in
      
      if call.method == "get_initial_volume" {
        let audioSession = AVAudioSession.sharedInstance()
        var currentVolume: Float = 0.0
        do {
            try audioSession.setActive(true)
            currentVolume = audioSession.outputVolume
        } catch {
            print("Error getting volume: \(error)")
        }
        result(currentVolume)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}