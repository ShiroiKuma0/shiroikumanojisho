import Flutter
import UIKit

public class DocumentFileSavePlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "document_file_save_plus", binaryMessenger: registrar.messenger())
    let instance = DocumentFileSavePlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if (call.method == "getPlatformVersion") {
        result("iOS " + UIDevice.current.systemVersion)
    } else if (call.method == "getBatteryPercentage") {
        result(UIDevice.current.batteryLevel)
    } else if (call.method == "saveMultipleFiles") {
        let args = call.arguments as! Dictionary<String, Any>
        let dataList = args["dataList"] as! [FlutterStandardTypedData]
        let fileNameList = args["fileNameList"] as! [String]
        let mimeTypeList = args["mimeTypeList"] as! [String]
        saveMultipleFiles(dataList: dataList, fileNameList: fileNameList, mimeTypeList: mimeTypeList)
        result(nil)
    }
  }

  private func saveMultipleFiles(dataList: [FlutterStandardTypedData], fileNameList: [String], mimeTypeList: [String]) {
    if let vc = UIApplication.shared.keyWindow?.rootViewController {
        var temporaryFileURLList:[URL] = []

        let count = dataList.count
        var i = 0
        while i < count {
            let data = dataList[i]
            let fileName = fileNameList[i]
            let temporaryFolder = URL(fileURLWithPath: NSTemporaryDirectory())
            let temporaryFileURL = temporaryFolder.appendingPathComponent(fileName)
            temporaryFileURLList.append(temporaryFileURL)

            do {
                try data.data.write(to: temporaryFileURL)
            } catch {
               print(error)
            }

            i = i + 1
        }

        let activityController = UIActivityViewController(activityItems: temporaryFileURLList, applicationActivities: nil)
        activityController.excludedActivityTypes = [.airDrop, .postToTwitter, .assignToContact, .postToFlickr, .postToWeibo, .postToTwitter]
        if let popOver = activityController.popoverPresentationController {
          popOver.sourceView = vc.view
          popOver.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
          popOver.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        }

        vc.present(activityController, animated: true, completion: nil)
    }
  }
}
