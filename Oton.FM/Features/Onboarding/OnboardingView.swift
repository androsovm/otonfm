import SwiftUI
import AuthenticationServices

/// Onboarding screen with two steps:
/// 1. Apple Sign-In (required for chat write access)
/// 2. Profile setup (name + country flag)
struct OnboardingView: View {
    let authService: any AuthServiceProtocol
    var onComplete: () -> Void

    @State private var step: OnboardingStep = .appleSignIn
    @State private var name: String = ""
    @State private var selectedFlag: String = ""
    @State private var isSaving = false
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    private enum OnboardingStep {
        case appleSignIn
        case profile
    }

    // Priority countries first, then all others
    private static let priorityFlags = [
        "🇷🇺", "🇰🇿", "🇺🇸", "🇫🇷", "🇩🇪", "🇨🇾",
    ]

    private static let otherFlags = [
        "🇬🇧", "🇨🇦", "🇦🇺", "🇰🇷", "🇯🇵", "🇨🇳",
        "🇹🇷", "🇺🇿", "🇰🇬", "🇹🇯", "🇹🇲", "🇦🇿",
        "🇬🇪", "🇦🇲", "🇧🇾", "🇲🇳", "🇲🇩", "🇱🇻",
        "🇱🇹", "🇪🇪", "🇫🇮", "🇸🇪", "🇳🇴", "🇩🇰",
        "🇳🇱", "🇧🇪", "🇨🇭", "🇦🇹", "🇮🇹", "🇪🇸",
        "🇵🇹", "🇬🇷", "🇵🇱", "🇨🇿", "🇮🇱", "🇦🇪",
        "🇹🇭", "🇻🇳", "🇮🇩", "🇲🇾", "🇸🇬", "🇵🇭",
        "🇮🇳", "🇧🇷", "🇲🇽", "🇦🇷", "🇪🇬", "🇿🇦",
        "🇳🇬", "🇲🇦",
    ]

    private let flags = priorityFlags + otherFlags

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [AppColors.splashTop, AppColors.splashBottom]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch step {
            case .appleSignIn:
                appleSignInStep
            case .profile:
                profileStep
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Step 1: Apple Sign-In

    private var appleSignInStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("otonLogo-Light")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            VStack(spacing: 8) {
                Text("Войдите, чтобы писать в чат")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Apple ID нужен для отправки сообщений")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if isSigningIn {
                ProgressView()
                    .tint(.white)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.horizontal, 32)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Profile

    private var profileStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("otonLogo-Light")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Ваше имя")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $name, prompt: Text("Введите имя").foregroundStyle(.white.opacity(0.3)))
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.1))
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 32)

            // Flag grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Выбери страну в которой находишься")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 32)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(flags, id: \.self) { flag in
                            Text(flag)
                                .font(.largeTitle)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedFlag == flag ? .white.opacity(0.2) : .clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedFlag == flag ? .white.opacity(0.5) : .clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedFlag = flag
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }

            // Start button
            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Начать")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(canProceed ? .white : .white.opacity(0.3))
            )
            .disabled(!canProceed || isSaving)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private var canProceed: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedFlag.isEmpty
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Не удалось получить данные Apple ID"
                return
            }

            isSigningIn = true
            errorMessage = nil
            let fullName = appleIDCredential.fullName

            Task {
                do {
                    try await authService.signInWithApple(idToken: idTokenString, nonce: nonce, fullName: fullName)
                    await MainActor.run {
                        isSigningIn = false
                        // Pre-fill name from Apple if available
                        if let givenName = fullName?.givenName, !givenName.isEmpty {
                            name = givenName
                        } else {
                            name = authService.displayName
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .profile
                        }
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        errorMessage = "Ошибка входа: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            // User cancelled — ASAuthorizationError.canceled
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Ошибка Apple Sign-In: \(error.localizedDescription)"
        }
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            try? await authService.saveProfile(displayName: trimmedName, countryFlag: selectedFlag)
            await MainActor.run {
                onComplete()
            }
        }
    }
}
