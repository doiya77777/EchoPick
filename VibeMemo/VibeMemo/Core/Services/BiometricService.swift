import LocalAuthentication
import Foundation

/// 生物识别认证服务 (Face ID / Touch ID)
struct BiometricService {
    
    enum BiometricType {
        case faceID
        case touchID
        case none
    }
    
    /// 检测设备支持的生物识别类型
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID // Treat as Face ID equivalent
        @unknown default:
            return .none
        }
    }
    
    /// 执行生物识别认证
    func authenticate(reason: String = "解锁 VibeMemo 以访问你的笔记和录音") async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to passcode
            return await authenticateWithPasscode(reason: reason)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            // Fall back to passcode on biometric failure
            return await authenticateWithPasscode(reason: reason)
        }
    }
    
    /// 使用设备密码认证（作为后备方案）
    private func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            return false
        }
    }
    
    /// 获取生物识别图标名称
    var iconName: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }
    
    /// 获取生物识别类型显示名称
    var displayName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "密码"
        }
    }
}
