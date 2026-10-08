import Foundation
import CryptoKit
import CommonCrypto
import Security

struct KokoPasswordVerifier: Codable, Sendable {
    let salt: Data
    let derivedKey: Data
    let iterations: UInt32
}

enum KokoCredentialFailure: LocalizedError {
    case unavailable, derivationFailed
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Your secure sign-in information could not be saved or opened. Unlock your device and try again."
        case .derivationFailed: return "Your password could not be secured. Please try again."
        }
    }
}

enum KokoLocalCredentials {
    private static let service = "koko.local-account-password.v1"
    static func identityKey(_ identity: String) -> String {
        SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func makeVerifier(password: String) throws -> KokoPasswordVerifier {
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { bytes in SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!) }
        guard status == errSecSuccess else { throw KokoCredentialFailure.derivationFailed }
        let rounds: UInt32 = 210_000
        return KokoPasswordVerifier(salt: salt, derivedKey: try derive(password, salt: salt, iterations: rounds), iterations: rounds)
    }
    static func matches(password: String, verifier: KokoPasswordVerifier) throws -> Bool {
        guard verifier.salt.count == 32, verifier.derivedKey.count == 32,
              (100_000...1_000_000).contains(verifier.iterations) else { throw KokoCredentialFailure.unavailable }
        let result = try derive(password, salt: verifier.salt, iterations: verifier.iterations)
        return zip(result, verifier.derivedKey).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
    private static func derive(_ password: String, salt: Data, iterations: UInt32) throws -> Data {
        let secret = Array(password.utf8)
        var output = Data(count: 32)
        let status = secret.withUnsafeBytes { secretBytes in
            salt.withUnsafeBytes { saltBytes in
                output.withUnsafeMutableBytes { keyBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), secretBytes.baseAddress!.assumingMemoryBound(to: Int8.self), secret.count,
                                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                                        keyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard status == kCCSuccess else { throw KokoCredentialFailure.derivationFailed }
        return output
    }
    static func verifier(for identity: String) throws -> KokoPasswordVerifier? {
        var query = keychainQuery(identity)
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KokoCredentialFailure.unavailable }
        return try JSONDecoder().decode(KokoPasswordVerifier.self, from: data)
    }
    static func save(_ verifier: KokoPasswordVerifier, identity: String) throws {
        let data = try JSONEncoder().encode(verifier)
        var query = keychainQuery(identity)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result = SecItemAdd(query as CFDictionary, nil)
        guard result == errSecSuccess else { throw KokoCredentialFailure.unavailable }
    }
    static func remove(identity: String) throws {
        let status = SecItemDelete(keychainQuery(identity) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KokoCredentialFailure.unavailable }
    }
    private static func keychainQuery(_ identity: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: identity]
    }
}
