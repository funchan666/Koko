import Foundation
import CoreFoundation
import Security

final class KokoNoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class KokoGatewayClient {
    static let shared = KokoGatewayClient()
    enum Failure: LocalizedError {
        case response, rejected, installation, content
        var errorDescription: String? {
            switch self {
            case .response: "The connection did not return a complete response. Please try again."
            case .rejected: "This request could not be completed. Please try again."
            case .installation: "This device could not save its secure installation identity. Please try again."
            case .content: "The community collection is temporarily unavailable. Please try again."
            }
        }
    }
    private let session: URLSession
    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: KokoNoRedirects(), delegateQueue: nil)
    }
    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              number.doubleValue >= Double(Int.min), number.doubleValue < Double(Int.max) else { return nil }
        return number.intValue
    }
    func request(_ path: String, body: [String: Any]? = nil, allowUnauthorized: Bool = false) async throws -> [String: Any] {
        guard let origin = IntegrationContract.baseURLString, let url = URL(string: origin + path) else { throw Failure.response }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (bytes, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || (allowUnauthorized && http.statusCode == 401),
              var result = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw Failure.response }
        #if DEBUG
        if path == IntegrationContract.entryPath { print("[Koko arrival] HTTP \(http.statusCode)\n\(String(decoding: bytes, as: UTF8.self))") }
        #endif
        result["_httpStatus"] = http.statusCode
        return result
    }
    func settlement(origin: String, path: String, fields: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: origin + path), url.scheme == "https", url.host != nil else { throw Failure.response }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.response }
        return object
    }
    func probe() async throws {
        guard let origin = IntegrationContract.baseURLString, let url = URL(string: origin + "/") else { throw Failure.response }
        var request = URLRequest(url: url); request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        guard response is HTTPURLResponse else { throw Failure.response }
    }
    func publicArrivalFields() async throws -> [String: Any] {
        let push = await KokoArrivalNotifications.shared.tokenForArrival()
        try Task.checkCancellation()
        return ["koko_edition": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                "arrival_chime": push, "listener_installation": try installationID(), "room_delivery_kind": 2]
    }
    func installationID() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.koko.installation", kSecAttrAccount as String: "listener"]
        func read() -> String? {
            var lookup = query; lookup[kSecReturnData as String] = true
            var result: CFTypeRef?
            guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data, let id = String(data: data, encoding: .utf8), UUID(uuidString: id) != nil else { return nil }
            return id
        }
        if let id = read() { return id }
        let id = UUID().uuidString
        var item = query; item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess, read() == id else { throw Failure.installation }
        return id
    }
}
