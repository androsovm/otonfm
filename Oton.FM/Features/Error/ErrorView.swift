import SwiftUI

/// Error overlay with icon, message, recovery suggestion, and retry button.
/// In v2 this is actually connected to the UI (unlike v1).
struct ErrorView: View {
    let error: AudioError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Constants.Layout.errorIconSize))
                .foregroundColor(AppColors.error)

            Text(error.errorDescription ?? "Произошла ошибка")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retry) {
                Text("Повторить")
                    .font(AppFonts.buttonLabel)
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(AppColors.buttonPrimaryBg)
                    .clipShape(Capsule())
            }
        }
        .padding(Constants.Layout.cardCornerRadius * 2) // 40pt
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cardCornerRadius)
                .fill(AppColors.surfaceCard)
        )
        .padding(.horizontal, Constants.Layout.cardCornerRadius * 2) // 40pt
    }
}
