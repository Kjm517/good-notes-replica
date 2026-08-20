import Flutter
import PDFKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let pdfText = PdfTextChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    pdfText.register(messenger: engineBridge.applicationRegistrar.messenger())
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
