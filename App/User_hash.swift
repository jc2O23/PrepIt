//
//  PrepIt
//

import Foundation
import CryptoKit
import Security

struct PasswordSecurity {

    // MARK: - Generate random salt
    static func generateSalt(length: Int = 16) -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        if result != errSecSuccess {
            return UUID().uuidString.data(using: .utf8) ?? Data()
        }
        return data
    }

    // MARK: - Hash password + salt
    static func hashPassword(_ password: String, salt: Data) -> Data {
        let passwordData = Data(password.utf8)
        var combined = Data()
        combined.append(salt)
        combined.append(passwordData)
        let digest = SHA256.hash(data: combined)
        return Data(digest)
    }

    // MARK: - Base64 helpers
    static func toBase64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    static func fromBase64(_ string: String) -> Data? {
        Data(base64Encoded: string)
    }
}
