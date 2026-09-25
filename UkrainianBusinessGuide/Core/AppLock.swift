//
//  AppLock.swift
//  UkrainianBusinessGuide
//
//  Блокування застосунку: Face ID / Touch ID, а якщо біометрії немає — код пристрою.
//

import LocalAuthentication
import Observation

@Observable
final class AppLock {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false

    init(locked: Bool = false) {
        isLocked = locked
    }

    func lock() {
        isLocked = true
    }

    @MainActor
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        // Якщо на пристрої вимкнули код, захисту вже немає — не блокуємо користувача назавжди.
        guard Self.isAvailable else {
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await Self.authenticate(reason: "Відкрити фінансові дані") {
            isLocked = false
        }
    }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "код пристрою"
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
