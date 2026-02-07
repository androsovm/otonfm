import SwiftUI

/// One-time welcome screen that explains push notification value
/// and requests permission before showing the main player.
struct WelcomeNotificationView: View {
    let notificationService: any NotificationServiceProtocol
    let onComplete: () -> Void

    @State private var bellScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.splashTop, AppColors.splashBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .scaleEffect(bellScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                        ) {
                            bellScale = 1.1
                        }
                    }

                Text("Будь в курсе эфира")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                Text("Узнавай о новых программах, специальных выпусках и событиях Oton.FM")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Spacer()
                    .frame(height: 40)

                Button {
                    Task {
                        _ = await notificationService.requestPermission()
                        onComplete()
                    }
                } label: {
                    Text("Включить уведомления")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)

                Button {
                    onComplete()
                } label: {
                    Text("Не сейчас")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 12)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
