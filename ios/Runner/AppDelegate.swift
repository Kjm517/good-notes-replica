// xcode: set sdk=iOS

import Flutter
import PDFKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let pdfText = PdfTextChannel()
  private let keepAlive = KeepAliveChannel()
  private let fileTransfer = FileTransferChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    pdfText.register(messenger: messenger)
    keepAlive.register(messenger: messenger)
    fileTransfer.register(messenger: messenger)
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    fileTransfer.handleBackgroundEvents(completionHandler)
  }
}

/// Opens a PDF from disk with PDFKit and returns one page of text at a time.
private final class PdfTextChannel {
  static let name = "notably/pdf_text"

  private var documents: [String: PDFDocument] = [:]
  private let queue = DispatchQueue(label: "notably.pdf_text", qos: .userInitiated)

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: PdfTextChannel.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "pdf_text", message: "unavailable", details: nil))
        return
      }
      self.queue.async {
        do {
          let value = try self.handle(call)
          DispatchQueue.main.async { result(value) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "pdf_text", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func handle(_ call: FlutterMethodCall) throws -> Any? {
    switch call.method {
    case "open":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let document = PDFDocument(url: URL(fileURLWithPath: path))
      else {
        throw PdfTextError.couldNotOpen
      }
      let id = UUID().uuidString
      documents[id] = document
      return id
    case "extractPage":
      let document = try document(from: call)
      let pageIndex = (call.arguments as? [String: Any])?["pageIndex"] as? Int ?? 0
      guard pageIndex >= 0, pageIndex < document.pageCount else { return "" }
      return document.page(at: pageIndex)?.string ?? ""
    case "outline":
      return outline(of: try document(from: call))
    case "close":
      if let id = (call.arguments as? [String: Any])?["id"] as? String {
        documents[id] = nil
      }
      return nil
    default:
      throw PdfTextError.unknownMethod
    }
  }

  private func document(from call: FlutterMethodCall) throws -> PDFDocument {
    guard let id = (call.arguments as? [String: Any])?["id"] as? String,
          let document = documents[id]
    else {
      throw PdfTextError.closed
    }
    return document
  }

  private func outline(of document: PDFDocument) -> [[String: Any]] {
    guard let root = document.outlineRoot else { return [] }
    var entries: [[String: Any]] = []
    func walk(_ outline: PDFOutline, depth: Int) {
      for i in 0..<outline.numberOfChildren {
        guard let child = outline.child(at: i) else { continue }
        let title = (child.label ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        var pageIndex = -1
        if let page = child.destination?.page {
          pageIndex = document.index(for: page)
        }
        if !title.isEmpty && pageIndex >= 0 {
          entries.append(["t": title, "p": pageIndex, "d": depth])
        }
        walk(child, depth: depth + 1)
      }
    }
    walk(root, depth: 0)
    return entries
  }
}

private enum PdfTextError: LocalizedError {
  case couldNotOpen
  case closed
  case unknownMethod

  var errorDescription: String? {
    switch self {
    case .couldNotOpen: return "Could not open PDF"
    case .closed: return "PDF session closed"
    case .unknownMethod: return "Unknown method"
    }
  }
}

/// Extra CPU/network time after the user switches apps so a Dart HTTP
/// upload is not frozen at the first suspend.
private final class KeepAliveChannel {
  static let name = "notably/keep_alive"
  private var task = UIBackgroundTaskIdentifier.invalid

  func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "start":
          self?.start()
          result(nil)
        case "stop":
          self?.stop()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  func start() {
    guard task == .invalid else { return }
    task = UIApplication.shared.beginBackgroundTask(withName: "notably.sync") { [weak self] in
      self?.stop()
    }
  }

  func stop() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }
}

/// Downloads a file with a background URLSession so iOS can finish it after
/// the app is no longer on screen.
private final class FileTransferChannel: NSObject, URLSessionDownloadDelegate, FlutterStreamHandler {
  static let name = "notably/file_transfer"

  private var session: URLSession!
  private var pending: (dest: String, result: FlutterResult)?
  private var eventSink: FlutterEventSink?
  private var backgroundCompletion: (() -> Void)?

  func register(messenger: FlutterBinaryMessenger) {
    let config = URLSessionConfiguration.background(withIdentifier: "com.notably.notably.files")
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

    FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "download" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.download(call.arguments, result: result)
      }
    FlutterEventChannel(name: "notably/file_transfer/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  func handleBackgroundEvents(_ completion: @escaping () -> Void) {
    backgroundCompletion = completion
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func download(_ arguments: Any?, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "A download is already running", details: nil))
      return
    }
    guard let args = arguments as? [String: Any],
          let urlString = args["url"] as? String,
          let url = URL(string: urlString),
          let dest = args["destPath"] as? String
    else {
      result(FlutterError(code: "args", message: "Missing url or destPath", details: nil))
      return
    }
    var request = URLRequest(url: url)
    if let headers = args["headers"] as? [String: String] {
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }
    pending = (dest, result)
    session.downloadTask(with: request).resume()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["progress": fraction])
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    if let http = downloadTask.response as? HTTPURLResponse,
       !(200...299).contains(http.statusCode) {
      finish(ok: false, message: "HTTP \(http.statusCode)")
      return
    }
    let dest = pending?.dest
    do {
      guard let dest else { throw URLError(.cannotCreateFile) }
      let destURL = URL(fileURLWithPath: dest)
      try FileManager.default.createDirectory(
        at: destURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: dest) {
        try FileManager.default.removeItem(at: destURL)
      }
      try FileManager.default.moveItem(at: location, to: destURL)
      finish(ok: true)
    } catch {
      finish(ok: false, message: error.localizedDescription)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error {
      finish(ok: false, message: error.localizedDescription)
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let done = backgroundCompletion
    backgroundCompletion = nil
    DispatchQueue.main.async { done?() }
  }

  private func finish(ok: Bool, message: String? = nil) {
    guard let pending else { return }
    self.pending = nil
    DispatchQueue.main.async {
      if ok {
        pending.result(true)
      } else {
        pending.result(
          FlutterError(code: "download", message: message ?? "Download failed", details: nil)
        )
      }
    }
  }
}
