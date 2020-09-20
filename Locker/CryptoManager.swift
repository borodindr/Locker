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

class CryptoManager {
    
    // MARK: - Private parameters
    
    private let name: String
    
    private var algorithm: SecKeyAlgorithm {
        .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    }
    
    
    // MARK: - Initializers
    
    init(name: String) throws {
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
            completion(.failure(error))
            return
        }
        
        // Get public key from private key
        guard let publicKey = SecKeyCopyPublicKey(key) else {
            completion(.failure(CryptoManagerError.unableToGeneratePublicKey))
            return
        }
        
        // Check whether encryption is supported
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            completion(.failure(CryptoManagerError.encryptionNotSupported))
            return
        }
        
        // Convert string to data
        let dataToEncrypt = string.data(using: .utf8)!
        
        // Encrypt data
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(publicKey, algorithm, dataToEncrypt as CFData, &error) as Data? else {
            let error = error?.takeRetainedValue() as Error?
            completion(.failure(error ?? CryptoManagerError.unknown))
            return
        }
        
        // Get base64 value of encrypted data
        let encryptedDataString = encryptedData.base64EncodedString()
        completion(.success(encryptedDataString))
    }
    
    /// Decrypts passed string with result in completion
    func decrypt(base64string string: String, completion: @escaping (Result<String, Error>) -> ()) {
        // Convert base64 string to data
        guard let data = Data(base64Encoded: string) else {
            completion(.failure(CryptoManagerError.unacceptableDataToDecrypt))
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
            completion(.failure(error))
            return
        }
        
        // Check whether decryption is supported
        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            completion(.failure(CryptoManagerError.decryptionNotSupported))
            return
        }
        
        var error: Unmanaged<CFError>?
        // Different thread needed to perform FaceID/TouchID authentication
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Decrypt data
            guard let decryptedData = SecKeyCreateDecryptedData(key, self.algorithm, data as CFData, &error) as Data? else {
                let error = error?.takeRetainedValue() as Error?
                completion(.failure(error ?? CryptoManagerError.unknown))
                return
            }
            // Convert decrypted data to string
            let decryptedString = String(decoding: decryptedData, as: UTF8.self)
            DispatchQueue.main.async {
                completion(.success(decryptedString))
            }
        }
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
}
