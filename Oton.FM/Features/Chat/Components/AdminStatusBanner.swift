import SwiftUI

/// Slim banner displayed on the main player screen (outside the chat)
/// showing the current admin status message.
struct AdminStatusBanner: View {
    let status: AdminStatus

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.accentPrimary)

            Text(status.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.25)))
                .overlay(Capsule().strokeBorder(AppColors.accentPrimary.opacity(0.3), lineWidth: 0.5))
        }
        .clipShape(Capsule())
        .offset(y: appeared ? 0 : -10)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
