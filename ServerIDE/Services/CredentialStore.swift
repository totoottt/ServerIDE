import Foundation

enum CredentialStore {
    private static let passwordService = "ServerIDE.SSH.Password"
    private static let privateKeyService = "ServerIDE.SSH.PrivateKey"
    private static let passphraseService = "ServerIDE.SSH.PrivateKeyPassphrase"

    @discardableResult
    static func savePassword(_ password: String, for id: UUID) -> Bool {
        KeychainService.save(Data(password.utf8), service: passwordService, account: id.uuidString)
    }

    static func password(for id: UUID) -> String? {
        guard let data = KeychainService.read(service: passwordService, account: id.uuidString) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func savePrivateKey(_ key: String, passphrase: String?, for id: UUID) {
        _ = KeychainService.save(Data(key.utf8), service: privateKeyService, account: id.uuidString)
        if let passphrase, !passphrase.isEmpty {
            _ = KeychainService.save(Data(passphrase.utf8), service: passphraseService, account: id.uuidString)
        }
    }

    static func privateKey(for id: UUID) -> String? {
        guard let data = KeychainService.read(service: privateKeyService, account: id.uuidString) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clone(from source: UUID, to destination: UUID) -> Bool {
        for service in [passwordService, privateKeyService, passphraseService] {
            if let data = KeychainService.read(service: service, account: source.uuidString),
               !KeychainService.save(data, service: service, account: destination.uuidString) {
                remove(for: destination)
                return false
            }
        }
        return true
    }
    static func remove(for id: UUID) {
        for service in [passwordService, privateKeyService, passphraseService] {
            KeychainService.delete(service: service, account: id.uuidString)
        }
    }
}
