import SwiftUI

/// Overlay shown after a successful purchase.
struct PurchaseSuccessView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(
                    width: Constants.Layout.successIconSize,
                    height: Constants.Layout.successIconSize
                )
                .foregroundColor(AppColors.accentPrimary)

            Text("Көмөҥ иһин барҕа махтал!")
                .font(AppFonts.successTitle)
                .foregroundColor(AppColors.textPrimary)

            Text("Спасибо за покупку!")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                withAnimation {
                    onDismiss()
                }
            }) {
                Text("Продолжить")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(AppColors.accentPrimary)
                    .clipShape(Capsule())
            }
            .padding(.top, 10)
        }
        .padding(30)
        .background(AppColors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cardCornerRadius))
        .shadow(
            color: .black.opacity(Constants.Shadow.cardOpacity),
            radius: Constants.Shadow.cardRadius,
            x: 0,
            y: Constants.Shadow.cardOffsetY
        )
        .transition(.scale.combined(with: .opacity))
    }
}
