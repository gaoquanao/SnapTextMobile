import LocalAuthentication
import SwiftUI

/// FaceID / 密码隐私锁。开启后 App 退到后台即上锁，回前台需验证。
struct LockScreenView: View {
    var onUnlock: () -> Void

    @State private var failed = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                Text("拾文已锁定")
                    .font(.title3.weight(.semibold))
                Text("归档内容受隐私锁保护")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if failed {
                    Text("验证未通过，请重试")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Button {
                    authenticate()
                } label: {
                    Label("解锁", systemImage: "faceid")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        let policy = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            ? LAPolicy.deviceOwnerAuthentication
            : LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.evaluatePolicy(policy, localizedReason: "解锁拾文查看归档") { success, _ in
            Task { @MainActor in
                if success {
                    onUnlock()
                } else {
                    failed = true
                }
            }
        }
    }
}
