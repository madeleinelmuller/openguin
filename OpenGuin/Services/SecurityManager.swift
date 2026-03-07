import CryptoKit
import Foundation
import Security

enum SecurityManagerError: LocalizedError {
    case keyCreationFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyCreationFailed(let status):
            return "Failed to create encryption key (\(status))."
        case .keychainReadFailed(let status):
            return "Failed to read secure data (\(status))."
        case .keychainWriteFailed(let status):
            return "Failed to write secure data (\(status))."
        case .encryptionFailed:
            return "Failed to encrypt data."
        case .decryptionFailed:
            return "Failed to decrypt data."
        }
    }
}

final class SecurityManager: @unchecked Sendable {
    static let shared = SecurityManager()

    private let service = "com.openguin.secure-store"
    private let encryptionAccount = "memory-encryption-key"

    private init() {}

    func saveSecret(_ value: String, account: String) throws {
        try saveData(Data(value.utf8), account: account)
    }

    func loadSecret(account: String) throws -> String? {
        guard let data = try loadData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteSecret(account: String) throws {
        try deleteValue(account: account)
    }

    func encrypt(_ data: Data) throws -> Data {
        let key = try fetchOrCreateEncryptionKey()
        do {
            guard let combined = try AES.GCM.seal(data, using: key).combined else {
                throw SecurityManagerError.encryptionFailed
            }
            return combined
        } catch {
            throw SecurityManagerError.encryptionFailed
        }
    }

    func decrypt(_ data: Data) throws -> Data {
        let key = try fetchOrCreateEncryptionKey()
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw SecurityManagerError.decryptionFailed
        }
    }

    private func fetchOrCreateEncryptionKey() throws -> SymmetricKey {
        if let existing = try loadData(account: encryptionAccount) {
            return SymmetricKey(data: existing)
        }

        let newKey = SymmetricKey(size: .bits256)
        let data = newKey.withUnsafeBytes { Data($0) }
        try saveData(data, account: encryptionAccount)
        return newKey
    }

    private func loadData(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw SecurityManagerError.keychainReadFailed(status)
        }
    }

    private func saveData(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw SecurityManagerError.keychainWriteFailed(updateStatus)
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecurityManagerError.keychainWriteFailed(addStatus)
        }
    }

    private func deleteValue(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityManagerError.keychainWriteFailed(status)
        }
    }
}
