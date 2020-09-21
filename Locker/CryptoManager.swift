//
//  CryptoManager.swift
//  Locker
//
//  Created by Dmitry Borodin on 20.09.2020.
//  Copyright © 2020 Dmitry Borodin. All rights reserved.
//

import Foundation

enum CryptoManagerError: Error {
    case unacceptableName
    case unacceptableDataToDecrypt
    case unableToGeneratePublicKey
    case decryptionNotSupported
    case encryptionNotSupported
    case unknown
}

extension CryptoManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unacceptableName:
            return "Unacceptable name"
        case .unacceptableDataToDecrypt:
            return "Unacceptable data to decrypt"
        case .unableToGeneratePublicKey:
            return "Unable to generate public key"
        case .decryptionNotSupported:
            return "Decryption not supported"
        case .encryptionNotSupported:
            return "Encryption not supported"
        case .unknown:
            return "Unknown error"
        }
    }
}

final class CryptoManager {
    
    // MARK: - Private parameters
    
    private let name: String
    
    private var algorithm: SecKeyAlgorithm {
        .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    }
    
    
    // MARK: - Initializers
    
    init(name: String) {
        self.name = name
    }
    
    
    // MARK: - Public methods
    
    /// Encrypts passed string with result in completion
    func encrypt(string: String, completion: @escaping (Result<String, Error>) -> ()) {
        // Get private key
        let key: SecKey
        do {
            key = try privateKey()
        } catch {
            print("Error getting private key:", error)
            completion(.failure(error))
            return
        }
        
        // Get public key from private key
        guard let publicKey = SecKeyCopyPublicKey(key) else {
            let error = CryptoManagerError.unableToGeneratePublicKey
            print(error)
            completion(.failure(error))
            return
        }
        
        // Check whether encryption is supported
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            let error = CryptoManagerError.encryptionNotSupported
            print(error)
            completion(.failure(error))
            return
        }
        
        // Convert string to data
        let dataToEncrypt = string.data(using: .utf8)!
        
        // Encrypt data
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(publicKey, algorithm, dataToEncrypt as CFData, &error) as Data? else {
            let error = error?.takeRetainedValue() as Error?
            print(error ?? CryptoManagerError.unknown)
            completion(.failure(error ?? CryptoManagerError.unknown))
            return
        }
        
        // Get base64 value of encrypted data
        let encryptedDataString = encryptedData.base64EncodedString()
        completion(.success(encryptedDataString))
    }
    
    /// Decrypts passed string with result in completion
    func decrypt(base64String string: String, completion: @escaping (Result<String, Error>) -> ()) {
        // Convert base64 string to data
        guard let data = Data(base64Encoded: string) else {
            let error = CryptoManagerError.unacceptableDataToDecrypt
            print(error)
            completion(.failure(error))
            return
        }
        decrypt(data: data, completion: completion)
    }
    
    /// Decrypts passed data with result in completion
    func decrypt(data: Data, completion: @escaping (Result<String, Error>) -> ()) {
        // Get private key
        let key: SecKey
        do {
            key = try privateKey()
        } catch {
            print("Error getting private key:", error)
            completion(.failure(error))
            return
        }
        
        // Check whether decryption is supported
        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            let error = CryptoManagerError.decryptionNotSupported
            print(error)
            completion(.failure(error))
            return
        }
        
        var error: Unmanaged<CFError>?
        // Different thread needed to perform FaceID/TouchID authentication
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Decrypt data
            guard let decryptedData = SecKeyCreateDecryptedData(key, self.algorithm, data as CFData, &error) as Data? else {
                let error = error?.takeRetainedValue() as Error?
                print(error ?? CryptoManagerError.unknown)
                DispatchQueue.main.async {
                    completion(.failure(error ?? CryptoManagerError.unknown))
                }
                return
            }
            // Convert decrypted data to string
            let decryptedString = String(decoding: decryptedData, as: UTF8.self)
            DispatchQueue.main.async {
                completion(.success(decryptedString))
            }
        }
    }
    
    @discardableResult
    func removeKey() -> Bool {
        removeKey(name: name)
    }
    
    func hasKey() -> Bool {
        hasKey(name: name)
    }
    
    
    // MARK: - Private methods
    
    private func privateKey() throws -> SecKey {
        // Check whether private key was already generated
        if let existedKey = loadKey(name: name) {
            return existedKey
        }
        // Otherwise generate new private key
        return try generatePrivateKey(name: name)
    }
    
    private func generatePrivateKey(name: String) throws -> SecKey {
        let tag = name.data(using: .utf8)!
        let parameters = try newPrivateKeyParameters(withTag: tag)
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
            let error = error?.takeRetainedValue() as Error?
            throw error ?? CryptoManagerError.unknown
        }
        
        return privateKey
    }
    
    private func newPrivateKeyParameters(withTag tag: Data) throws -> [String: Any] {
        let access = try createAccess()
        
        return [
            kSecAttrKeyType as String:            kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String:      256,
            kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
              kSecAttrIsPermanent as String:      true,
              kSecAttrApplicationTag as String:   tag,
              kSecAttrAccessControl as String:    access
            ]
        ]
    }
    
    private func createAccess() throws -> SecAccessControl {
        let flags: SecAccessControlCreateFlags = [
            .privateKeyUsage,
            .biometryCurrentSet // Adds functionality of FaceID/TouchID authentication
        ]
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                     flags,
                                                     &error) else {
            let error = error?.takeRetainedValue() as Error?
            throw error ?? CryptoManagerError.unknown
        }
        
        return access
    }
    
    private func loadKey(name: String) -> SecKey? {
        let tag = name.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String:                kSecClassKey,
            kSecAttrApplicationTag as String:   tag,
            kSecAttrKeyType as String:          kSecAttrKeyTypeEC,
            kSecReturnRef as String:            true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        return (item as! SecKey)
    }
    
    private func removeKey(name: String) -> Bool {
        let tag = name.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String:                kSecClassKey,
            kSecAttrApplicationTag as String:   tag,
            kSecAttrKeyType as String:          kSecAttrKeyTypeEC,
            kSecReturnRef as String:            true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            return false
        }
        return true
    }
    
    private func hasKey(name: String) -> Bool {
        if let _ = loadKey(name: name) {
            return true
        } else {
            return false
        }
    }
}
